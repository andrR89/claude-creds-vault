#!/usr/bin/env bash
# Testa cada cluster OpenShift (OKD_<ENV>_CONSOLE_URL / OKD_<ENV>_API_URL). 1 linha por cluster.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
found=0
for env in $(okd_envs); do
  found=1
  code="$(okd_status "$env" 2>/dev/null)"
  if ! [[ "$code" =~ ^[0-9]{3}$ ]]; then   # auth falhou → reporta HTTP cru p/ falhar honesto
    if [ "$(okd_kind "$env")" = console ]; then
      code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$(_okd_console "$env")/api/kubernetes/version")"
    else
      code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$(_okd_api "$env")/oapi/v1/users/~")"
    fi
  fi
  echo "openshift ($env): $code"
done
[ "$found" = 1 ] || echo "openshift: nenhum OKD_<ENV>_CONSOLE_URL/_API_URL definido"
