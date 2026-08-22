#!/usr/bin/env bash
# teardown.sh — Destroy completo do ambiente ecommerce-devopsproject
# Automatiza o RUNBOOK-destroy.md. Baseado na validação de 2026-07-23.
#
# Uso:
#   ./teardown.sh            — executa tudo (fases 1 a 5), preservando a stack backend
#   ./teardown.sh --full     — o mesmo, e TAMBÉM apaga a stack backend, os buckets de
#                              apoio, os parâmetros SSM e o state local: a conta volta
#                              ao dia zero e o Estágio 1.1 do RUNBOOK roda sem import
#   ./teardown.sh --dry-run  — mostra os comandos sem executar (combinável com --full)
#
# ADR-0023: --full existe porque a stack backend passou a criar os buckets de apoio
# (ansible-ssm, patch logs). Numa conta onde eles já existem fora do state, o apply da
# backend falha com BucketAlreadyOwnedByYou e exige `terraform import`. Para uma
# demonstração de instalação do zero, é mais limpo zerar a conta.

set -euo pipefail

# Respeita DRY_RUN vindo do ambiente: `DRY_RUN=true ./script.sh` antes zerava esta
# variavel e executava de verdade — alguem convencido de estar em dry-run acabava
# aplicando/destruindo. A flag --dry-run continua funcionando normalmente.
DRY_RUN="${DRY_RUN:-false}"
FULL=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --full)    FULL=true ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
  esac
done

REGION="us-east-1"
CLUSTER_NAME="ecommerce-devopsproject-cluster"
TERRAFORM_DIR="$(cd "$(dirname "$0")/terraform" && pwd)"
STATE_BUCKET="devopsproject-terraform-state-${ACCOUNT_ID:-692430448478}"
ANSIBLE_SSM_BUCKET="devopsproject-ecommerce-ansible-ssm"
PATCH_LOGS_BUCKET="devopsproject-production-logs"
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
    ALB_TIMED_OUT=false
    for i in $(seq 1 24); do
      ALB=$(aws elbv2 describe-load-balancers --region "$REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName,'dpe-ingress') || contains(LoadBalancerName,'ingress-stg')].LoadBalancerName" \
        --output text 2>/dev/null || echo "")
      [[ -z "$ALB" ]] && { ok "ALBs removidos"; break; }
      echo -n "  ."; sleep 10
      [[ $i -eq 24 ]] && ALB_TIMED_OUT=true
    done

    # Achado ao vivo em 2026-08-17: apos 4min o ALB Controller as vezes nao
    # termina a tempo (nodes ja sendo destruidos), e o ALB fica orfao —
    # bloqueia terraform destroy da stack server mais adiante com
    # "DependencyViolation" nas Security Groups (via ENI do ALB) e
    # "ResourceInUseException" no certificado ACM (listener HTTPS do ALB).
    # So' um warn aqui nao resolvia — forcar a delecao direta via API.
    if $ALB_TIMED_OUT; then
      warn "ALB(s) ainda existem após 4 min ($ALB) — deletando diretamente via API (ALB Controller não terminou a tempo)"
      for name in $ALB; do
        arn=$(aws elbv2 describe-load-balancers --names "$name" --region "$REGION" \
          --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
        if [[ -n "$arn" && "$arn" != "None" ]]; then
          aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$REGION" 2>&1 \
            && ok "ALB $name deletado diretamente" \
            || warn "Falha ao deletar $name diretamente — verifique manualmente antes de continuar"
        fi
      done
      echo "  aguardando ENIs do ALB liberarem (necessário antes do destroy das Security Groups)..."
      for i in $(seq 1 12); do
        SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" \
          --filters "Name=group-name,Values=*worker*,*control-plane*,*alb*" \
          --query "SecurityGroups[].GroupId" --output text 2>/dev/null || echo "")
        ENI_COUNT=$(aws ec2 describe-network-interfaces --region "$REGION" \
          --filters "Name=group-id,Values=$(echo $SG_IDS | tr ' ' ',')" \
          --query 'length(NetworkInterfaces)' --output text 2>/dev/null || echo "0")
        [[ "$ENI_COUNT" == "0" ]] && { ok "ENIs liberados"; break; }
        echo -n "  ."; sleep 10
        [[ $i -eq 12 ]] && warn "ENIs ainda presentes após 2min — o destroy da stack server pode falhar de novo, verifique manualmente"
      done
    fi
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

# ─── Senhas do destroy ──────────────────────────────────────────────────────
#
# ADR-0023: as senhas vivem no SSM Parameter Store. Tenta carregá-las de lá antes de
# perguntar — num ciclo normal isso elimina os quatro prompts interativos abaixo, que
# só permanecem como fallback (conta antiga, ou parâmetros já apagados por um
# `teardown.sh --full` anterior).
for _entry in \
  "/devopsproject/terraform/aurora-master-password:TF_VAR_aurora_master_password" \
  "/devopsproject/terraform/app-identity-admin-password:TF_VAR_app_identity_admin_password" \
  "/devopsproject/terraform/staging-app-identity-admin-password:TF_VAR_staging_app_identity_admin_password" \
  "/devopsproject/terraform/opensearch-master-password:TF_VAR_opensearch_master_password"; do
  _name="${_entry%%:*}"; _var="${_entry##*:}"
  if [[ -z "${!_var:-}" ]]; then
    _val=$(aws ssm get-parameter --name "$_name" --with-decryption \
             --query Parameter.Value --output text --region "$REGION" 2>/dev/null || true)
    if [[ -n "$_val" && "$_val" != "None" ]]; then
      export "$_var=$_val"
      ok "$_var carregada do SSM"
    fi
  fi
done
unset _entry _name _var _val

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

log "FASE 4 — Terraform Destroy (ordem: site → cicd → observability → serverless → server → networking)"

tf_destroy() {
  local stack="$1" extra_args="${2:-}"
  log "  destroy: $stack"
  # `terraform init` antes do destroy: sem ele, uma stack cujo diretorio .terraform nao
  # existe falha com "Backend initialization required". Isso ficava mascarado enquanto o
  # cache sobrevivia entre ciclos — o `--full` passou a limpa-lo, e stacks que nunca
  # chegaram a ser aplicadas neste ciclo (tipicamente `site`, que depende do ALB) caem
  # exatamente nesse caso. init e' idempotente e barato quando ja inicializado.
  run "cd \"$TERRAFORM_DIR/$stack\" && terraform init -input=false -reconfigure"
  run "cd \"$TERRAFORM_DIR/$stack\" && terraform destroy -var-file=\"envs/production.tfvars\" -auto-approve $extra_args"
  ok "$stack destruída"
}

# site: -refresh=false porque o ALB já foi deletado na fase 1
tf_destroy "site" "-refresh=false"

# cicd (ADR-0023): OIDC provider + roles de ECR. Depois de `site`, porque as roles
# de frontend que ficaram em `site` referenciam o OIDC provider daqui via
# terraform_remote_state — e ANTES de `server`, porque data.terraform_remote_state.server
# precisa dos outputs (ecr_repository_urls) ainda presentes no state.
#
# O guard cobre o caso de a stack nunca ter sido aplicada (conta anterior ao ADR-0023,
# ou um ciclo interrompido): sem state, o `terraform destroy` ainda avalia o data source
# e falha com "Unsupported attribute" se o state da `server` ja estiver vazio.
if aws s3api head-object \
    --bucket "$STATE_BUCKET" \
    --key cicd/terraform.tfstate >/dev/null 2>&1; then
  tf_destroy "cicd"
else
  ok "sem state de cicd — nada a destruir"
fi

# observability: OpenSearch leva 10-15 min
warn "observability pode levar 10–15 min (OpenSearch)..."
tf_destroy "observability"

# 2026-08-10 (ADR-0012) / ADR-0023: staging vive num WORKSPACE separado da mesma
# stack serverless (env:/staging/serverless/terraform.tfstate) e le SGs/subnet groups de
# producao via terraform_remote_state — por isso precisa ser destruida ANTES da
# serverless de producao (senao o destroy de staging falha tentando ler outputs
# de um state que ja nao existe mais). Só executa se o state de staging existir
# (deploy do zero sem staging não cria esse arquivo).
if aws s3api head-object \
    --bucket devopsproject-terraform-state-692430448478 \
    --key env:/staging/serverless/terraform.tfstate >/dev/null 2>&1; then
  log "  destroy: serverless (workspace staging)"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform init -input=false -reconfigure"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform workspace select staging && terraform destroy -var-file=\"envs/production.tfvars\" -var-file=\"envs/staging.tfvars\" -auto-approve"
  run "cd \"$TERRAFORM_DIR/serverless\" && terraform workspace select default"
  ok "serverless (staging) destruída"
else
  ok "sem state de staging (workspace staging não existe) — nada a destruir"
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

# ─── FASE 4.5 — backend e recursos de apoio (somente com --full) ────────────

if $FULL; then
  log "FASE 4.5 — Destruindo a stack backend e os recursos de apoio (--full)"

  warn "Isto apaga o bucket de state, a tabela de lock, os buckets de apoio e as senhas."
  warn "Só faz sentido quando NADA precisa ser preservado. NÃO é reversível."
  # O teardown normal não pergunta nada — comportamento histórico, mantido. Mas --full
  # apaga o bucket de state, e um bucket de state apagado por engano não volta.
  if ! $DRY_RUN && [[ "${TEARDOWN_FULL_YES:-}" != "true" ]]; then
    echo -n "  Digite EXCLUIR para confirmar: "
    read -r _confirm
    [[ "$_confirm" == "EXCLUIR" ]] || err "cancelado pelo operador"
  fi

  # Os buckets de apoio não pertencem a nenhuma stack destruída acima e sobrevivem a um
  # teardown normal — é justamente por isso que precisam ser tratados aqui.
  for b in "$ANSIBLE_SSM_BUCKET" "$PATCH_LOGS_BUCKET"; do
    if aws s3api head-bucket --bucket "$b" >/dev/null 2>&1; then
      log "  esvaziando e removendo: $b"
      run "aws s3 rm \"s3://$b\" --recursive --quiet || true"
      run "aws s3api delete-bucket --bucket \"$b\" --region $REGION"
      ok "$b removido"
    else
      ok "$b não existe"
    fi
  done

  # Senhas do ADR-0023 — recriadas pelo Estágio 0 do runbook.
  for p in /devopsproject/terraform/aurora-master-password \
           /devopsproject/terraform/app-identity-admin-password \
           /devopsproject/terraform/staging-app-identity-admin-password \
           /devopsproject/terraform/opensearch-master-password \
           /devopsproject/grafana/admin-password \
           /devopsproject/opensearch/master-password; do
    if aws ssm get-parameter --name "$p" --region "$REGION" >/dev/null 2>&1; then
      run "aws ssm delete-parameter --name \"$p\" --region $REGION"
      ok "parâmetro removido: $p"
    fi
  done

  # O bucket de state é versionado: delete-bucket exige remover TODAS as versões e
  # delete markers, não só os objetos correntes.
  log "  esvaziando o bucket de state (todas as versões)"
  if ! $DRY_RUN; then
    python3 - "$STATE_BUCKET" "$REGION" <<'PYEOF'
import subprocess, sys, json
bucket, region = sys.argv[1], sys.argv[2]

def aws(*args):
    return subprocess.run(["aws", *args], capture_output=True, text=True)

total = 0
for key in ("Versions", "DeleteMarkers"):
    # Limite de rodadas: sem ele, um delete-objects que falha em silencio deixa os
    # mesmos itens na listagem e o while roda para sempre.
    for _round in range(200):
        out = aws("s3api", "list-object-versions", "--bucket", bucket,
                  "--region", region, "--max-items", "500", "--output", "json")
        if out.returncode != 0:
            print(f"  aviso: list-object-versions falhou: {out.stderr.strip()[:120]}")
            break
        items = (json.loads(out.stdout or "{}") or {}).get(key) or []
        if not items:
            break
        objs = [{"Key": i["Key"], "VersionId": i["VersionId"]} for i in items]
        rm = aws("s3api", "delete-objects", "--bucket", bucket, "--region", region,
                 "--delete", json.dumps({"Objects": objs, "Quiet": True}))
        if rm.returncode != 0:
            print(f"  ERRO: delete-objects falhou: {rm.stderr.strip()[:160]}")
            sys.exit(1)
        total += len(objs)
    else:
        print(f"  ERRO: {key} nao esvaziou em 200 rodadas — abortando")
        sys.exit(1)
print(f"  {total} objetos/versoes removidos de {bucket}")
PYEOF
  else
    echo -e "  \033[90m[dry-run] remoção de todas as versões de s3://$STATE_BUCKET\033[0m"
  fi

  # terraform destroy na backend em vez de deletar na mão: mantém o state local
  # coerente e remove a tabela DynamoDB junto.
  log "  destroy: backend"
  run "cd \"$TERRAFORM_DIR/backend\" && terraform init -input=false"
  run "cd \"$TERRAFORM_DIR/backend\" && terraform destroy -var-file=\"envs/production.tfvars\" -auto-approve"

  # Sem isso, o próximo apply parte de um state que ainda referencia recursos apagados.
  run "rm -f \"$TERRAFORM_DIR/backend/terraform.tfstate\" \"$TERRAFORM_DIR/backend/terraform.tfstate.backup\""

  # Cada stack guarda em .terraform/ um cache da configuração de backend apontando para
  # o bucket que acabou de ser apagado. Sem limpar, o `terraform init` do Estágio 1.2 pode
  # reclamar de backend alterado ou tentar migrar um state que não existe mais.
  log "  limpando caches .terraform/ das stacks"
  run "find \"$TERRAFORM_DIR\" -maxdepth 2 -type d -name .terraform -exec rm -rf {} + 2>/dev/null || true"

  ok "Stack backend destruída, state local e caches zerados — conta no dia zero"
else
  ok "Stack backend preservada (S3 + DynamoDB do Terraform state)"
fi

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
  if $FULL; then
    echo "S3 buckets restantes (nenhum esperado — modo --full):"
  else
    echo "S3 buckets restantes (backend + ansible-ssm esperados):"
  fi
  aws s3 ls --region "$REGION" 2>/dev/null || true
else
  run "aws ec2 describe-instances / elbv2 / nat-gateways / rds / opensearch / s3 ls"
fi

echo ""
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m  Teardown completo!\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
