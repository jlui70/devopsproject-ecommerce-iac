#!/usr/bin/env bash
# sync-gitops-outputs.sh — propaga outputs do Terraform (valores que mudam a cada
# apply/rebuild) para os arquivos correspondentes no repositório GitOps, substituindo
# os passos manuais de `terraform output` + `sed` + `git commit/push` descritos no
# RUNBOOK-deploy-do-zero.md (Fase 4 e Fase 10.0a).
#
# Uso:
#   ./sync-gitops-outputs.sh <alvo> [--push]
#
# Alvos:
#   prod-acm        ARN do certificado ACM de produção -> production/infrastructure/ingress.yml
#   staging-acm     ARN do certificado ACM do backend de staging -> staging/ingress.yml
#   staging-pghost  Endpoint do Aurora writer de staging -> staging/seed-job.yml (PGHOST)
#   all             Executa os três, na ordem acima
#
# Antes de editar qualquer arquivo, sincroniza o clone local com origin/<branch>
# (fetch + pull --rebase --autostash) — necessário em reinstalações do zero, onde
# o clone local pode estar atrasado em relação a commits que o CI/CD de um ciclo
# anterior deixou no remoto (o teardown de infra nunca mexe em repositórios git).
#
# Por padrão só faz `git add` + `git commit` local no repo GitOps — não dá push.
# Passe --push para também enviar ao remoto (ação visível a outros colaboradores,
# por isso é opt-in e não o padrão).
#
# Requer: terraform, aws cli, git — as mesmas ferramentas já exigidas pela Fase 0
# do runbook. Rodar a partir de qualquer diretório.

set -euo pipefail

IAC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITOPS_ROOT="$(cd "${IAC_ROOT}/../devopsproject-ecommerce-gitops" && pwd)"

TARGET="${1:-}"
PUSH=false
for arg in "$@"; do
  [[ "$arg" == "--push" ]] && PUSH=true
done

if [[ -z "$TARGET" || "$TARGET" == "-h" || "$TARGET" == "--help" ]]; then
  sed -n '3,20p' "${BASH_SOURCE[0]}"
  exit 1
fi

log() { echo "[sync-gitops-outputs] $*"; }

# Sincroniza o clone local do GitOps com o remoto antes de qualquer edição.
# Necessário porque o repo GitOps sobrevive a ciclos de teardown+rebuild da infra
# (o teardown nunca mexe em repositórios git) — um clone local que ficou parado
# desde um ciclo anterior, enquanto o CI/CD do ciclo anterior seguiu commitando
# em `main` (deploy/staging, deploy/production), fica atrasado em relação ao
# remoto. Sem este passo, o commit local deste script diverge do remoto e o
# `git push` subsequente falha com "non-fast-forward" — reproduzível em qualquer
# clone que não tenha sido atualizado manualmente antes de rodar o script, não é
# um caso isolado de um clone específico.
sync_local_repo() {
  cd "$GITOPS_ROOT"
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  log "Sincronizando clone local com origin/${branch} antes de aplicar mudanças..."
  git fetch origin "$branch" --quiet
  if ! git pull --rebase --autostash origin "$branch" --quiet; then
    log "ERRO: não foi possível sincronizar automaticamente com origin/${branch} (conflito de rebase)."
    log "Resolva manualmente em ${GITOPS_ROOT} (git status / git rebase --abort) e rode o script de novo."
    exit 1
  fi
}
sync_local_repo

# Regex de ARN ACM — casa tanto um ARN real de um ciclo anterior quanto qualquer
# outro ARN real (não depende de placeholder textual, evita o no-op silencioso
# documentado no runbook para o kustomization.yml e o ingress.yml de produção).
ACM_ARN_REGEX='arn:aws:acm:us-east-1:[0-9]*:certificate/[a-z0-9-]*'

# Regex de endpoint RDS/Aurora — casa tanto o placeholder documentado
# (<TERRAFORM_OUTPUT:staging_aurora_writer_endpoint>) quanto um endpoint real
# deixado por um ciclo anterior (achado A-1 da auditoria de 2026-08-13: o sed
# anterior só casava o placeholder literal e ficava mudo diante de um valor real).
PGHOST_REGEX='([A-Za-z0-9<>_:.-]*\.rds\.amazonaws\.com|<TERRAFORM_OUTPUT:staging_aurora_writer_endpoint>)'

commit_and_maybe_push() {
  local file="$1" msg="$2"
  cd "$GITOPS_ROOT"
  if git diff --quiet -- "$file"; then
    log "Nada mudou em ${file} — pulando commit."
    return 0
  fi
  git add "$file"
  git commit -m "$msg"
  if [[ "$PUSH" == true ]]; then
    git push
    log "Push feito: ${file}"
  else
    log "Commitado localmente (sem push — rode com --push para enviar): ${file}"
  fi
}

sync_prod_acm() {
  log "Lendo acm_certificate_arn da stack server..."
  local arn
  arn=$(terraform -chdir="${IAC_ROOT}/terraform/server" output -raw acm_certificate_arn)
  local file="production/infrastructure/ingress.yml"
  sed -i -E "s|${ACM_ARN_REGEX}|${arn}|" "${GITOPS_ROOT}/${file}"
  grep "certificate-arn" "${GITOPS_ROOT}/${file}"
  commit_and_maybe_push "$file" "chore(gitops): sincroniza ARN do ACM de produção (${arn##*/})"
}

sync_staging_acm() {
  log "Lendo staging_backend_acm_certificate_arn da stack server..."
  local arn
  arn=$(terraform -chdir="${IAC_ROOT}/terraform/server" output -raw staging_backend_acm_certificate_arn)
  local file="staging/ingress.yml"
  sed -i -E "s|${ACM_ARN_REGEX}|${arn}|" "${GITOPS_ROOT}/${file}"
  grep "certificate-arn" "${GITOPS_ROOT}/${file}"
  commit_and_maybe_push "$file" "chore(gitops): sincroniza ARN do ACM do backend de staging (${arn##*/})"
}

sync_staging_pghost() {
  log "Lendo staging_aurora_writer_endpoint (workspace staging)..."
  local serverless_dir="${IAC_ROOT}/terraform/serverless"
  local pghost
  # ADR-0023: workspace em vez de `terraform init -reconfigure` ida e volta. Alem de
  # ser um comando so', nao mexe na configuracao de backend do diretorio — o antigo
  # vaivem deixava o diretorio apontando para a state key errada se o script morresse
  # no meio.
  ( cd "$serverless_dir"
    terraform workspace select staging >/dev/null
    terraform output -raw staging_aurora_writer_endpoint > /tmp/.sync-gitops-pghost
    terraform workspace select default >/dev/null
  )
  pghost=$(cat /tmp/.sync-gitops-pghost); rm -f /tmp/.sync-gitops-pghost
  local file="staging/seed-job.yml"
  # Delimitador `#`, não `|` — o `|` já é usado como operador de alternação
  # dentro de PGHOST_REGEX; usá-lo também como delimitador do sed quebra o comando.
  sed -i -E "s#${PGHOST_REGEX}#${pghost}#" "${GITOPS_ROOT}/${file}"
  grep "PGHOST" -A1 "${GITOPS_ROOT}/${file}"
  commit_and_maybe_push "$file" "chore(gitops): sincroniza endpoint do Aurora writer de staging"
}

case "$TARGET" in
  prod-acm)       sync_prod_acm ;;
  staging-acm)    sync_staging_acm ;;
  staging-pghost) sync_staging_pghost ;;
  all)            sync_prod_acm; sync_staging_acm; sync_staging_pghost ;;
  *) echo "Alvo desconhecido: ${TARGET} (use prod-acm | staging-acm | staging-pghost | all)"; exit 1 ;;
esac
