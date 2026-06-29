#!/usr/bin/env bash
# Wrapper de auto-recuperação: ao receber 401/403, roda ./refresh.sh e tenta UMA vez.
# Uso: ./svc-curl.sh -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/..."
# Como o refresh re-busca do Bitwarden via token de máquina, NÃO há prompt de senha.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
load(){ set -a; source "$HOME/.config/claude-creds/secrets.env"; set +a; }
load
code=$(curl -s -o /tmp/_svc_body -w '%{http_code}' "$@"); cat /tmp/_svc_body
if [ "$code" = 401 ] || [ "$code" = 403 ]; then
  echo "↻ $code — rodando refresh e tentando de novo…" >&2
  "$HERE/refresh.sh" >/dev/null && load
  curl -s "$@"
fi
