#!/usr/bin/env bash
# cluster-access.sh — kubeconfig + túnel SSM para o control plane (ADR-0023).
# Substitui as antigas Fases 5.4 e 5.5 do runbook (send-command + montagem manual do
# túnel em dois terminais).
#
# O cluster é kubeadm self-managed em subnets privadas: não há endpoint público de API.
# O acesso é sempre por port forwarding do SSM contra o NLB interno (ADR-0002).
#
# Uso:
#   ./cluster-access.sh kubeconfig   — baixa o admin.conf e aponta para localhost:6443
#   ./cluster-access.sh tunnel       — abre o túnel (bloqueia; deixe o terminal aberto)
#   ./cluster-access.sh              — kubeconfig e, em seguida, tunnel

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib-common.sh"

KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/config-devopsproject}"

first_control_plane() {
  aws ec2 describe-instances \
    --filters "Name=tag:aws:autoscaling:groupName,Values=${CLUSTER_NAME}-control-plane" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$REGION"
}

fetch_kubeconfig() {
  local cp cmd_id status
  cp=$(first_control_plane)
  [[ -z "$cp" || "$cp" == "None" ]] && err "nenhum control plane em execução — o Estágio 1 rodou?"
  log "Baixando o kubeconfig de $cp"

  cmd_id=$(aws ssm send-command --instance-ids "$cp" \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["cat /etc/kubernetes/admin.conf"]}' \
    --query "Command.CommandId" --output text --region "$REGION")

  # O send-command é assíncrono: sem esperar o status, o get-command-invocation
  # devolve vazio e o kubeconfig sai truncado.
  for _ in $(seq 1 20); do
    sleep 3
    status=$(aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$cp" \
      --query "Status" --output text --region "$REGION" 2>/dev/null || echo Pending)
    [[ "$status" == "Success" ]] && break
    [[ "$status" == "Failed"  ]] && err "SSM command falhou no control plane"
  done
  [[ "$status" == "Success" ]] || err "timeout aguardando o SSM command"

  mkdir -p "$(dirname "$KUBECONFIG_PATH")"
  aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$cp" \
    --query "StandardOutputContent" --output text --region "$REGION" > "$KUBECONFIG_PATH"
  chmod 600 "$KUBECONFIG_PATH"

  # O certificado do apiserver tem o DNS do NLB no SAN, não "localhost" — daí o
  # insecure-skip-tls-verify no acesso via túnel.
  KUBECONFIG="$KUBECONFIG_PATH" kubectl config set-cluster "$CLUSTER_NAME" \
    --server=https://localhost:6443 --insecure-skip-tls-verify=true >/dev/null

  ok "kubeconfig salvo em $KUBECONFIG_PATH"
  echo "    export KUBECONFIG=$KUBECONFIG_PATH"
}

open_tunnel() {
  local cp nlb
  cp=$(first_control_plane)
  nlb=$(terraform -chdir="${TERRAFORM_DIR}/server" output -raw nlb_dns_name)
  log "Abrindo o túnel SSM: localhost:6443 -> $nlb:6443 (via $cp)"
  warn "Mantenha este terminal aberto. Em outro terminal: export KUBECONFIG=$KUBECONFIG_PATH"
  exec aws ssm start-session --target "$cp" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$nlb\"],\"portNumber\":[\"6443\"],\"localPortNumber\":[\"6443\"]}" \
    --region "$REGION"
}

case "${1:-all}" in
  kubeconfig) fetch_kubeconfig ;;
  tunnel)     open_tunnel ;;
  all)        fetch_kubeconfig; open_tunnel ;;
  *) err "uso: $0 [kubeconfig|tunnel]" ;;
esac
