#!/usr/bin/env bash
# Testa cada ambiente Kibana (KIBANA_BASE_URL_<ENV>). Uma linha por ambiente.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
found=0
for env in $(kibana_envs); do
  found=1
  code="$(kibana_status "$env" 2>/dev/null)"
  # sem credencial válida o status pode vir vazio → reporta o HTTP cru (ex.: 401) p/ falhar honesto
  [[ "$code" =~ ^[0-9]{3}$ ]] || code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$(_kibana_url "$env")/api/status")"
  echo "kibana ($env): $code"
done
[ "$found" = 1 ] || echo "kibana: nenhum KIBANA_BASE_URL_<ENV> definido"
