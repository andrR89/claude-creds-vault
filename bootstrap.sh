#!/usr/bin/env bash
# Injeta TODAS as credenciais do vault (Bitwarden Secrets Manager) no bloco env do
# ~/.claude/settings.json e cria um espelho runtime fresco (chmod 600).
# Fonte da verdade: Bitwarden Secrets Manager — lido via `bws secret list --output env`.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
TOKEN_FILE="$HOME/.config/claude-creds/bws-token"

command -v bws     >/dev/null || { echo "❌ instale o bws (Bitwarden Secrets Manager CLI)"; exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 necessário"; exit 1; }
[ -f "$TOKEN_FILE" ] || { echo "❌ não achei $TOKEN_FILE (guarde ali o BWS_ACCESS_TOKEN, chmod 600)"; exit 1; }

export BWS_ACCESS_TOKEN="$(cat "$TOKEN_FILE")"

echo "🔐 Buscando segredos no Bitwarden Secrets Manager…"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
bws secret list --output env > "$TMP"   # emite KEY=VALUE de todos os segredos da machine account
[ -s "$TMP" ] || { echo "❌ bws não retornou segredos (token sem acesso ao projeto?)"; exit 1; }

mkdir -p "$HOME/.claude"; [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

python3 - "$SETTINGS" "$TMP" <<'PY'
import json, re, sys
sp, ep = sys.argv[1], sys.argv[2]
data = json.load(open(sp)); env = data.setdefault("env", {}); n = 0
for line in open(ep):
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line: continue
    k, v = re.sub(r'^export\s+', '', line).split("=", 1)
    env[k.strip()] = v.strip().strip('"').strip("'"); n += 1
json.dump(data, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print(f"✅ {n} variáveis gravadas em {sp}")
PY

# espelho runtime — leitura AO VIVO (sempre o valor atual, pega rotação na hora)
RUNTIME_DIR="$HOME/.config/claude-creds"; mkdir -p "$RUNTIME_DIR"
install -m 600 "$TMP" "$RUNTIME_DIR/secrets.env"
echo "✅ Espelho runtime: $RUNTIME_DIR/secrets.env (chmod 600)"
echo "✅ Pronto. Sessões NOVAS pegam via settings.json; sessões ABERTAS pegam dando source no espelho runtime."
