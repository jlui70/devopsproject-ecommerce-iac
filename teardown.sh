#!/usr/bin/env bash
# teardown.sh — Destroy completo do ambiente ecommerce-devopsproject
# Automatiza o RUNBOOK-destroy.md. Preserva a stack backend (S3/DynamoDB do state).
# Baseado na validação de 2026-07-23.
#
# Uso:
#   ./teardown.sh            — executa tudo (fases 1 a 5)
#   ./teardown.sh --dry-run  — mostra os comandos sem executar

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REGION="us-east-1"
CLUSTER_NAME="ecommerce-devopsproject-cluster"
TERRAFORM_DIR="$(cd "$(dirname "$0")/terraform" && pwd)"
S3_BUCKETS=(
  "ecommerce-devopsproject.com"
  "ecommerce-devopsproject.com-logs"
  "ecommerce-devopsproject.com-staging"
  "ecommerce-devopsproject.com-staging-logs"
  "app-staging.ecommerce-devopsproject.com"
)

# ─── helpers ────────────────────────────────────────────────────────────────

log()  { echo -e "\n\033[1;34m▶ $*\033[0m"; }
ok()   { echo -e "\033[1;32m  ✓ $*\033[0m"; }
warn() { echo -e "\033[1;33m  ⚠ $*\033[0m"; }
err()  { echo -e "\033[1;31m  ✗ $*\033[0m"; exit 1; }

run() {
  if $DRY_RUN; then
    echo -e "  \033[90m[dry-run] $*\033[0m"
  else
    eval "$@"
  fi
}

wait_ssm_command() {
  local cmd_id="$1" instance_id="$2"
  echo -n "  aguardando SSM command $cmd_id"
  for i in $(seq 1 30); do
    sleep 5
    status=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" --instance-id "$instance_id" \
      --region "$REGION" --query "Status" --output text 2>/dev/null || echo "Pending")
    echo -n "."
    [[ "$status" == "Success" ]] && { echo " OK"; return 0; }
    [[ "$status" == "Failed"  ]] && { echo " FALHOU"; return 1; }
  done
  echo " timeout"
  return 1
}

# ─── pré-checagem ───────────────────────────────────────────────────────────

log "Verificando pré-requisitos"
command -v aws      >/dev/null || err "aws CLI não encontrado"
command -v terraform >/dev/null || err "terraform não encontrado"
command -v python3  >/dev/null || err "python3 não encontrado"
aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1 || err "Credenciais AWS inválidas"
ok "pré-requisitos OK"

# ─── IDs dinâmicos ──────────────────────────────────────────────────────────

log "Buscando IDs dinâmicos na AWS"

ACCOUNT_ID=$(aws sts get-caller-identity --region "$REGION" --query "Account" --output text)
VELERO_BUCKET="devopsproject-velero-backups-${ACCOUNT_ID}"
ok "Account ID: $ACCOUNT_ID | Velero bucket: $VELERO_BUCKET"

CONTROL_PLANE_INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:aws:autoscaling:groupName,Values=${CLUSTER_NAME}-control-plane" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || echo "")

[[ -z "$CONTROL_PLANE_INSTANCE_ID" || "$CONTROL_PLANE_INSTANCE_ID" == "None" ]] \
  && warn "Control plane não encontrado — fase 1 será pulada" \
  || ok "Control plane: $CONTROL_PLANE_INSTANCE_ID"

HOSTED_ZONE_ID=$(cd "$TERRAFORM_DIR/networking" && \
  terraform output -raw route53_zone_id 2>/dev/null || \
  aws route53 list-hosted-zones --query "HostedZones[?Name=='ecommerce-devopsproject.com.'].Id" \
    --output text | sed 's|/hostedzone/||' || echo "")

[[ -z "$HOSTED_ZONE_ID" ]] \
  && warn "Hosted Zone não encontrada — fase 3 será pulada" \
  || ok "Hosted Zone: $HOSTED_ZONE_ID"

# ─── FASE 1 — remover recursos Kubernetes ───────────────────────────────────

log "FASE 1 — Deletar namespaces via SSM"

if [[ -z "$CONTROL_PLANE_INSTANCE_ID" || "$CONTROL_PLANE_INSTANCE_ID" == "None" ]]; then
  warn "Control plane não está running — pulando fase 1"
else
  log "1.1 Deletando namespace dpe"
  if ! $DRY_RUN; then
    CMD_ID=$(aws ssm send-command \
      --region "$REGION" \
      --instance-ids "$CONTROL_PLANE_INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete namespace dpe --timeout=120s && echo DPE_OK || echo DPE_SKIP"]' \
      --query "Command.CommandId" --output text)
    wait_ssm_command "$CMD_ID" "$CONTROL_PLANE_INSTANCE_ID" || warn "Namespace dpe pode já ter sido deletado"
  else
    run "aws ssm send-command --region $REGION --instance-ids $CONTROL_PLANE_INSTANCE_ID --document-name AWS-RunShellScript --parameters 'commands=[...]'"
  fi

  log "1.2 Deletando namespaces argocd e argo-rollouts"
  if ! $DRY_RUN; then
    CMD_ID=$(aws ssm send-command \
      --region "$REGION" \
      --instance-ids "$CONTROL_PLANE_INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete namespace argocd argo-rollouts --timeout=60s && echo OK || echo SKIP"]' \
      --query "Command.CommandId" --output text)
    wait_ssm_command "$CMD_ID" "$CONTROL_PLANE_INSTANCE_ID" || warn "Namespaces argocd/argo-rollouts podem já ter sido deletados"
  else
    run "aws ssm send-command --region $REGION --instance-ids $CONTROL_PLANE_INSTANCE_ID --document-name AWS-RunShellScript ..."
  fi

  # 2026-08-10 (ADR-0011/0013): namespace staging tem seu proprio Ingress/ALB
  # dedicado (dpe-stg-ingress-stg) e seus proprios registros ExternalDNS
  # (staging.*). Faltava aqui antes - o ALB e os registros DNS de staging
  # ficavam orfaos apos os nodes serem terminados na FASE 4 (ExternalDNS
  # recriava os registros que a FASE 3 apagava, enquanto o namespace/Ingress
  # de staging continuava existindo e os nodes ainda estavam de pe). So roda
  # se o namespace existir (deploy sem staging não tem nada a fazer aqui).
  log "1.2b Deletando namespace staging (se existir)"
  if ! $DRY_RUN; then
    CMD_ID=$(aws ssm send-command \
      --region "$REGION" \
      --instance-ids "$CONTROL_PLANE_INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete namespace staging --timeout=60s && echo OK || echo SKIP"]' \
      --query "Command.CommandId" --output text)
    wait_ssm_command "$CMD_ID" "$CONTROL_PLANE_INSTANCE_ID" || warn "Namespace staging pode já ter sido deletado ou não existir"
  else
    run "aws ssm send-command --region $REGION --instance-ids $CONTROL_PLANE_INSTANCE_ID --document-name AWS-RunShellScript ..."
  fi

  log "1.3 Confirmando ALBs deletados (produção e staging)"
  if ! $DRY_RUN; then
    echo "  aguardando ALBs dpe-ingress/dpe-stg-ingress serem removidos pelo ALB Controller..."
    for i in $(seq 1 24); do
      ALB=$(aws elbv2 describe-load-balancers --region "$REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName,'dpe-ingress') || contains(LoadBalancerName,'ingress-stg')].LoadBalancerName" \
        --output text 2>/dev/null || echo "")
      [[ -z "$ALB" ]] && { ok "ALBs removidos"; break; }
      echo -n "  ."; sleep 10
      [[ $i -eq 24 ]] && warn "ALB(s) ainda existem após 4 min ($ALB) — verifique manualmente antes de continuar (podem ficar órfãos se os nodes forem terminados antes do ALB Controller reconciliar)"
    done
  else
    run "aws elbv2 describe-load-balancers --query \"LoadBalancers[?contains(LoadBalancerName,'dpe-ingress') || contains(LoadBalancerName,'ingress-stg')]\""
  fi
fi

# ─── FASE 2 — esvaziar S3 buckets da stack site ─────────────────────────────

log "FASE 2 — Esvaziar S3 buckets (versioning habilitado)"

for BUCKET in "${S3_BUCKETS[@]}"; do
  log "  limpando bucket: $BUCKET"
  if ! $DRY_RUN; then
    # Verifica se bucket existe
    if ! aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
      warn "Bucket $BUCKET não encontrado — pulando"
      continue
    fi

    # Delete versões
    VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET" \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null || echo '{"Objects":[]}')
    if [[ $(echo "$VERSIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Objects') or []))") -gt 0 ]]; then
      aws s3api delete-objects --bucket "$BUCKET" --delete "$VERSIONS" --region "$REGION" >/dev/null
      ok "versões deletadas em $BUCKET"
    fi

    # Delete markers
    MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET" \
      --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null || echo '{"Objects":[]}')
    if [[ $(echo "$MARKERS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Objects') or []))") -gt 0 ]]; then
      aws s3api delete-objects --bucket "$BUCKET" --delete "$MARKERS" --region "$REGION" >/dev/null
      ok "delete markers removidos de $BUCKET"
    fi
  else
    run "aws s3api delete-objects --bucket $BUCKET --delete <versions+markers>"
  fi
done

# ─── FASE 2.5 — esvaziar bucket Velero (versioning habilitado) ──────────────
# Necessário antes do terraform destroy server — sem isso o bucket não pode ser deletado

log "FASE 2.5 — Esvaziar bucket Velero: $VELERO_BUCKET"

if ! $DRY_RUN; then
  if ! aws s3api head-bucket --bucket "$VELERO_BUCKET" --region "$REGION" 2>/dev/null; then
    warn "Bucket $VELERO_BUCKET não encontrado — pulando"
  else
    VERSIONS=$(aws s3api list-object-versions --bucket "$VELERO_BUCKET" \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null || echo '{"Objects":[]}')
    if [[ $(echo "$VERSIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Objects') or []))") -gt 0 ]]; then
      aws s3api delete-objects --bucket "$VELERO_BUCKET" --delete "$VERSIONS" --region "$REGION" >/dev/null
      ok "versões deletadas em $VELERO_BUCKET"
    fi

    MARKERS=$(aws s3api list-object-versions --bucket "$VELERO_BUCKET" \
      --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null || echo '{"Objects":[]}')
    if [[ $(echo "$MARKERS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Objects') or []))") -gt 0 ]]; then
      aws s3api delete-objects --bucket "$VELERO_BUCKET" --delete "$MARKERS" --region "$REGION" >/dev/null
      ok "delete markers removidos de $VELERO_BUCKET"
    fi

    ok "bucket $VELERO_BUCKET esvaziado"
  fi
else
  run "aws s3api delete-objects --bucket $VELERO_BUCKET --delete <versions+markers>"
fi

# ─── FASE 3 — limpar Route53 (registros ExternalDNS) ───────────────────────

log "FASE 3 — Limpar registros Route53 (ExternalDNS)"

if [[ -z "$HOSTED_ZONE_ID" ]]; then
  warn "Hosted Zone não encontrada — pulando fase 3"
else
  if ! $DRY_RUN; then
python3 << PYEOF
import subprocess, json, sys

ZONE_ID = '${HOSTED_ZONE_ID}'
REGION  = '${REGION}'

result = subprocess.run([
    'aws', 'route53', 'list-resource-record-sets',
    '--hosted-zone-id', ZONE_ID, '--output', 'json'
], capture_output=True, text=True)

records = json.loads(result.stdout)['ResourceRecordSets']
changes = []
for r in records:
    if r['Type'] in ('NS', 'SOA'):
        continue
    change = {'Action': 'DELETE', 'ResourceRecordSet': {}}
    change['ResourceRecordSet']['Name'] = r['Name']
    change['ResourceRecordSet']['Type'] = r['Type']
    if 'AliasTarget' in r:
        change['ResourceRecordSet']['AliasTarget'] = r['AliasTarget']
    else:
        change['ResourceRecordSet']['TTL'] = r['TTL']
        change['ResourceRecordSet']['ResourceRecords'] = r['ResourceRecords']
    changes.append(change)

if not changes:
    print('  ✓ nenhum registro a deletar')
    sys.exit(0)

result = subprocess.run([
    'aws', 'route53', 'change-resource-record-sets',
    '--hosted-zone-id', ZONE_ID,
    '--change-batch', json.dumps({'Changes': changes})
], capture_output=True, text=True)

if result.returncode == 0:
    print(f'  ✓ {len(changes)} registro(s) deletados do Route53')
else:
    print('  ✗ erro:', result.stderr)
    sys.exit(1)
PYEOF
  else
    run "python3 route53-cleanup.py --zone $HOSTED_ZONE_ID"
  fi
fi

# ─── Aurora password (necessária para destruir a stack serverless) ───────────

if [[ -z "${TF_VAR_aurora_master_password:-}" ]]; then
  echo ""
  warn "A stack serverless requer TF_VAR_aurora_master_password para o destroy."
  echo -n "  Digite a senha do Aurora (Enter para pular — Terraform pedirá interativamente): "
  read -rs _AURORA_PWD
  echo ""
  if [[ -n "$_AURORA_PWD" ]]; then
    export TF_VAR_aurora_master_password="$_AURORA_PWD"
    ok "TF_VAR_aurora_master_password exportada"
  else
    warn "Senha não fornecida — o destroy da stack serverless pedirá a senha interativamente"
  fi
else
  ok "TF_VAR_aurora_master_password já está definida no ambiente"
fi

# ─── OpenSearch password (necessária para destruir a stack observability) ────

if [[ -z "${TF_VAR_opensearch_master_password:-}" ]]; then
  echo ""
  warn "A stack observability requer TF_VAR_opensearch_master_password para o destroy."
  echo -n "  Digite a senha do OpenSearch (Enter para pular — Terraform pedirá interativamente): "
  read -rs _OPENSEARCH_PWD
  echo ""
  if [[ -n "$_OPENSEARCH_PWD" ]]; then
    export TF_VAR_opensearch_master_password="$_OPENSEARCH_PWD"
    ok "TF_VAR_opensearch_master_password exportada"
  else
    warn "Senha não fornecida — o destroy da stack observability pedirá a senha interativamente"
  fi
else
  ok "TF_VAR_opensearch_master_password já está definida no ambiente"
fi

# ─── Senhas de admin da aplicação (achado 2026-08-17 — antes viviam em .tfvars,
# agora são variáveis top-level sem default, mesmo padrão de aurora_master_password
# acima; sem elas o destroy da stack serverless — produção E staging — pede
# interativamente e trava a automação deste script) ──────────────────────────

if [[ -z "${TF_VAR_app_identity_admin_password:-}" ]]; then
  echo ""
  warn "A stack serverless requer TF_VAR_app_identity_admin_password para o destroy."
  echo -n "  Digite a senha de admin (produção) (Enter para pular — Terraform pedirá interativamente): "
  read -rs _APP_ADMIN_PWD
  echo ""
  if [[ -n "$_APP_ADMIN_PWD" ]]; then
    export TF_VAR_app_identity_admin_password="$_APP_ADMIN_PWD"
    ok "TF_VAR_app_identity_admin_password exportada"
  else
    warn "Senha não fornecida — o destroy da stack serverless pedirá a senha interativamente"
  fi
else
  ok "TF_VAR_app_identity_admin_password já está definida no ambiente"
fi

if [[ -z "${TF_VAR_staging_app_identity_admin_password:-}" ]]; then
  echo ""
  warn "O destroy da state key de staging (serverless) requer TF_VAR_staging_app_identity_admin_password."
  echo -n "  Digite a senha de admin (staging) (Enter para pular — Terraform pedirá interativamente): "
  read -rs _STG_APP_ADMIN_PWD
  echo ""
  if [[ -n "$_STG_APP_ADMIN_PWD" ]]; then
    export TF_VAR_staging_app_identity_admin_password="$_STG_APP_ADMIN_PWD"
    ok "TF_VAR_staging_app_identity_admin_password exportada"
  else
    warn "Senha não fornecida — o destroy de staging pedirá a senha interativamente (só relevante se o state de staging existir)"
  fi
else
  ok "TF_VAR_staging_app_identity_admin_password já está definida no ambiente"
fi

# ─── FASE 4 — Terraform Destroy ─────────────────────────────────────────────

log "FASE 4 — Terraform Destroy (ordem: site → observability → serverless → server → networking)"

tf_destroy() {
  local stack="$1" extra_args="${2:-}"
  log "  destroy: $stack"
  run "cd \"$TERRAFORM_DIR/$stack\" && terraform destroy -var-file=\"envs/production.tfvars\" -auto-approve $extra_args"
  ok "$stack destruída"
}

# site: -refresh=false porque o ALB já foi deletado na fase 1
tf_destroy "site" "-refresh=false"

# observability: OpenSearch leva 10-15 min
warn "observability pode levar 10–15 min (OpenSearch)..."
tf_destroy "observability"

# 2026-08-10 (ADR-0012): staging vive numa state key SEPARADA da mesma stack
# serverless (serverless/staging/terraform.tfstate) e le SGs/subnet groups de
# producao via terraform_remote_state — por isso precisa ser destruida ANTES da
# serverless de producao (senao o destroy de staging falha tentando ler outputs
# de um state que ja nao existe mais). Só executa se o state de staging existir
# (deploy do zero sem staging não cria esse arquivo).
if aws s3api head-object \
    --bucket devopsproject-terraform-state-692430448478 \
    --key serverless/staging/terraform.tfstate >/dev/null 2>&1; then
  log "  destroy: serverless (staging, state key separada)"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform init -reconfigure -backend-config=\"key=serverless/staging/terraform.tfstate\" && terraform destroy -var-file=\"envs/production.tfvars\" -var-file=\"envs/staging.tfvars\" -auto-approve"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform init -reconfigure -backend-config=\"key=serverless/terraform.tfstate\""
  ok "serverless (staging) destruída"
else
  ok "sem state de staging (serverless/staging/terraform.tfstate não existe) — nada a destruir"
fi

tf_destroy "serverless"
tf_destroy "server"

# ADR-0022 (2026-08-17): o comando de join dos workers é gravado pelo Ansible via
# `aws ssm put-parameter` (roles/init-cluster/tasks/join-commands.yml), não é um
# recurso Terraform — o destroy da stack `server` acima não limpa isso, ficaria
# órfão. Não quebra o próximo ciclo (Ansible sobrescreve com --overwrite na
# próxima instalação), mas é limpeza incompleta deixar para trás.
log "Limpando SSM Parameter do comando de join (ADR-0022, não gerido pelo Terraform)"
if ! $DRY_RUN; then
  aws ssm delete-parameter --name /devopsproject/cluster/worker-join-command \
    --region "$REGION" 2>/dev/null \
    && ok "SSM Parameter removido" \
    || warn "SSM Parameter não encontrado (ok se staging/server nunca chegou a rodar Ansible)"
else
  run "aws ssm delete-parameter --name /devopsproject/cluster/worker-join-command --region $REGION"
fi

# networking: Route53 já limpo na fase 3
tf_destroy "networking" "-refresh=false"

ok "Stack backend preservada (S3 + DynamoDB do Terraform state)"

# ─── FASE 5 — verificação final ─────────────────────────────────────────────

log "FASE 5 — Verificação Final"

if ! $DRY_RUN; then
  echo ""
  echo "EC2 instances running/stopped:"
  aws ec2 describe-instances --region "$REGION" \
    --filters "Name=instance-state-name,Values=running,pending,stopped" \
    --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name}" \
    --output table 2>/dev/null || true

  echo ""
  echo "Load Balancers:"
  aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[].{Name:LoadBalancerName,Type:Type}" --output table 2>/dev/null || true

  echo ""
  echo "NAT Gateways:"
  aws ec2 describe-nat-gateways --region "$REGION" \
    --filter "Name=state,Values=available" \
    --query "NatGateways[].{ID:NatGatewayId}" --output table 2>/dev/null || true

  echo ""
  echo "RDS / DocumentDB clusters:"
  aws rds describe-db-clusters --region "$REGION" \
    --query "DBClusters[].{ID:DBClusterIdentifier,Status:Status}" --output table 2>/dev/null || true

  echo ""
  echo "OpenSearch domains:"
  aws opensearch list-domain-names --region "$REGION" \
    --query "DomainNames[].DomainName" --output table 2>/dev/null || true

  echo ""
  echo "S3 buckets restantes (backend + ansible-ssm esperados):"
  aws s3 ls --region "$REGION" 2>/dev/null || true
else
  run "aws ec2 describe-instances / elbv2 / nat-gateways / rds / opensearch / s3 ls"
fi

echo ""
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m  Teardown completo!\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
