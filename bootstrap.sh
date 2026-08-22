#!/usr/bin/env bash
# bootstrap.sh — deploy do zero do ambiente ecommerce-devopsproject (ADR-0023).
#
# Espelho do teardown.sh, na direção oposta. Automatiza o RUNBOOK-deploy-do-zero-comandos.md
# sem substituí-lo: cada estágio abaixo corresponde a um estágio do runbook, e os comandos
# executados aqui são exatamente os que estão documentados lá. Os aprovadores podem seguir
# o runbook comando a comando ou usar este script — o resultado é o mesmo.
#
# Uso:
#   ./bootstrap.sh                 — estágios 1 a 5
#   ./bootstrap.sh <estágio>       — apenas um estágio
#   ./bootstrap.sh --dry-run       — mostra os comandos sem executar
#
# Estágios:
#   0 | secrets    Semeia as senhas no SSM (uma vez por conta)
#   1 | foundation backend -> networking -> [gate: delegação NS] -> server
#   2 | platform   serverless(prod+staging), observability, cicd -> secrets e repo do GitHub
#   3 | artifacts  pipeline em modo bootstrap (imagens + tags) -> sync do GitOps
#   4 | cluster    ansible-playbook site.yml (execução única) -> [gate: ALB]
#   5 | edge       site (CloudFront + S3 + WAF + Route 53)
#
# A ordem acima é o resequenciamento do ADR-0023: `serverless` e `observability` vêm
# ANTES do Ansible porque só dependem de `server` — é isso que elimina as reexecuções
# do playbook que o runbook antigo exigia nas Fases 8.4 e 10.3.

set -euo pipefail

# Respeita DRY_RUN vindo do ambiente: `DRY_RUN=true ./script.sh` antes zerava esta
# variavel e executava de verdade — alguem convencido de estar em dry-run acabava
# aplicando/destruindo. A flag --dry-run continua funcionando normalmente.
DRY_RUN="${DRY_RUN:-false}"
STAGE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) STAGE="$arg" ;;
  esac
done
export DRY_RUN

# shellcheck source=lib-common.sh
source "$(cd "$(dirname "$0")" && pwd)/lib-common.sh"

TFVARS='-var-file="envs/production.tfvars"'

tf_apply() {
  local stack="$1" extra="${2:-}"
  log "terraform apply: $stack"
  run "cd \"$TERRAFORM_DIR/$stack\" && terraform init -input=false"
  run "cd \"$TERRAFORM_DIR/$stack\" && terraform validate"
  run "cd \"$TERRAFORM_DIR/$stack\" && terraform apply $TFVARS -auto-approve $extra"
  ok "$stack aplicada"
}

# ─── Estágio 0 — senhas ─────────────────────────────────────────────────────
stage_secrets() {
  log "ESTÁGIO 0 — senhas no SSM e configuração do repositório"
  seed_ssm_secrets

  # A branch protection sobrevive entre ciclos (o teardown zera a AWS, nunca o GitHub).
  # Um ciclo anterior com enforce_admins=true bloqueia até o dono do repositório — e o
  # Estágio 0 do RUNBOOK precisa empurrar o workflow com o input `bootstrap` para a
  # `develop` antes do Estágio 3 conseguir dispará-lo. Por isso isto roda aqui, e não
  # no Estágio 2 como na primeira versão do ADR-0023.
  log "Configurando o repositório do GitHub"
  run "\"$IAC_ROOT/setup-github-repo.sh\""
}

# ─── Estágio 1 — fundação ───────────────────────────────────────────────────
stage_foundation() {
  log "ESTÁGIO 1 — fundação (backend, networking, DNS, server)"
  command -v terraform >/dev/null || err "terraform não encontrado"
  command -v aws       >/dev/null || err "aws CLI não encontrado"

  tf_apply "backend"
  tf_apply "networking"
  wait_for_ns_delegation
  # ACM da stack `server` valida por DNS — sem a delegação ativa, o apply trava no
  # aws_acm_certificate_validation até estourar o timeout.
  tf_apply "server"

  log "Salvando a chave SSH das instâncias"
  run "rm -f ~/.ssh/devopsproject-nodes.pem"
  run "terraform -chdir=\"$TERRAFORM_DIR/server\" output -raw ec2_key_pair_private_key > ~/.ssh/devopsproject-nodes.pem"
  run "chmod 400 ~/.ssh/devopsproject-nodes.pem"
  ok "ESTÁGIO 1 concluído"
}

# ─── Estágio 2 — dados, observabilidade e identidade de CI/CD ───────────────
stage_platform() {
  log "ESTÁGIO 2 — serverless, observability, cicd"
  load_ssm_secrets

  # Passo 2.2 do RUNBOOK. Faltava aqui: num clone novo os diretórios build/ não
  # existem e o apply da `serverless` falha ao empacotar as Lambdas. Só compila o que
  # estiver faltando — num clone que já rodou um ciclo, é no-op.
  log "Verificando os builds das Lambdas"
  local lam="${TERRAFORM_DIR}/serverless/lambdas" fn
  for fn in layer order-confirmed report-job; do
    if [[ -d "${lam}/${fn}/build" ]]; then
      ok "build presente: ${fn}"
    else
      log "  compilando ${fn}"
      run "cd \"${lam}/${fn}\" && npm install && npm run build"
    fi
  done

  tf_apply "serverless"

  # ADR-0012 + ADR-0023: staging é um WORKSPACE da mesma stack, não uma troca manual
  # de state key. `-or-create` torna o estágio repetível num ambiente novo.
  log "terraform apply: serverless (workspace staging)"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform workspace select -or-create staging"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform apply $TFVARS -var-file=\"envs/staging.tfvars\" -auto-approve"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform workspace select default"
  ok "serverless (staging) aplicada"

  tf_apply "observability"
  tf_apply "cicd"

  log "Publicando os secrets de CI/CD"
  run "\"$IAC_ROOT/sync-github-secrets.sh\""
  ok "ESTÁGIO 2 concluído — CI/CD pronto antes do cluster existir"
}

# ─── Estágio 3 — artefatos ──────────────────────────────────────────────────
stage_artifacts() {
  log "ESTÁGIO 3 — imagens publicadas pelo pipeline (modo bootstrap)"
  command -v gh >/dev/null || err "gh CLI não encontrado (necessário para disparar o pipeline)"

  # ADR-0023: a primeira imagem que chega ao cluster também passa pelo pipeline, em vez
  # de sair de um `build-push-ecr.sh` rodando na máquina do operador. O modo bootstrap
  # pula o smoke test e a promoção, que ainda não teriam como funcionar aqui.
  run "gh workflow run deploy-backend.yml --repo \"$APP_REPO\" --ref develop -f bootstrap=true"
  if [[ "$DRY_RUN" != true ]]; then
    warn "Acompanhe o run em: https://github.com/${APP_REPO}/actions"
    warn "Aguardando a conclusão (o run publica as 6 imagens e escreve as tags nos dois overlays)..."
    sleep 15
    gh run watch --repo "$APP_REPO" "$(gh run list --repo "$APP_REPO" --workflow deploy-backend.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
  fi

  log "Sincronizando os outputs do Terraform com o repositório GitOps"
  run "\"$IAC_ROOT/sync-gitops-outputs.sh\" all --push"
  ok "ESTÁGIO 3 concluído"
}

# ─── Estágio 4 — cluster ────────────────────────────────────────────────────
stage_cluster() {
  log "ESTÁGIO 4 — provisionamento do cluster Kubernetes (execução única do Ansible)"
  command -v ansible-playbook >/dev/null || err "ansible-playbook não encontrado"

  run "cd \"$ANSIBLE_DIR\" && ansible all -m ping"
  # Uma única execução: observability e serverless já existem (Estágio 2), então o
  # Fluent Bit instala aqui e o ArgoCD aplica as duas Applications e cria os dois pull
  # secrets nesta mesma passada. Nenhum `--tags` de retorno é necessário (ADR-0023).
  run "cd \"$ANSIBLE_DIR\" && ansible-playbook site.yml"

  wait_for_alb "dpe-ingress-prod"
  ok "ESTÁGIO 4 concluído"
}

# ─── Estágio 5 — borda ──────────────────────────────────────────────────────
stage_edge() {
  log "ESTÁGIO 5 — borda (CloudFront, S3, WAF, Route 53)"
  # A stack `site` lê o ALB por nome (data.aws_lb.cluster) — o gate do Estágio 4
  # garante que ele já existe.
  tf_apply "site"

  # As roles de frontend ficaram na stack `site` (escopam permissões sobre os buckets e
  # distribuições dela), então só agora os secrets FRONTEND_* podem ser publicados.
  log "Completando os secrets de frontend"
  run "\"$IAC_ROOT/sync-github-secrets.sh\""

  log "Criando o index pattern no OpenSearch Dashboards"
  run "\"$IAC_ROOT/opensearch-index-pattern.sh\" || true"
  ok "ESTÁGIO 5 concluído — valide com: curl -I https://${DOMAIN}"
}

case "${STAGE:-all}" in
  0|secrets)     stage_secrets ;;
  1|foundation)  stage_foundation ;;
  2|platform)    stage_platform ;;
  3|artifacts)   stage_artifacts ;;
  4|cluster)     stage_cluster ;;
  5|edge)        stage_edge ;;
  all)
    stage_foundation
    stage_platform
    stage_artifacts
    stage_cluster
    stage_edge
    log "Deploy concluído. Prossiga para o Estágio 6 (testes de aceite) no RUNBOOK."
    ;;
  *) err "Estágio desconhecido: '$STAGE'. Use --help." ;;
esac
