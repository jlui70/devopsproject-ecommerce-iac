#!/usr/bin/env bash
# Backup do estado atual antes da implantação ADR-0009
# Rodar no control-plane (via SSM session) ANTES de executar o playbook

set -euo pipefail
KUBECONFIG=/etc/kubernetes/admin.conf
BACKUP_DIR="/tmp/backup-pre-adr009-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "==> Salvando estado em $BACKUP_DIR"

# Helm releases atuais
helm list -A --kubeconfig "$KUBECONFIG" > "$BACKUP_DIR/helm-releases.txt"

# Values e manifest do cluster-autoscaler
helm get values  cluster-autoscaler -n kube-system --kubeconfig "$KUBECONFIG" > "$BACKUP_DIR/ca-values.yaml"
helm get manifest cluster-autoscaler -n kube-system --kubeconfig "$KUBECONFIG" > "$BACKUP_DIR/ca-manifest.yaml"

# Estado dos pods e nós
kubectl --kubeconfig "$KUBECONFIG" get pods -A -o wide > "$BACKUP_DIR/pods.txt"
kubectl --kubeconfig "$KUBECONFIG" get nodes -o wide > "$BACKUP_DIR/nodes.txt"

# ScaledObjects (KEDA)
kubectl --kubeconfig "$KUBECONFIG" get scaledobject -A > "$BACKUP_DIR/scaledobjects.txt" 2>/dev/null || true

# Namespace monitoring (deve estar vazio antes do apply)
kubectl --kubeconfig "$KUBECONFIG" get all -n monitoring > "$BACKUP_DIR/monitoring-ns.txt" 2>/dev/null || echo "(namespace monitoring não existe ainda)" > "$BACKUP_DIR/monitoring-ns.txt"

echo ""
echo "==> Backup salvo em $BACKUP_DIR"
echo ""
echo "==> Rollback rápido se necessário:"
echo "    # Reverter cluster-autoscaler para revisão anterior:"
echo "    helm rollback cluster-autoscaler -n kube-system --kubeconfig $KUBECONFIG"
echo ""
echo "    # Remover overprovisioning:"
echo "    kubectl delete deployment overprovisioning -n kube-system --kubeconfig $KUBECONFIG"
echo "    kubectl delete priorityclass overprovisioning --kubeconfig $KUBECONFIG"
echo ""
echo "    # Remover priority-expander ConfigMap:"
echo "    kubectl delete configmap cluster-autoscaler-priority-expander -n kube-system --kubeconfig $KUBECONFIG"
echo ""
echo "    # Remover kube-prometheus-stack (se precisar):"
echo "    helm uninstall kube-prometheus-stack -n monitoring --kubeconfig $KUBECONFIG"
ls "$BACKUP_DIR"
