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

MANAGED="$HOME/.config/claude-creds/managed-keys"
python3 - "$SETTINGS" "$TMP" "$MANAGED" <<'PY'
import json, re, sys, os
sp, ep, mp = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(sp)); env = data.setdefault("env", {})

# chaves que vêm do vault AGORA
incoming = {}
for line in open(ep):
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line: continue
    k, v = re.sub(r'^export\s+', '', line).split("=", 1)
    incoming[k.strip()] = v.strip().strip('"').strip("'")

# chaves que o vault gravou da última vez (marker) — só removemos o que ELE gerenciava
prev = {l.strip() for l in open(mp)} if os.path.exists(mp) else set()
removed = [k for k in prev if k not in incoming and k in env]
for k in removed: env.pop(k, None)

# injeta/atualiza as atuais
for k, v in incoming.items(): env[k] = v

# sem assinaturas do Claude em commits/PRs (só preenche o que faltar — não
# sobrescreve customização manual)
att = data.setdefault("attribution", {})
att.setdefault("commit", "")
att.setdefault("pr", "")
att.setdefault("sessionUrl", False)

json.dump(data, open(sp, "w"), indent=2); open(sp, "a").write("\n")
os.makedirs(os.path.dirname(mp), exist_ok=True)
open(mp, "w").write("\n".join(sorted(incoming)) + "\n")   # atualiza o marker

msg = f"✅ {len(incoming)} variáveis gravadas em {sp}"
if removed: msg += f"; {len(removed)} órfã(s) removida(s): {', '.join(removed)}"
print(msg)
PY

# espelho runtime — leitura AO VIVO (sempre o valor atual, pega rotação na hora)
RUNTIME_DIR="$HOME/.config/claude-creds"; mkdir -p "$RUNTIME_DIR"
install -m 600 "$TMP" "$RUNTIME_DIR/secrets.env"
echo "✅ Espelho runtime: $RUNTIME_DIR/secrets.env (chmod 600)"

# ── ponte p/ os agentes: anuncia os serviços no arquivo de contexto global ──
# Bloco gerenciado (entre marcadores) montado a partir dos services/*/README.md.
# Assim o agente, em QUALQUER sessão/projeto, sabe que tem acesso — sem precisar
# checar o ambiente. Adicionou serviço → a ponte se atualiza no próximo bootstrap.
# Claude Code: ~/.claude/CLAUDE.md · Gemini CLI/Antigravity: ~/.gemini/GEMINI.md (se instalados).
write_bridge() {  # $1 = arquivo de contexto global, $2 = flavor (claude|gemini)
python3 - "$HERE" "$1" "$2" <<'PY'
import os, re, sys, glob, fnmatch
here, md, flavor = sys.argv[1], sys.argv[2], sys.argv[3]
BEGIN = "<!-- BEGIN claude-creds-vault (auto-gerado por bootstrap.sh — não edite à mão) -->"
END   = "<!-- END claude-creds-vault -->"

rows = []
for rd in sorted(glob.glob(os.path.join(here, "services", "*", "README.md"))):
    svc = os.path.basename(os.path.dirname(rd))
    if svc.startswith("_"):
        continue
    auth = envs = ""
    for line in open(rd, encoding="utf-8"):
        s = line.strip()
        m = re.match(r'-\s*\*\*Auth:\*\*\s*(.+)', s)
        if m: auth = m.group(1).strip()
        m = re.match(r'-\s*\*\*Env vars:\*\*\s*(.+)', s)
        if m: envs = m.group(1).strip()
    rows.append((svc, auth, envs))

# ── env.required: omite da ponte serviço cujas vars não estão no espelho ──
# Chaves disponíveis = linhas KEY=... com valor não-vazio no espelho runtime.
env_file = os.path.join(os.path.expanduser("~"), ".config", "claude-creds", "secrets.env")
keys = set()
try:
    for line in open(env_file, encoding="utf-8"):
        m = re.match(r'([A-Za-z_][A-Za-z0-9_]*)=(.*)', line.strip())
        if m and m.group(2).strip().strip('"').strip("'"):
            keys.add(m.group(1))
except OSError:
    keys = None  # espelho ilegível → não desabilita ninguém

def first_missing(svc):  # → entrada não satisfeita ou None (erro de leitura = ativo)
    req = os.path.join(here, "services", svc, "env.required")
    if keys is None or not os.path.isfile(req):
        return None
    try:
        for raw in open(req, encoding="utf-8"):
            entry = raw.split("#", 1)[0].strip()
            if entry and not fnmatch.filter(keys, entry):
                return entry
    except OSError:
        return None
    return None

off = [(svc, first_missing(svc)) for svc, _, _ in rows]
off = [(svc, miss) for svc, miss in off if miss]
rows = [r for r in rows if r[0] not in {svc for svc, _ in off}]

inject = {
    "claude": "já injetadas no seu ambiente (bloco `env` do settings.json do Claude).",
    "gemini": "já injetadas no seu ambiente (carregadas do `~/.gemini/.env`, symlink do espelho runtime).",
}.get(flavor, "obtidas na hora via `source` do espelho runtime (regra de ouro abaixo).")
L = [BEGIN,
     "# Credenciais disponíveis (claude-creds-vault)",
     "",
     "Você TEM acesso aos serviços abaixo via env vars " + inject,
     "Quando o usuário pedir algo de um desses",
     "serviços, **use** — não diga que não tem acesso.",
     "",
     "| Serviço | Auth | Env vars |",
     "|---|---|---|"]
for svc, auth, envs in rows:
    L.append(f"| **{svc}** | {auth or '—'} | {envs or '—'} |")
L += ["",
      "**Regra de ouro — sempre o valor atual:** antes do curl, carregue o espelho",
      "runtime (pega rotações sem reiniciar a sessão):",
      "",
      "```bash",
      "set -a; source ~/.config/claude-creds/secrets.env; set +a",
      "```",
      "",
      f"- **Receitas completas** (leitura/escrita por serviço): `{here}/services/<id>/README.md`.",
      "- **Operações de escrita alteram dados reais** — confirme com o usuário antes.",
      "- **Nunca** imprima segredos no chat; ao testar, mostre só o status HTTP.",
      f"- Gerenciar o cofre (adicionar serviço, rotação): `{here}/CLAUDE.md`.",
      END]
if flavor != "claude":  # no Claude isso é resolvido via settings.json (attribution)
    L.insert(-1, "- **Nunca** inclua assinaturas de IA em commits/PRs (nada de "
                 "\"Generated with…\", `Co-Authored-By` de IA ou similares).")
block = "\n".join(L)

old = open(md, encoding="utf-8").read() if os.path.exists(md) else ""
pat = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.DOTALL)
new = pat.sub(lambda _: block, old) if pat.search(old) else \
      ((old.rstrip() + "\n\n" + block + "\n") if old.strip() else block + "\n")
os.makedirs(os.path.dirname(md), exist_ok=True)
open(md, "w", encoding="utf-8").write(new)
extra = f", {len(off)} desabilitado(s): {', '.join(svc for svc, _ in off)}" if off else ""
print(f"✅ Ponte p/ o agente ({flavor}): {md} ({len(rows)} serviços anunciados{extra})")
PY
}

write_bridge "$HOME/.claude/CLAUDE.md" claude

# ── Gemini CLI / Antigravity CLI (opcional): mesmo vault, mesma ponte ──
# Ambos usam ~/.gemini/ como config — uma ponte serve os dois (validado: o agy
# lê o GEMINI.md como regra global e faz os curls sozinho). Só age se algum
# existir na máquina (gemini/agy no PATH ou ~/.gemini/ presente).
# Env vars: o Gemini carrega ~/.gemini/.env sozinho → symlink p/ o espelho runtime
# (mesma fonte, rotação pega junto). Contexto: mesmo bloco gerenciado no GEMINI.md.
if command -v gemini >/dev/null 2>&1 || command -v agy >/dev/null 2>&1 || [ -d "$HOME/.gemini" ]; then
  mkdir -p "$HOME/.gemini"
  GENV="$HOME/.gemini/.env"
  if [ -L "$GENV" ] || [ ! -e "$GENV" ]; then
    ln -sfn "$RUNTIME_DIR/secrets.env" "$GENV"
    echo "✅ Gemini/Antigravity: $GENV → symlink p/ o espelho runtime"
  else
    echo "⚠️  Gemini/Antigravity: $GENV já existe (arquivo próprio) — não sobrescrevi; se quiser as credenciais lá, aponte-o p/ $RUNTIME_DIR/secrets.env"
  fi
  write_bridge "$HOME/.gemini/GEMINI.md" gemini
fi

# ── OpenCode (opcional): lê o AGENTS.md global de ~/.config/opencode/ ──
# Env herda do shell; a ponte instrui o source do espelho antes de cada curl.
if command -v opencode >/dev/null 2>&1 || [ -d "$HOME/.config/opencode" ]; then
  write_bridge "$HOME/.config/opencode/AGENTS.md" opencode
fi

# ── Kilo Code (opcional): extensão VS Code; regras globais em ~/.kilocode/rules/ ──
if [ -d "$HOME/.kilocode" ] || ls "$HOME/.vscode/extensions"/kilocode.* >/dev/null 2>&1; then
  write_bridge "$HOME/.kilocode/rules/creds-vault.md" kilocode
fi

echo "✅ Pronto. Sessões NOVAS pegam via settings.json/.env; sessões ABERTAS pegam dando source no espelho runtime."
