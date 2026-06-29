# Claude Creds Vault — cofre de credenciais plugável para Claude Code

> **Como usar este arquivo:** coloque-o numa máquina que **já tem acesso
> funcionando** aos serviços que você quer empacotar (hoje: Jira `jira.nexxera.com`
> e GitLab `gitlab.nexxera.com`), abra o Claude Code nessa pasta e diga:
> *"executa o SETUP-CLAUDE-CREDS-VAULT.md"*. O Claude descobre as credenciais que
> já existem, monta um repo **portável e encriptado**, e você leva esse repo para
> qualquer máquina nova — `git clone` + `./bootstrap.sh` configura tudo.

---

## 🎯 Objetivo e princípio

Um repo git **privado** que torna o acesso a **N serviços** (Jira, GitLab,
ClickUp, …) portável entre máquinas. Acesso via **`curl` + variáveis de ambiente**,
persistidas no **`~/.claude/settings.json` (bloco `env`)** — escopo Claude, valem
em **todas as sessões e agentes**, sem vazar para outros terminais e sem editar
profile de shell.

**Princípio de escalabilidade — convenção sobre configuração:**

> Adicionar um serviço novo = **soltar uma pasta `services/<id>/` + adicionar as
> chaves no env encriptado**. O núcleo (`bootstrap.sh`, `healthcheck.sh`) **nunca
> muda** — ele descobre os serviços automaticamente pela presença das pastas.

---

## 🧱 Arquitetura do repo

```
claude-creds-vault/
├── README.md                 # explicação geral
├── secrets.env.age           # FONTE DA VERDADE: todas as credenciais, encriptadas (age) — flat KEY=VALUE
├── bootstrap.sh              # GENÉRICO: decripta → settings.json + espelho runtime (~/.config/claude-creds/secrets.env)
├── refresh.sh                # GENÉRICO: git pull + re-decripta → atualiza o espelho runtime APÓS rotação (sem reiniciar)
├── healthcheck.sh            # GENÉRICO: roda services/*/check.sh e reporta status de cada um
├── .gitignore                # impede commit de segredo em texto puro
└── services/                 # 1 pasta por serviço — é só soltar mais

# Fora do repo (machine-local, gerado pelo bootstrap/refresh):
#   ~/.config/claude-creds/secrets.env   ← ESPELHO RUNTIME (chmod 600), o que o Claude dá `source` ao vivo
    ├── _TEMPLATE/            # modelo para criar serviços novos
    │   ├── check.sh
    │   └── README.md
    ├── jira/
    │   ├── check.sh          # healthcheck do serviço (usa as env vars)
    │   └── README.md         # auth + receitas de curl (referência p/ o Claude)
    └── gitlab/
        ├── check.sh
        └── README.md
```

**O que é "núcleo" (escreve uma vez, nunca mexe):** `bootstrap.sh`, `healthcheck.sh`.
**O que é "plugável" (cresce):** `secrets.env.age` (mais chaves) e `services/<id>/` (mais pastas).

---

## 🤖 PARA A IA QUE VAI EXECUTAR ESTE ARQUIVO

Você está numa máquina que **já acessa** os serviços. Siga na ordem.
**Regra de ouro: nunca imprima segredos em texto puro no chat** — escreva direto
em arquivo; ao testar, mascare (só status HTTP).

### Passo 0 — Descobrir as credenciais que já existem (sem imprimir valores)

O usuário disse que esta máquina **já lê um arquivo de env** com as credenciais,
persistido entre sessões. Ache-o e extraia **nomes + valores**:

```bash
grep -rIl -iE 'jira|gitlab|clickup' \
  ~/.claude/settings.json ~/.claude/settings.local.json \
  ~/.zshrc ~/.zshenv ~/.zprofile ~/.bashrc ~/.profile ~/.config 2>/dev/null
printenv | grep -iE 'jira|gitlab|clickup' | sed 's/=.*/=<oculto>/'   # só as chaves
```

Reaproveite os **nomes de variável já em uso**. Padrão canônico se não houver:

| Serviço | Variáveis |
|---|---|
| Jira (legado, basic auth) | `JIRA_BASE_URL`, `JIRA_USER`, `JIRA_PASS` |
| GitLab (token) | `GITLAB_BASE_URL`, `GITLAB_TOKEN` |

### Passo 1 — Criar a estrutura

```bash
PROJ="$HOME/Workspaces/claude-creds-vault"   # ajuste se quiser
mkdir -p "$PROJ/services/_TEMPLATE" && cd "$PROJ"
git init -q
command -v age >/dev/null || echo "⚠️ instale o age: brew install age"
```

### Passo 2 — `secrets.env.age` (flat, todas as creds, encriptado)

Crie `secrets.env` com os **valores reais** (escreva direto, não ecoe):

```bash
cat > secrets.env <<'EOF'
# === jira (legado, basic auth) ===
JIRA_BASE_URL=https://jira.nexxera.com
JIRA_USER=__PREENCHER__
JIRA_PASS=__PREENCHER__
# === gitlab (token) ===
GITLAB_BASE_URL=https://gitlab.nexxera.com
GITLAB_TOKEN=__PREENCHER__
EOF
# edite substituindo os __PREENCHER__
age -p -o secrets.env.age secrets.env   # define uma passphrase — guarde no gerenciador de senha
rm -f secrets.env
```

### Passo 3 — `bootstrap.sh` (núcleo, genérico)

```bash
cat > bootstrap.sh <<'EOF'
#!/usr/bin/env bash
# Injeta TODAS as credenciais do vault no bloco env do ~/.claude/settings.json.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENC="$HERE/secrets.env.age"; SETTINGS="$HOME/.claude/settings.json"
command -v age     >/dev/null || { echo "❌ instale: brew install age"; exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 necessário"; exit 1; }
[ -f "$ENC" ]                 || { echo "❌ não achei $ENC"; exit 1; }

echo "🔐 Decriptando (digite a passphrase do age)…"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
age -d "$ENC" > "$TMP"
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
EOF
chmod +x bootstrap.sh
```

### Passo 4 — `healthcheck.sh` (núcleo, genérico — descobre serviços sozinho)

```bash
cat > healthcheck.sh <<'EOF'
#!/usr/bin/env bash
# Testa cada serviço rodando services/*/check.sh. Não muda quando você adiciona serviço.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🔐 Carregando segredos (passphrase do age)…"
set -a; source <(age -d "$HERE/secrets.env.age"); set +a
fail=0
for chk in "$HERE"/services/*/check.sh; do
  [ -f "$chk" ] || continue
  out="$(bash "$chk" 2>&1)"; echo "$out"
  echo "$out" | grep -q ' 200' || fail=1
done
[ "$fail" = 0 ] && echo "✅ todos OK" || echo "❌ algum serviço falhou"
exit $fail
EOF
chmod +x healthcheck.sh
```

**`refresh.sh`** (núcleo — rotina de atualização após rotação de credencial):

```bash
cat > refresh.sh <<'EOF'
#!/usr/bin/env bash
# Rotina de manutenção: pega rotações (de outra máquina via git) e re-injeta tudo.
# Rode isto SEMPRE que uma credencial mudar. Não muda quando você adiciona serviço.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "⤓ git pull (pega rotações feitas em outra máquina)…"
git -C "$HERE" pull --ff-only 2>/dev/null || echo "  (sem remote/ahead — seguindo só com o local)"
exec "$HERE/bootstrap.sh"   # re-decripta → settings.json + espelho runtime atualizados
EOF
chmod +x refresh.sh
```

### Passo 5 — Módulo `_TEMPLATE` + serviços de hoje (jira, gitlab)

**Template** (o que se copia para criar serviço novo):

```bash
cat > services/_TEMPLATE/check.sh <<'EOF'
#!/usr/bin/env bash
# Troque <SVC> e a URL/headers. Deve imprimir "<nome>: <http_code>".
code=$(curl -s -o /dev/null -w '%{http_code}' "$SVC_BASE_URL/endpoint/de/saude")
echo "<nome>: $code"
EOF

cat > services/_TEMPLATE/README.md <<'EOF'
# <serviço>
- **Auth:** <basic | header token | bearer>
- **Env vars:** `SVC_BASE_URL`, `SVC_TOKEN`
## Receitas de curl (para o Claude usar)
```bash
curl -s -H "Authorization: Bearer $SVC_TOKEN" "$SVC_BASE_URL/api/..."
```
EOF
```

**jira:**

```bash
mkdir -p services/jira
cat > services/jira/check.sh <<'EOF'
#!/usr/bin/env bash
code=$(curl -s -o /dev/null -w '%{http_code}' -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/myself")
echo "jira: $code"
EOF
cat > services/jira/README.md <<'EOF'
# jira (legado — basic auth)
- **Auth:** básica (`-u "$JIRA_USER:$JIRA_PASS"`)
- **Env vars:** `JIRA_BASE_URL`, `JIRA_USER`, `JIRA_PASS`
## Receitas
```bash
curl -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/issue/CTR-703"
curl -s -G -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/search" \
  --data-urlencode 'jql=project=CTR ORDER BY updated DESC'
```
EOF
```

**gitlab:**

```bash
mkdir -p services/gitlab
cat > services/gitlab/check.sh <<'EOF'
#!/usr/bin/env bash
code=$(curl -s -o /dev/null -w '%{http_code}' -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_BASE_URL/api/v4/user")
echo "gitlab: $code"
EOF
cat > services/gitlab/README.md <<'EOF'
# gitlab (token)
- **Auth:** header `PRIVATE-TOKEN: $GITLAB_TOKEN`
- **Env vars:** `GITLAB_BASE_URL`, `GITLAB_TOKEN`
## Receitas
```bash
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_BASE_URL/api/v4/projects?membership=true"
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_BASE_URL/api/v4/projects/traducao%2Fpython%2Fconector2/issues?state=opened"
EOF
chmod +x services/*/check.sh services/_TEMPLATE/check.sh
```

### Passo 6 — `.gitignore`, `README.md`, commit

```bash
cat > .gitignore <<'EOF'
secrets.env
*.env
!*.env.age
EOF
```

`README.md` (raiz):

````markdown
# claude-creds-vault
Cofre de credenciais plugável para o Claude Code. Cada serviço vive em
`services/<id>/`. Credenciais em `secrets.env.age` (age). Persistidas no bloco
`env` do `~/.claude/settings.json`.

## Máquina nova
```bash
git clone <url-privada> claude-creds-vault && cd claude-creds-vault
./bootstrap.sh          # pede a passphrase do age → grava no settings.json
./healthcheck.sh        # confirma cada serviço (espera 200)
# reinicie o Claude Code
```

## Adicionar um serviço — ver seção no SETUP-CLAUDE-CREDS-VAULT.md
````

Commit:

```bash
git add -A && git commit -qm "vault de credenciais plugável para Claude Code"
# repo PRIVADO: git remote add origin <url>; git push -u origin main
```

---

## ➕ COMO ADICIONAR UM SERVIÇO NOVO (ex.: ClickUp)

Esta é a parte que prova a escalabilidade. **Três passos pequenos, núcleo intacto:**

**1. Adicionar as chaves no env encriptado:**
```bash
age -d secrets.env.age > secrets.env
cat >> secrets.env <<'EOF'
# === clickup (token pessoal) ===
CLICKUP_BASE_URL=https://api.clickup.com/api/v2
CLICKUP_TOKEN=__PREENCHER__
EOF
age -p -o secrets.env.age secrets.env && rm -f secrets.env
```

**2. Criar a pasta do serviço** (copia do `_TEMPLATE` e ajusta):
```bash
mkdir -p services/clickup
cat > services/clickup/check.sh <<'EOF'
#!/usr/bin/env bash
# ClickUp: header Authorization simples (sem "Bearer")
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: $CLICKUP_TOKEN" "$CLICKUP_BASE_URL/user")
echo "clickup: $code"
EOF
chmod +x services/clickup/check.sh
cat > services/clickup/README.md <<'EOF'
# clickup
- **Auth:** header `Authorization: $CLICKUP_TOKEN` (token pessoal, sem "Bearer")
- **Env vars:** `CLICKUP_BASE_URL`, `CLICKUP_TOKEN`
## Receitas
```bash
curl -s -H "Authorization: $CLICKUP_TOKEN" "$CLICKUP_BASE_URL/team"            # workspaces
curl -s -H "Authorization: $CLICKUP_TOKEN" "$CLICKUP_BASE_URL/task/<task_id>"  # uma task
```
EOF
```

**3. Reaplicar e validar:**
```bash
./bootstrap.sh      # re-injeta o env (agora com CLICKUP_*) no settings.json
./healthcheck.sh    # agora lista jira/gitlab/clickup, cada um com seu status
git add -A && git commit -qm "add serviço clickup"
```

Pronto. `bootstrap.sh` e `healthcheck.sh` **não foram tocados** — eles descobrem
`services/clickup/` sozinhos. Esse é o padrão para qualquer serviço futuro:
**chaves no env + uma pasta em `services/`.**

---

## 🔄 Manutenção e rotação de credenciais

**Modelo mental (3 camadas):**

| Camada | Onde | Papel |
|---|---|---|
| Fonte da verdade (em repouso) | `secrets.env.age` (no repo, encriptado) | o que viaja entre máquinas |
| Espelho runtime (ao vivo) | `~/.config/claude-creds/secrets.env` (600, fora do repo) | o que o Claude lê **fresco** a cada curl |
| Conveniência (sessão nova) | `~/.claude/settings.json` `env` | vars já presentes sem `source`, mas **congeladas por sessão** |

> ⚠️ O `settings.json` `env` **não muda no meio de uma sessão**. Por isso, para
> sempre usar a credencial **correta** (mesmo após rotação numa sessão já aberta),
> a regra é: **dar `source` no espelho runtime na hora de usar.**

### Como o Claude deve chamar um serviço (sempre o valor atual)

Prefixe o curl carregando o espelho runtime — ele é reescrito a cada `refresh`,
então isto sempre pega o valor mais novo, **sem reiniciar a sessão**:

```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a
curl -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/issue/CTR-703"
```

### Rotina quando uma credencial muda

**Mesma máquina:**
```bash
age -d secrets.env.age > secrets.env     # 1. edita o valor que mudou
#   ...troca o valor...
age -p -o secrets.env.age secrets.env && rm -f secrets.env   # 2. re-encripta
./refresh.sh                              # 3. atualiza settings.json + espelho runtime
git commit -am "rotate <serviço>" && git push   # 4. propaga p/ outras máquinas
```
Pronto — o **próximo curl** (que dá `source` no espelho) já usa o novo valor.
Sessões novas também. Nada de reiniciar no caso do espelho runtime.

**Outra máquina (pega a rotação que você fez e pushou):**
```bash
./refresh.sh        # faz git pull + re-decripta → espelho runtime atualizado
```

### (Opcional) auto-recuperação em 401/403

Para o Claude se curar sozinho quando bater numa credencial vencida, crie um
wrapper que, ao receber 401/403, roda `./refresh.sh` e tenta de novo **uma vez**:

```bash
cat > svc-curl.sh <<'EOF'
#!/usr/bin/env bash
# Uso: ./svc-curl.sh -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/..."
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
EOF
chmod +x svc-curl.sh
```
> ⚠️ O `refresh.sh` pode pedir a passphrase do age. Para auto-recuperação **sem
> prompt** (rotina/cron), troque a encriptação por **chave de identidade age**
> (`age-keygen` → guarda a chave privada em `~/.config/claude-creds/age.key`,
> chmod 600, fora do repo; encripta com `-r <chave-pública>`; decripta com
> `-i ~/.config/claude-creds/age.key`, que não pede senha).

### Resumo da divisão de responsabilidades

- **Adicionar serviço** → `secrets.env.age` + `services/<id>/` (núcleo intacto).
- **Rotacionar credencial** → editar valor + `./refresh.sh` (núcleo intacto).
- **Leitura sempre correta** → `source` do espelho runtime antes do curl.

---

## ✅ Checklist final (a IA confirma)

- [ ] `secrets.env.age` existe; `secrets.env` em texto puro **apagado** e no `.gitignore`.
- [ ] `bootstrap.sh` grava no `env` do settings.json **sem apagar** o resto **e** cria o espelho runtime `~/.config/claude-creds/secrets.env` (chmod 600).
- [ ] `refresh.sh` existe e é executável (git pull + re-injeção).
- [ ] `healthcheck.sh` lista cada serviço de `services/*/` com status **200**.
- [ ] Teste de rotação: troquei um valor → `./refresh.sh` → `source` do espelho → curl usou o **valor novo** sem reiniciar.
- [ ] Repo commitado em origem **privada**; passphrase do age guardada.

## 🧪 Teste na máquina destino (faremos juntos)
1. `git clone` → `./bootstrap.sh` (passphrase) → reinicia o Claude Code.
2. `./healthcheck.sh` → todos **200**.
3. Peça ao Claude: *"puxa a issue CTR-703 do Jira e meus projetos no GitLab"* —
   ele usa as env vars via curl e traz dados reais.

> As vars do `settings.json` `env` só valem em **sessões novas** do Claude — por
> isso o "reinicie" depois de cada `bootstrap.sh`.
