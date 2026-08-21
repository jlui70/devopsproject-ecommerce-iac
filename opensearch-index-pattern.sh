#!/usr/bin/env bash
# opensearch-index-pattern.sh — cria o index pattern `devopsproject-logs*` no
# OpenSearch Dashboards via API (ADR-0023). Substitui o passo de UI da antiga Fase 8.5.
#
# Sem o index pattern, o Discover do Dashboards não mostra nada mesmo com o Fluent Bit
# enviando documentos corretamente — o que na demonstração parece falha da stack de
# observabilidade e não é.
#
# Uso: ./opensearch-index-pattern.sh

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib-common.sh"

INDEX_PATTERN="${INDEX_PATTERN:-devopsproject-logs*}"
TIME_FIELD="${TIME_FIELD:-@timestamp}"

DASHBOARDS_URL=$(terraform -chdir="${TERRAFORM_DIR}/observability" output -raw opensearch_dashboards_url 2>/dev/null || echo "")
[[ -z "$DASHBOARDS_URL" ]] && err "output opensearch_dashboards_url indisponível — a stack 'observability' foi aplicada?"
DASHBOARDS_URL="${DASHBOARDS_URL%/}"

PASSWORD=$(ssm_get /devopsproject/opensearch/master-password)
[[ -z "$PASSWORD" || "$PASSWORD" == "None" ]] && err "senha do OpenSearch não encontrada em /devopsproject/opensearch/master-password"

if [[ "$DRY_RUN" == true ]]; then
  echo -e "  \033[90m[dry-run] criaria o index pattern '$INDEX_PATTERN' em $DASHBOARDS_URL\033[0m"
  exit 0
fi

# O Fluent Bit precisa ter indexado ao menos um documento — sem índice, o Dashboards
# cria o pattern mas ele aparece com "0 indices" e nenhum campo mapeado.
log "Aguardando o primeiro documento indexado por Fluent Bit"
for i in $(seq 1 30); do
  count=$(curl -s -u "admin:${PASSWORD}" "${DASHBOARDS_URL%/_dashboards}/devopsproject-logs*/_count" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo 0)
  [[ "${count:-0}" -gt 0 ]] && { ok "$count documentos indexados"; break; }
  printf '.'; sleep 10
  [[ $i -eq 30 ]] && warn "nenhum documento ainda — criando o pattern mesmo assim (kubectl get pods -n logging)"
done

log "Criando o index pattern '$INDEX_PATTERN'"
http_code=$(curl -s -o /tmp/os-index-pattern.out -w "%{http_code}" \
  -u "admin:${PASSWORD}" \
  -X POST "${DASHBOARDS_URL}/api/saved_objects/index-pattern/${INDEX_PATTERN}" \
  -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
  -d "{\"attributes\":{\"title\":\"${INDEX_PATTERN}\",\"timeFieldName\":\"${TIME_FIELD}\"}}")

case "$http_code" in
  200|201) ok "index pattern criado" ;;
  # 409 = já existe: o script é idempotente por natureza, rodar de novo não é erro.
  409)     ok "index pattern já existia" ;;
  *)       cat /tmp/os-index-pattern.out; err "falha ao criar o index pattern (HTTP $http_code)" ;;
esac
rm -f /tmp/os-index-pattern.out

echo "    Dashboards: ${DASHBOARDS_URL}  (usuário admin)"
