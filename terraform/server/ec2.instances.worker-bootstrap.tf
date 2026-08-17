# ADR-0022 — auto-join de workers no boot, escopo reduzido: cobre SOMENTE scale-up
# POS-bootstrap (Cluster Autoscaler reagindo a pressao real de pods, ou ajuste manual
# do ASG), quando o cluster ja existe e o SSM Parameter abaixo ja foi populado pelo
# Ansible (roles/init-cluster/tasks/join-commands.yml, tag always, toda execucao).
#
# NAO cobre o bootstrap inicial do cluster do zero (Fase 4/5 do RUNBOOK-deploy-do-zero.md)
# — nesse cenario o control plane ainda nao existe quando os workers sobem na Fase 4,
# entao nao ha comando de join disponivel no SSM ainda. Esse caminho continua 100%
# dependente do Ansible completo (Fase 5.2), sem nenhuma mudanca. O script abaixo so'
# tem efeito pratico em workers que sobem DEPOIS do cluster ja estar de pe.
#
# Falha de forma segura: se o comando de join nao aparecer no SSM em 5 minutos (cluster
# ainda nao inicializado, ou parametro nunca foi escrito), o script aborta sem tentar
# nada destrutivo — o fallback documentado no ADR-0022 continua valendo:
#   ansible-playbook site.yml -e 'grafana_admin_password="..."' --tags join-workers
#
# Instalacao de pacotes espelha roles/{dependency-packages,container-runtime,
# kube-packages}/tasks/*.yml — kubernetes_version fixado em "1.30" aqui porque nao ha
# hoje uma fonte unica compartilhada entre Terraform e Ansible; se
# ansible/group_vars/all.yml mudar kubernetes_version, atualizar aqui tambem.
locals {
  worker_join_ssm_parameter = "/devopsproject/cluster/worker-join-command"

  worker_bootstrap_script = <<-BOOTSTRAP
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    if [ -f /etc/kubernetes/kubelet.conf ]; then
      echo "[worker-bootstrap] Node ja esta unido ao cluster, nada a fazer."
      exit 0
    fi

    REGION="${var.region}"
    SSM_PARAM="${local.worker_join_ssm_parameter}"
    KUBERNETES_VERSION="1.30"

    IMDS_TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    NODE_HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/local-hostname)

    echo "[worker-bootstrap] Instalando dependencias base (curl/gnupg/awscli)..."
    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common awscli

    echo "[worker-bootstrap] Aguardando comando de join ficar disponivel em $SSM_PARAM (ate 5min)..."
    JOIN_CMD=""
    for i in $(seq 1 30); do
      JOIN_CMD=$(aws ssm get-parameter --name "$SSM_PARAM" --with-decryption --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || true)
      if [ -n "$JOIN_CMD" ] && [ "$JOIN_CMD" != "None" ]; then
        break
      fi
      sleep 10
    done
    if [ -z "$JOIN_CMD" ] || [ "$JOIN_CMD" == "None" ]; then
      echo "[worker-bootstrap] ERRO: comando de join indisponivel em $SSM_PARAM apos 5min."
      echo "[worker-bootstrap] Causa provavel: cluster ainda nao inicializado (bootstrap do zero, nao scale-up) ou parametro nunca foi escrito."
      echo "[worker-bootstrap] Fallback: ansible-playbook site.yml -e 'grafana_admin_password=...' --tags join-workers"
      exit 1
    fi

    echo "[worker-bootstrap] Configurando kernel modules e sysctl para rede de containers..."
    cat <<MODULES > /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    MODULES
    modprobe overlay
    modprobe br_netfilter
    cat <<SYSCTL > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward = 1
    SYSCTL
    sysctl --system

    echo "[worker-bootstrap] Instalando CRI-O..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/addons:/cri-o:/stable:/v$${KUBERNETES_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v$${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/cri-o.list
    apt-get update -y
    apt-get install -y cri-o
    systemctl enable --now cri-o

    echo "[worker-bootstrap] Instalando kubelet/kubeadm/kubectl $${KUBERNETES_VERSION}..."
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$${KUBERNETES_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update -y
    apt-get install -y "kubelet=$${KUBERNETES_VERSION}.*" "kubeadm=$${KUBERNETES_VERSION}.*" "kubectl=$${KUBERNETES_VERSION}.*" cri-tools
    apt-mark hold kubelet kubeadm kubectl

    echo "[worker-bootstrap] Configurando kubelet (cloud-provider externo)..."
    echo "KUBELET_EXTRA_ARGS=--cloud-provider=external --provider-id=aws:///$${AZ}/$${INSTANCE_ID} --hostname-override=$${NODE_HOSTNAME}" > /etc/default/kubelet
    systemctl daemon-reload
    systemctl enable kubelet
    systemctl restart kubelet

    echo "[worker-bootstrap] Executando kubeadm join..."
    eval "$JOIN_CMD --node-name=$${NODE_HOSTNAME}"

    echo "[worker-bootstrap] Node $${NODE_HOSTNAME} unido ao cluster com sucesso."
  BOOTSTRAP
}
