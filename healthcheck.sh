#!/usr/bin/env bash
# Testa cada serviço rodando services/*/check.sh. Não muda quando você adiciona serviço.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="$HOME/.config/claude-creds/bws-token"

command -v bws >/dev/null || { echo "❌ instale o bws"; exit 1; }
[ -f "$TOKEN_FILE" ] || { echo "❌ não achei $TOKEN_FILE"; exit 1; }
export BWS_ACCESS_TOKEN="$(cat "$TOKEN_FILE")"

echo "🔐 Carregando segredos do Bitwarden Secrets Manager…"
set -a; source <(bws secret list --output env); set +a

fail=0
for chk in "$HERE"/services/*/check.sh; do
  [ -f "$chk" ] || continue
  case "$chk" in */_*/check.sh) continue ;; esac   # ignora _TEMPLATE e afins
  out="$(bash "$chk" 2>&1)"; echo "$out"
  echo "$out" | grep -q ' 200' || fail=1
done
[ "$fail" = 0 ] && echo "✅ todos OK" || echo "❌ algum serviço falhou"
exit $fail
