# Design — desabilitar serviço sem credencial (`env.required`)

**Data:** 2026-07-02
**Problema:** hoje, se as env vars de um serviço não vêm do Bitwarden (token da
máquina não enxerga o secret), o `check.sh` roda com vars vazias → falha genérica
no healthcheck, e a ponte anuncia ao agente um serviço que ele não consegue usar.

**Decisão:** serviço sem credencial **some por completo** — o healthcheck pula
(sem falhar) e a ponte deixa de anunciá-lo.

## 1. Convenção — `services/<id>/env.required`

Arquivo **opcional**, 1 entrada por linha; linhas vazias e `#` comentários são
ignorados:

- Nome literal (`CLICKUP_API_KEY`) → exige a var definida e **não-vazia**.
- Padrão com `*` (`KIBANA_BASE_URL_*`) → exige **pelo menos uma** env var cujo
  nome case o padrão (glob), não-vazia.
- Várias linhas = **todas** exigidas (AND); o `*` dá o OR dentro da linha.
- **Sem arquivo → serviço sempre ativo** (retrocompatível).
- Erro de leitura (arquivo ilegível etc.) trata como "sem arquivo" = ativo —
  nunca desabilitar por acidente.

## 2. `healthcheck.sh`

Antes de rodar cada `check.sh`, valida o `env.required` contra o ambiente já
carregado (espelho runtime). Faltando algo:

```
kibana: — desabilitado (falta KIBANA_BASE_URL_*)
```

e **não conta como falha** — o exit code reflete só os serviços ativos.

## 3. `bootstrap.sh` (`write_bridge`)

O Python que monta a tabela por serviço lê o `env.required` de cada um e valida
contra as chaves do **espelho runtime** (`secrets.env`, recém-escrito — fonte
única). Serviço desabilitado **sai da tabela** de todas as pontes
(Claude/Gemini-Antigravity/OpenCode/Kilo). Mensagem final passa a informar, ex.:

```
✅ Ponte p/ o agente (claude): ~/.claude/CLAUDE.md (6 serviços anunciados, 1 desabilitado: kibana)
```

## 4. Conteúdo dos `env.required`

| Serviço | Entradas |
|---|---|
| clickup | `CLICKUP_API_KEY` |
| fal | `FAL_AI_API_KEY` |
| gemini | `*GEMINI_API_KEY` |
| gitlab | `GITLAB_BASE_URL`, `GITLAB_TOKEN` |
| jira | `JIRA_BASE_URL`, `SSO_NEXXERA_LOGIN`, `SSO_NEXXERA_PASS` |
| kibana | `KIBANA_BASE_URL_*` |
| openshift | `OKD_*_URL`, `SSO_NEXXERA_LOGIN`, `SSO_NEXXERA_PASS` |

`_TEMPLATE` ganha um `env.required` de exemplo (comentado) documentando a sintaxe.

## 5. Testes (manuais, sem framework — repo é shell puro)

1. **Baseline:** `./healthcheck.sh` e `./bootstrap.sh` com tudo presente →
   saída igual à de hoje (nenhum desabilitado).
2. **Healthcheck pulando:** `env -u CLICKUP_API_KEY ./healthcheck.sh` → linha
   `clickup: — desabilitado (falta CLICKUP_API_KEY)`, exit code ignora clickup.
3. **Ponte omitindo:** bootstrap apontado para um `secrets.env` temporário sem
   uma chave → serviço some da tabela da ponte e a contagem informa o
   desabilitado. (Restaurar estado real ao final com `./bootstrap.sh` normal.)

## Fora de escopo

- Desabilitar por flag manual (só por ausência de credencial).
- Validação de *valor* da credencial (isso é papel do `check.sh`/healthcheck).
