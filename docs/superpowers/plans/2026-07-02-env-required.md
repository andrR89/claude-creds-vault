# env.required — desabilitar serviço sem credencial — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** serviço cujas env vars não vieram do Bitwarden some por completo — healthcheck pula sem falhar e as pontes (CLAUDE.md/GEMINI.md/AGENTS.md/Kilo) deixam de anunciá-lo.

**Architecture:** convenção nova `services/<id>/env.required` (opcional; 1 entrada por linha; glob `*` = "pelo menos uma var casando"; todas as linhas exigidas). Dois consumidores: `healthcheck.sh` (valida contra o ambiente carregado do bws e pula com mensagem) e o Python de `write_bridge` no `bootstrap.sh` (valida contra as chaves do espelho runtime e omite a linha da tabela). Sem arquivo ou erro de leitura → serviço ativo (retrocompatível, nunca desabilita por acidente).

**Tech Stack:** bash (healthcheck), python3 inline (bootstrap) — sem dependências novas. Testes manuais via serviço fake temporário `services/zzztest/` (o healthcheck re-carrega secrets do bws, então `env -u` NÃO simula ausência — o fake exige uma var que não existe em lugar nenhum).

**Spec:** `docs/superpowers/specs/2026-07-02-env-required-desabilitar-servico-design.md`

---

### Task 1: arquivos `env.required` (7 serviços + _TEMPLATE)

**Files:**
- Create: `services/clickup/env.required`, `services/fal/env.required`, `services/gemini/env.required`, `services/gitlab/env.required`, `services/jira/env.required`, `services/kibana/env.required`, `services/openshift/env.required`, `services/_TEMPLATE/env.required`

- [ ] **Step 1: criar os 8 arquivos**

```bash
cd /home/andre/Workspace/claude-creds-vault

printf '%s\n' 'CLICKUP_API_KEY' > services/clickup/env.required
printf '%s\n' 'FAL_AI_API_KEY'  > services/fal/env.required
printf '%s\n' '*GEMINI_API_KEY' > services/gemini/env.required
printf '%s\n' 'GITLAB_BASE_URL' 'GITLAB_TOKEN' > services/gitlab/env.required
printf '%s\n' 'JIRA_BASE_URL' 'SSO_NEXXERA_LOGIN' 'SSO_NEXXERA_PASS' > services/jira/env.required
printf '%s\n' 'KIBANA_BASE_URL_*' > services/kibana/env.required
printf '%s\n' 'OKD_*_URL' 'SSO_NEXXERA_LOGIN' 'SSO_NEXXERA_PASS' > services/openshift/env.required

cat > services/_TEMPLATE/env.required <<'EOF'
# env.required (OPCIONAL) — se alguma entrada não estiver satisfeita no ambiente,
# o serviço é DESABILITADO: healthcheck pula (sem falhar) e a ponte não o anuncia.
# Sintaxe: 1 entrada por linha; '#' comenta.
#   NOME_LITERAL   → exige a env var definida e não-vazia
#   PADRAO_COM_*   → exige PELO MENOS UMA env var casando o glob (ex.: KIBANA_BASE_URL_*)
# Todas as linhas são exigidas (AND). Sem este arquivo → serviço sempre ativo.
#EXEMPLO_API_KEY
EOF
```

- [ ] **Step 2: conferir conteúdo**

Run: `head -99 services/*/env.required`
Expected: 8 arquivos, conteúdos conforme acima (o `_TEMPLATE` só com comentários).

- [ ] **Step 3: commit**

```bash
git add services/*/env.required
git commit -m "feat(services): declara env.required (vars exigidas por serviço)"
```

---

### Task 2: `healthcheck.sh` — pular serviço desabilitado

**Files:**
- Modify: `healthcheck.sh:14-25` (loop de serviços)
- Test (temporário): `services/zzztest/{check.sh,env.required}`

- [ ] **Step 1: criar o serviço fake (teste que "falha" antes da implementação)**

```bash
mkdir -p services/zzztest
cat > services/zzztest/check.sh <<'EOF'
#!/usr/bin/env bash
echo "zzztest: 999"
EOF
chmod +x services/zzztest/check.sh
printf '%s\n' 'VAR_QUE_NAO_EXISTE_EM_LUGAR_NENHUM' > services/zzztest/env.required
```

- [ ] **Step 2: rodar healthcheck e verificar que HOJE ele falha por causa do fake**

Run: `./healthcheck.sh; echo "exit=$?"`
Expected: linha `zzztest: 999` na saída e `exit=1` (o env.required ainda é ignorado).
(Obs.: gemini NEXXERA=400 e kibana PRD=000 podem falhar também — problema pré-existente conhecido; o que importa aqui é a linha `zzztest: 999` aparecer.)

- [ ] **Step 3: implementar o skip no `healthcheck.sh`**

Substituir o bloco do loop (linhas 14–25 atuais) por:

```bash
# ── env.required: serviço sem credencial é DESABILITADO (pulado), não falha ──
# Sintaxe: 1 entrada por linha ('#' comenta); nome literal exige var não-vazia;
# padrão com '*' (glob) exige pelo menos uma var casando. Sem arquivo → ativo.
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
```

(As linhas finais `[ "$fail" = 0 ] && …` e `exit $fail` ficam como estão.)

- [ ] **Step 4: verificar sintaxe e comportamento novo**

Run: `bash -n healthcheck.sh && ./healthcheck.sh; echo "exit=$?"`
Expected:
- linha `zzztest: — desabilitado (falta VAR_QUE_NAO_EXISTE_EM_LUGAR_NENHUM)`
- NENHUMA linha `zzztest: 999` (check.sh não roda)
- os 7 serviços reais aparecem normalmente (todos têm env.required satisfeito → nada mais desabilitado)
- `exit` igual ao do Step 2 SEM a contribuição do zzztest (i.e. reflete só os serviços reais)

- [ ] **Step 5: commit (sem o fake)**

```bash
git add healthcheck.sh
git commit -m "feat(healthcheck): pula serviço desabilitado (env.required não satisfeito)"
```

---

### Task 3: `bootstrap.sh` — ponte omite serviço desabilitado

**Files:**
- Modify: `bootstrap.sh` — dentro do heredoc `PY` de `write_bridge()` (após o loop que monta `rows`, e o `print` final)

- [ ] **Step 1: verificar comportamento atual com o fake**

Criar um `README.md` mínimo pro fake (a ponte só lista serviços com README):

```bash
cat > services/zzztest/README.md <<'EOF'
# zzztest
- **Auth:** fake
- **Env vars:** `VAR_QUE_NAO_EXISTE_EM_LUGAR_NENHUM`
EOF
./bootstrap.sh
grep -c '| \*\*' ~/.claude/CLAUDE.md
```

Expected: bootstrap imprime `(8 serviços anunciados)` e o grep conta 8 linhas de serviço na tabela (zzztest entrou mesmo sem credencial — o bug que vamos corrigir).

- [ ] **Step 2: implementar o filtro no Python de `write_bridge`**

No `bootstrap.sh`, dentro do heredoc `PY`:

**(a)** trocar a linha de imports `import os, re, sys, glob` por:

```python
import os, re, sys, glob, fnmatch
```

**(b)** logo APÓS o loop `for rd in sorted(glob.glob(...))` que preenche `rows`
(i.e., depois de `rows.append((svc, auth, envs))` e antes de `inject = {`), inserir:

```python
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
```

**(c)** trocar o `print` final:

```python
extra = f", {len(off)} desabilitado(s): {', '.join(svc for svc, _ in off)}" if off else ""
print(f"✅ Ponte p/ o agente ({flavor}): {md} ({len(rows)} serviços anunciados{extra})")
```

- [ ] **Step 3: verificar — fake some da ponte**

Run: `bash -n bootstrap.sh && ./bootstrap.sh && grep -c '| \*\*' ~/.claude/CLAUDE.md && grep zzztest ~/.claude/CLAUDE.md; echo "grep-exit=$?"`
Expected:
- bootstrap imprime, para CADA ponte, `(7 serviços anunciados, 1 desabilitado(s): zzztest)`
- grep -c conta 7; `grep zzztest` não acha nada (`grep-exit=1`)

- [ ] **Step 4: remover o fake e restaurar estado real**

```bash
rm -rf services/zzztest
./bootstrap.sh
```

Expected: `(7 serviços anunciados)` (sem sufixo de desabilitado) em todas as pontes.

- [ ] **Step 5: rodar `./healthcheck.sh` uma última vez (sem o fake)**

Run: `./healthcheck.sh; echo "exit=$?"`
Expected: mesmos resultados dos 7 serviços reais de sempre; nenhuma linha `zzztest`.

- [ ] **Step 6: commit**

```bash
git add bootstrap.sh
git commit -m "feat(bootstrap): ponte omite serviço desabilitado (env.required não satisfeito)"
```

---

### Task 4: documentação

**Files:**
- Modify: `CLAUDE.md` (árvore da arquitetura + seção "Como adicionar uma integração nova")

- [ ] **Step 1: árvore da arquitetura** — em `CLAUDE.md`, trocar a linha:

```
    ├── jira/          # check.sh + README.md (auth + receitas de curl)
```

por:

```
    ├── jira/          # check.sh + README.md (auth + receitas) + env.required (opcional)
```

- [ ] **Step 2: nova subseção** — em `CLAUDE.md`, logo APÓS a subseção "### Padrão multi-chave (ex.: gemini)" e ANTES de "### Auth compartilhada (ex.: SSO Nexxera)", inserir:

```markdown
### Desabilitar automático (`env.required`)

Um serviço pode declarar em `services/<id>/env.required` as env vars que exige
(1 por linha; `#` comenta; nome literal = var não-vazia; padrão com `*` = pelo
menos uma var casando o glob, ex. `KIBANA_BASE_URL_*`; todas as linhas são
exigidas). Se algo faltar — ex.: máquina cujo token do Bitwarden não enxerga
aquele secret — o serviço é **desabilitado por completo**: o `healthcheck` pula
(mostra `desabilitado (falta X)`, sem falhar) e as pontes deixam de anunciá-lo
ao agente. Sem o arquivo (ou com erro de leitura), o serviço fica sempre ativo.
```

- [ ] **Step 3: commit e push de tudo**

```bash
git add CLAUDE.md
git commit -m "docs(CLAUDE.md): documenta env.required (desabilita serviço sem credencial)"
git push
```

---

### Notas para o executor

- **NUNCA** imprimir valores de secrets — só nomes de vars e status HTTP.
- O `zzztest` é temporário: precisa sumir antes do commit da Task 3 (nada dele vai pro git; `git status` deve confirmar).
- A linha de "desabilitado" é impressa ANTES do parser de códigos HTTP do healthcheck (via `continue`), então dígitos no nome da var não disparam falso-negativo.
- `fnmatch.filter(keys, entry)` funciona também para entradas literais (padrão sem `*` casa a si mesmo).
