#!/usr/bin/env bash
# sync-github-secrets.sh — publica os outputs do Terraform como secrets do repositório
# da aplicação (ADR-0023). Substitui a cópia manual de valores descrita na antiga
# Fase 11.5 do runbook.
#
# Por que um script: os ARNs das roles e os IDs de distribuição mudam a cada
# teardown+rebuild. Copiados à mão, ficavam silenciosamente desatualizados — o sintoma
# era um `AccessDenied` em AssumeRoleWithWebIdentity no meio da apresentação, ou uma
# invalidação de CloudFront apontando para uma distribuição que já não existia.
#
# Dois secrets que existiam antes deixaram de ser necessários: os distribution IDs do
# CloudFront agora são resolvidos em runtime pelo alias, dentro do deploy-frontend.yml.
#
# Uso:
#   ./sync-github-secrets.sh            — sincroniza o que já estiver disponível
#   ./sync-github-secrets.sh --check    — só mostra o que seria configurado

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib-common.sh"

CHECK=false
[[ "${1:-}" == "--check" ]] && CHECK=true

command -v gh >/dev/null || err "gh CLI não encontrado"
gh auth status >/dev/null 2>&1 || err "gh não autenticado — rode 'gh auth login'"

tf_out() {
  terraform -chdir="${TERRAFORM_DIR}/$1" output -raw "$2" 2>/dev/null || echo ""
}

set_secret() {
  local name="$1" value="$2"
  if [[ -z "$value" ]]; then
    warn "$name — output indisponível, pulando (a stack correspondente já foi aplicada?)"
    return 0
  fi
  if [[ "$CHECK" == true ]]; then
    echo "  $name = ${value:0:28}..."
    return 0
  fi
  gh secret set "$name" --repo "$APP_REPO" --body "$value" >/dev/null
  ok "$name"
}

log "Sincronizando secrets em ${APP_REPO}"

set_secret AWS_ACCOUNT_ID "$ACCOUNT_ID"
set_secret AWS_REGION     "$REGION"

# Stack `cicd` (ADR-0023) — disponível já no Estágio 2, antes do cluster existir.
set_secret STAGING_ROLE_ARN "$(tf_out cicd github_staging_role_arn)"
set_secret PROD_ROLE_ARN    "$(tf_out cicd github_prod_role_arn)"

# Stack `site` (Estágio 5) — as roles de frontend escopam permissões sobre os buckets
# e distribuições daquela stack, então só existem depois dela. Um deploy de frontend
# também não teria o que fazer antes do bucket de destino existir.
set_secret FRONTEND_STAGING_ROLE_ARN "$(tf_out site frontend_staging_role_arn)"
set_secret FRONTEND_PROD_ROLE_ARN    "$(tf_out site github_frontend_role_arn)"

if [[ -z "$(tf_out site frontend_staging_role_arn)" ]]; then
  warn "Os secrets de frontend dependem da stack 'site' (Estágio 5). Rode este script de novo depois dela."
fi

# GITOPS_DEPLOY_TOKEN não sai de output nenhum — é um PAT fine-grained, criado uma vez
# por conta e reaproveitado entre ciclos. Só avisa se estiver faltando.
if [[ "$CHECK" != true ]] && ! gh secret list --repo "$APP_REPO" | grep -q GITOPS_DEPLOY_TOKEN; then
  warn "GITOPS_DEPLOY_TOKEN ausente — crie um PAT fine-grained com Contents:Read and write"
  warn "  em devopsproject-ecommerce-gitops e configure com:"
  echo  "    gh secret set GITOPS_DEPLOY_TOKEN --repo $APP_REPO"
fi

ok "secrets sincronizados"
