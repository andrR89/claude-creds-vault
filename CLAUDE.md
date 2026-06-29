# Claude Creds Vault — cofre de credenciais plugável para Claude Code

> **O que é este repo:** um cofre **portável** que torna o acesso a **N serviços**
> (Jira, GitLab, ClickUp, Gemini, fal.ai, …) disponível para o Claude Code em
> qualquer máquina. A **fonte da verdade é o Bitwarden Secrets Manager** — nenhum
> segredo entra no git. Numa máquina nova: instala o `bws`, grava o token, roda
> `./bootstrap.sh`. Pronto.
>
> **Para o Claude trabalhando NESTE repo:** este arquivo é a referência de como o
> projeto funciona, como usá-lo, como adicionar integrações e como rotacionar
> credenciais. **Nunca imprima segredos em texto puro no chat** — ao testar, mostre
> só status HTTP.

---

## 🎯 Objetivo e princípio

Acesso a serviços via **`curl` + variáveis de ambiente**, persistidas no bloco
`env` do **`~/.claude/settings.json`** (escopo Claude — valem em todas as sessões e
agentes, sem vazar para outros terminais nem editar profile de shell) e espelhadas
num arquivo runtime para leitura ao vivo.

**Princípio de escalabilidade — convenção sobre configuração:**

> Adicionar um serviço = **criar os secrets no Bitwarden + soltar uma pasta
> `services/<id>/`**. O núcleo (`bootstrap.sh`, `refresh.sh`, `healthcheck.sh`)
> **nunca muda** — ele descobre os serviços sozinho pela presença das pastas e
> injeta todas as chaves que o token enxerga no Bitwarden.

---

## 🧱 Arquitetura

```
claude-creds-vault/
├── README.md          # guia rápido (máquina nova, rotação, adicionar serviço)
├── CLAUDE.md          # este arquivo — referência de funcionamento p/ o Claude
├── bootstrap.sh       # NÚCLEO: bws → settings.json (env) + espelho runtime
├── refresh.sh         # NÚCLEO: git pull (código) + re-busca do bws
├── healthcheck.sh     # NÚCLEO: roda services/*/check.sh e exige status 200
├── svc-curl.sh        # wrapper opcional: em 401/403 dá refresh e tenta 1x
├── .gitignore         # bloqueia qualquer segredo em texto puro / token
└── services/          # 1 pasta por serviço — é só soltar mais
    ├── _TEMPLATE/     # modelo p/ criar serviço novo (ignorado pelo healthcheck)
    ├── jira/          # check.sh + README.md (auth + receitas de curl)
    ├── gitlab/
    ├── clickup/
    ├── gemini/
    └── fal/

# Fora do repo (machine-local — NÃO versionado):
#   ~/.config/claude-creds/bws-token     ← access token da machine account (chmod 600)
#   ~/.config/claude-creds/secrets.env   ← ESPELHO RUNTIME (chmod 600), source ao vivo
#   ~/.config/claude-creds/managed-keys  ← marker: chaves que o bootstrap gerencia
#   ~/.claude/CLAUDE.md                  ← PONTE: bloco gerenciado que anuncia os serviços ao Claude
```

**Núcleo (escreve uma vez, nunca mexe):** `bootstrap.sh`, `refresh.sh`, `healthcheck.sh`.
**Plugável (cresce):** secrets no Bitwarden + pastas em `services/<id>/`.

---

## 🔐 As três camadas (modelo mental)

| Camada | Onde | Papel |
|---|---|---|
| **Fonte da verdade** | Bitwarden Secrets Manager | o que viaja entre máquinas; rotação central |
| **Espelho runtime** (ao vivo) | `~/.config/claude-creds/secrets.env` (600) | o que o Claude lê **fresco** a cada curl |
| **Conveniência** (sessão nova) | `~/.claude/settings.json` → `env` | vars já presentes sem `source`, mas **congeladas por sessão** |

> ⚠️ O `settings.json` `env` **não muda no meio de uma sessão** já aberta. Por isso,
> para sempre usar o valor **atual** (mesmo após rotação), a regra de ouro é:
> **dar `source` no espelho runtime na hora de usar.**

---

## 🚀 Como rodar numa máquina nova

Pré-requisitos no Bitwarden (uma vez): **Secrets Manager** ativo, um **projeto**
(ex. `claude-creds`) com **1 secret por variável** (key = nome da env var), e uma
**machine account** com acesso **read** ao projeto + um **access token**.

```bash
git clone <url-privada> claude-creds-vault && cd claude-creds-vault

# 1. instalar o bws (NÃO há fórmula no Homebrew — é binário do bitwarden/sdk-sm)
#    macOS arm64, ex. v2.1.0:
URL="https://github.com/bitwarden/sdk-sm/releases/download/bws-v2.1.0/bws-aarch64-apple-darwin-2.1.0.zip"
curl -sL -o /tmp/bws.zip "$URL" && unzip -o /tmp/bws.zip -d ~/.local/bin
chmod +x ~/.local/bin/bws && xattr -d com.apple.quarantine ~/.local/bin/bws 2>/dev/null
#    (garanta que ~/.local/bin está no PATH)

# 2. gravar o access token (sem ecoar — escreve direto no arquivo, chmod 600)
mkdir -p ~/.config/claude-creds
printf '%s' 'SEU_BWS_ACCESS_TOKEN' > ~/.config/claude-creds/bws-token
chmod 600 ~/.config/claude-creds/bws-token

# 3. injetar tudo e validar
./bootstrap.sh          # busca do Bitwarden → settings.json (env) + espelho runtime
./healthcheck.sh        # confirma cada serviço (espera 200 em todas as linhas)

# 4. REINICIE o Claude Code — o bloco env do settings.json só vale em sessões NOVAS
```

**Diagnóstico se o `bootstrap` gravar `0 variáveis`:** o token autentica mas não
vê segredos. Cheque `bws project list` e `bws secret list` — provável falta de
acesso **read** da machine account ao projeto, ou token de outra org.

### Ponte automática p/ o Claude (gerada pelo bootstrap)

O `bootstrap.sh` **também** mantém um bloco gerenciado no `~/.claude/CLAUDE.md`
global (entre marcadores `<!-- BEGIN/END claude-creds-vault -->`), montado a partir
dos `services/*/README.md` (linhas `**Auth:**` e `**Env vars:**`). Assim, em
**qualquer** sessão/projeto, o Claude sabe que tem acesso aos serviços — sem
precisar inspecionar o ambiente. É **idempotente** (substitui o bloco, não duplica)
e **preserva** o resto do seu CLAUDE.md global. Adicionou um serviço novo? O
próximo `bootstrap`/`refresh` atualiza a ponte sozinho.

---

## 🤖 Como o Claude deve chamar um serviço (sempre o valor atual)

Prefixe o curl carregando o espelho runtime — ele é reescrito a cada bootstrap/
refresh, então pega o valor mais novo **sem reiniciar a sessão**:

```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a
curl -s -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" "$JIRA_BASE_URL/rest/api/2/myself"
```

As **receitas de curl de cada serviço** (auth, leitura, escrita) vivem em
`services/<id>/README.md` — consulte-as antes de chamar um serviço. Operações de
**escrita alteram dados reais**: confirme com o usuário antes.

---

## ➕ Como adicionar uma integração nova (ex.: ClickUp)

Prova da escalabilidade — **núcleo intacto**, dois lugares mudam:

**1. Criar o(s) secret(s) no Bitwarden** (projeto `claude-creds`), 1 por env var:
ex. `CLICKUP_API_KEY`. (A machine account já tem read → o `bootstrap` passa a
enxergá-lo automaticamente. Base URLs fixas/públicas podem ficar direto no
`check.sh`, sem virar secret.)

**2. Criar a pasta do serviço** (copia de `_TEMPLATE` e ajusta):

```bash
mkdir -p services/clickup
cat > services/clickup/check.sh <<'EOF'
#!/usr/bin/env bash
# Deve imprimir "<nome>: <http_code>". O healthcheck exige 200 em CADA linha.
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/user")
echo "clickup: $code"
EOF
chmod +x services/clickup/check.sh
# crie services/clickup/README.md com Auth + Env vars + Docs + receitas (use _TEMPLATE)
```

**3. Reaplicar e validar:**

```bash
./bootstrap.sh      # re-injeta o env (agora com CLICKUP_*) no settings.json
./healthcheck.sh    # agora lista clickup com seu status
git add -A && git commit -qm "add serviço clickup" && git push
```

> `bootstrap.sh`/`healthcheck.sh` **não foram tocados** — descobrem `services/clickup/`
> sozinhos. Padrão p/ qualquer serviço futuro: **secret(s) no Bitwarden + uma pasta
> em `services/`.** Pastas começadas com `_` (ex. `_TEMPLATE`) são ignoradas pelo
> healthcheck.

### Padrão multi-chave (ex.: gemini)

Um `check.sh` pode testar **todas** as env vars que casam um sufixo — útil quando
o mesmo serviço tem várias chaves (pessoal, corporativa…). O `services/gemini/check.sh`
itera sobre `compgen -A variable | grep -E 'GEMINI_API_KEY$'` e imprime uma linha
por chave; o healthcheck exige 200 em cada uma.

### Auth compartilhada (ex.: SSO Nexxera)

Credenciais reutilizadas por vários serviços ficam em env vars próprias e
compartilhadas — ex. o Jira autentica com `SSO_NEXXERA_LOGIN`/`SSO_NEXXERA_PASS`,
que qualquer outro serviço atrás do mesmo SSO reutiliza. Não duplique o segredo.

---

## 🔄 Rotação e manutenção de credenciais

A rotação é **central no Bitwarden** — sem git commit/push de segredo, sem
re-encriptar nada.

**Quando uma credencial muda:**
1. Edite o valor no **Bitwarden** (web/app).
2. Em **cada máquina**: `./refresh.sh` (faz `git pull` de código + re-busca do bws →
   atualiza `settings.json` e o espelho runtime).
3. O **próximo curl** que der `source` no espelho já usa o valor novo. Sessões
   novas também. Sem reiniciar (para o espelho runtime).

> `refresh.sh` ≠ propagação de segredo. O `git pull` dele serve só para puxar
> **código/serviços novos** de outra máquina; os segredos sempre vêm do Bitwarden.

**Poda de órfãs:** o `bootstrap` lembra (em `~/.config/claude-creds/managed-keys`)
quais chaves ele injetou. Se um secret some do Bitwarden, ele **remove** essa chave
do `settings.json` no próximo run — sem mexer em chaves que você pôs à mão.

**Auto-recuperação (opcional):** `./svc-curl.sh` envolve o curl e, em **401/403**,
roda `./refresh.sh` e tenta **uma vez** de novo. Como o refresh usa o token de
máquina do bws, não há prompt de senha.

```bash
./svc-curl.sh -s -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" "$JIRA_BASE_URL/rest/api/2/issue/CTR-703"
```

---

## 🔒 Regras de segurança

- **Nunca** imprima segredos em texto puro no chat; ao testar, mostre só `%{http_code}`.
- `secrets.env`, `*.env` e `bws-token` estão no `.gitignore` — nada de segredo no repo.
- O `bws-token` e o espelho runtime ficam **fora do repo**, em `~/.config/claude-creds/` (chmod 600).
- Se um token vazar (ex. colado no chat), **rotacione** no Bitwarden e regrave com
  `printf '%s' 'NOVO' > ~/.config/claude-creds/bws-token`.

---

## ✅ Divisão de responsabilidades (resumo)

- **Adicionar serviço** → secret(s) no Bitwarden + pasta `services/<id>/` (núcleo intacto).
- **Rotacionar credencial** → editar no Bitwarden + `./refresh.sh` (núcleo intacto).
- **Leitura sempre correta** → `source` do espelho runtime antes do curl.
- **Máquina nova** → instalar `bws` + gravar token + `./bootstrap.sh` + reiniciar o Claude.
