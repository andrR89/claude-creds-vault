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

# ── env.required: serviço sem credencial é DESABILITADO (pulado), não falha ──
# Sintaxe: 1 entrada por linha ('#' comenta); nome literal exige var não-vazia;
# padrão com '*' (glob) exige pelo menos uma var casando. Sem arquivo → ativo.
# (espelha first_missing() do bootstrap.sh — manter em sincronia)
missing_req() {  # $1 = env.required → ecoa a 1ª entrada não satisfeita (nada se ok)
  local entry name found
  while IFS= read -r entry || [ -n "$entry" ]; do
    entry="${entry%%#*}"; entry="${entry//[[:space:]]/}"
    [ -n "$entry" ] || continue
    found=0
    if [[ "$entry" == *\** ]]; then
      while IFS= read -r name; do
        [[ "$name" == $entry && -n "${!name:-}" ]] && { found=1; break; }
      done < <(compgen -A variable)
    else
      [ -n "${!entry:-}" ] && found=1
    fi
    [ "$found" = 1 ] || { echo "$entry"; return; }
  done < "$1"
}

fail=0
for chk in "$HERE"/services/*/check.sh; do
  [ -f "$chk" ] || continue
  case "$chk" in */_*/check.sh) continue ;; esac   # ignora _TEMPLATE e afins
  dir="$(dirname "$chk")"; svc="$(basename "$dir")"
  if [ -r "$dir/env.required" ]; then               # ilegível/ausente → ativo
    miss="$(missing_req "$dir/env.required")"
    [ -n "$miss" ] && { echo "$svc: — desabilitado (falta $miss)"; continue; }
  fi
  out="$(bash "$chk" 2>&1)"; echo "$out"
  # falha se QUALQUER linha com código HTTP não for 200 (cobre serviços multi-linha, ex. gemini)
  while IFS= read -r line; do
    code="$(printf '%s' "$line" | grep -oE '[0-9]{3}' | tail -1)"
    [ -n "$code" ] || continue
    [ "$code" = "200" ] || fail=1
  done <<< "$out"
done
[ "$fail" = 0 ] && echo "✅ todos OK" || echo "❌ algum serviço falhou"
exit $fail
