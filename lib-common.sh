#!/usr/bin/env bash
# lib-common.sh — helpers compartilhados pelos scripts do deploy (ADR-0023).
# Não é executável por si só; use `source`.

REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-692430448478}"
DOMAIN="${DOMAIN:-ecommerce-devopsproject.com}"
CLUSTER_NAME="${CLUSTER_NAME:-ecommerce-devopsproject-cluster}"
APP_REPO="${APP_REPO:-jlui70/devopsproject-ecommerce}"
STATE_BUCKET="${STATE_BUCKET:-devopsproject-terraform-state-${ACCOUNT_ID}}"

IAC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${IAC_ROOT}/terraform"
ANSIBLE_DIR="${IAC_ROOT}/ansible"

DRY_RUN="${DRY_RUN:-false}"

log()  { echo -e "\n\033[1;34m▶ $*\033[0m"; }
ok()   { echo -e "\033[1;32m  ✓ $*\033[0m"; }
warn() { echo -e "\033[1;33m  ⚠ $*\033[0m"; }
err()  { echo -e "\033[1;31m  ✗ $*\033[0m"; exit 1; }

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  \033[90m[dry-run] $*\033[0m"
  else
    eval "$@"
  fi
}

# ─── Senhas em SSM (ADR-0023) ───────────────────────────────────────────────
#
# Até o ADR-0023 as senhas viviam em `export TF_VAR_...='<senha>'` espalhados por
# três fases do runbook, e a do Grafana aparecia em texto puro em sete pontos do
# documento. Agora existem uma única vez, como SecureString no SSM Parameter Store,
# e todo consumidor (Terraform, Ansible, teardown) lê de lá.
#
# Mapa: <parâmetro SSM> -> <variável de ambiente exportada>
SSM_SECRETS=(
  "/devopsproject/terraform/aurora-master-password:TF_VAR_aurora_master_password"
  "/devopsproject/terraform/app-identity-admin-password:TF_VAR_app_identity_admin_password"
  "/devopsproject/terraform/staging-app-identity-admin-password:TF_VAR_staging_app_identity_admin_password"
  "/devopsproject/terraform/opensearch-master-password:TF_VAR_opensearch_master_password"
  "/devopsproject/grafana/admin-password:GRAFANA_ADMIN_PASSWORD"
)

ssm_get() {
  aws ssm get-parameter --name "$1" --with-decryption \
    --query Parameter.Value --output text --region "$REGION" 2>/dev/null
}

# Gera senha compatível com as exigências de Aurora/DocumentDB/OpenSearch FGAC:
# maiúscula, minúscula, dígito e símbolo, sem caracteres que quebrem shell/URI
# (aspas, barras, @, :, espaço) — o `@` e os `:` já causaram problema em connection
# string ADO.NET neste projeto.
gen_password() {
  local base
  base=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 28)
  echo "Dp!${base}9Za"
}

seed_ssm_secrets() {
  log "Semeando senhas no SSM Parameter Store (idempotente — nunca sobrescreve)"
  local entry name value
  for entry in "${SSM_SECRETS[@]}"; do
    name="${entry%%:*}"
    if value=$(ssm_get "$name") && [[ -n "$value" && "$value" != "None" ]]; then
      ok "já existe: $name"
      continue
    fi
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  \033[90m[dry-run] aws ssm put-parameter --name $name --type SecureString --value '<gerada>'\033[0m"
      continue
    fi
    aws ssm put-parameter --name "$name" --type SecureString \
      --value "$(gen_password)" --region "$REGION" >/dev/null
    ok "criado: $name"
  done
  warn "As senhas foram geradas automaticamente. Para definir uma manualmente:"
  echo "    aws ssm put-parameter --name <nome> --type SecureString --value '<senha>' --overwrite --region $REGION"
}

# Exporta TF_VAR_* / GRAFANA_ADMIN_PASSWORD a partir do SSM. Chamado antes de
# qualquer apply — substitui os `export TF_VAR_...` manuais do runbook antigo.
load_ssm_secrets() {
  local entry name var value missing=()
  for entry in "${SSM_SECRETS[@]}"; do
    name="${entry%%:*}"; var="${entry##*:}"
    value=$(ssm_get "$name") || value=""
    if [[ -z "$value" || "$value" == "None" ]]; then
      missing+=("$name")
      continue
    fi
    export "$var=$value"
  done
  if (( ${#missing[@]} > 0 )); then
    # Em --dry-run o objetivo é revisar o plano de execução, não executá-lo — falhar
    # aqui esconderia os estágios seguintes de quem só quer conferir a sequência.
    if [[ "$DRY_RUN" == true ]]; then
      warn "Parâmetros SSM ausentes (${#missing[@]}): ${missing[*]}"
      return 0
    fi
    err "Parâmetros SSM ausentes: ${missing[*]} — rode './bootstrap.sh 0' primeiro (Estágio 0)."
  fi
  ok "senhas carregadas do SSM (${#SSM_SECRETS[@]} parâmetros)"
}

# ─── Gates ──────────────────────────────────────────────────────────────────

# Espera o ALB publicado pelo Ingress do GitOps. É a única dependência circular
# genuína do projeto (stack `site` -> ALB -> Ingress -> ArgoCD -> Ansible) e por
# isso vira um gate explícito entre os Estágios 4 e 5 (ADR-0023).
wait_for_alb() {
  local name="$1" timeout="${2:-600}" waited=0 state
  log "Aguardando o ALB '$name' ficar active (timeout ${timeout}s)"
  [[ "$DRY_RUN" == true ]] && { echo -e "  \033[90m[dry-run] aguardaria o ALB $name\033[0m"; return 0; }
  while (( waited < timeout )); do
    state=$(aws elbv2 describe-load-balancers --names "$name" \
      --query 'LoadBalancers[0].State.Code' --output text --region "$REGION" 2>/dev/null || echo "none")
    [[ "$state" == "active" ]] && { ok "ALB $name active"; return 0; }
    printf '.'; sleep 15; waited=$((waited + 15))
  done
  err "ALB '$name' não ficou active em ${timeout}s. O ArgoCD sincronizou o ingress.yml? kubectl -n dpe get ingress"
}

# Delegação de nameservers no registrador (Namecheap) — passo manual por natureza.
wait_for_ns_delegation() {
  local expected waited=0 timeout="${1:-1800}"
  expected=$(terraform -chdir="${TERRAFORM_DIR}/networking" output -json route53_zone_name_servers 2>/dev/null || echo "[]")
  log "Delegação de DNS — configure estes nameservers no Namecheap (Custom DNS):"
  echo "$expected" | python3 -c "import json,sys; [print('    '+n) for n in json.load(sys.stdin)]" 2>/dev/null || echo "$expected"
  [[ "$DRY_RUN" == true ]] && { echo -e "  \033[90m[dry-run] aguardaria a propagação de NS\033[0m"; return 0; }
  echo "  Aguardando a propagação (Ctrl+C interrompe; o estágio pode ser retomado depois)..."
  while (( waited < timeout )); do
    if dig NS +short "$DOMAIN" 2>/dev/null | grep -q "awsdns"; then
      ok "delegação ativa — Route 53 é autoritativo para $DOMAIN"
      return 0
    fi
    printf '.'; sleep 30; waited=$((waited + 30))
  done
  err "NS ainda não propagaram após ${timeout}s. Confira o painel do Namecheap e rode o estágio de novo."
}
