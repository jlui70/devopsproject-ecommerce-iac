#!/usr/bin/env bash
# setup-github-repo.sh — branch `develop`, branch protection e GitHub Environments
# (ADR-0023). Substitui as antigas Fases 11.1 a 11.3 do runbook. Idempotente.
#
# MUDANÇA EM RELAÇÃO AO RUNBOOK ANTIGO — `enforce_admins: false`:
#
# A proteção anterior usava enforce_admins=true + 1 aprovação obrigatória. Num
# repositório de conta única o GitHub não permite auto-aprovação, então não havia
# caminho válido para mergear — e o runbook contornava zerando
# required_approving_review_count, mergeando e restaurando, duas vezes (Fase 11.7 e
# Teste 0). O efeito prático era um gate que parecia contornável a comando.
#
# Com enforce_admins=false o PR continua obrigatório para todo mundo, e o dono do
# repositório usa `gh pr merge --admin` explicitamente — uma ação registrada e
# auditável, em vez de desligar e religar a proteção. O gate que de fato protege
# produção não é este: é o GitHub Environment `production` com reviewer obrigatório
# (ADR-0014) somado a `if: github.ref == 'refs/heads/develop'` (ADR-0021), e nenhum
# dos dois é afetado.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib-common.sh"

command -v gh >/dev/null || err "gh CLI não encontrado"
gh auth status >/dev/null 2>&1 || err "gh não autenticado — rode 'gh auth login'"

APP_REPO_DIR="${APP_REPO_DIR:-$(cd "${IAC_ROOT}/../devopsproject-ecommerce" && pwd)}"

# ─── branch develop ─────────────────────────────────────────────────────────
log "Garantindo a branch 'develop' em ${APP_REPO}"
if gh api "repos/${APP_REPO}/branches/develop" >/dev/null 2>&1; then
  ok "develop já existe no remoto"
else
  run "cd \"$APP_REPO_DIR\" && git checkout develop 2>/dev/null || git checkout -b develop"
  run "cd \"$APP_REPO_DIR\" && git push -u origin develop"
  ok "develop criada"
fi

# ─── branch protection ──────────────────────────────────────────────────────
# `-F` (não `-f`) nos campos numéricos/booleanos: com `-f` o GitHub devolve 422,
# porque os valores chegam como string.
log "Aplicando branch protection em develop"
run "gh api -X PUT \"repos/${APP_REPO}/branches/develop/protection\" \
  -F 'required_status_checks=null' \
  -F 'enforce_admins=false' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'restrictions=null' >/dev/null"
ok "develop protegida (PR obrigatório; merge administrativo via 'gh pr merge --admin')"

# ─── environments ───────────────────────────────────────────────────────────
log "Criando os GitHub Environments"
run "gh api -X PUT \"repos/${APP_REPO}/environments/staging\" >/dev/null"
ok "environment staging"

if [[ "$DRY_RUN" == true ]]; then
  echo -e "  \033[90m[dry-run] gh api -X PUT repos/${APP_REPO}/environments/production (com reviewer)\033[0m"
else
  MY_ID=$(gh api user --jq .id)
  gh api -X PUT "repos/${APP_REPO}/environments/production" \
    -f "reviewers[][type]=User" -F "reviewers[][id]=${MY_ID}" >/dev/null
  ok "environment production (reviewer obrigatório — gate do ADR-0014)"
fi

# ─── OIDC provider ──────────────────────────────────────────────────────────
log "Verificando o provider OIDC do GitHub na conta AWS"
if aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text \
    | grep -q "token.actions.githubusercontent.com"; then
  ok "provider OIDC presente"
else
  warn "provider OIDC ausente — a stack 'cicd' foi aplicada? (Estágio 2)"
fi

ok "repositório configurado"
