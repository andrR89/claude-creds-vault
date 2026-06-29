# CLAUDE.md — orientação para o Claude Code

Este repo é um **cofre de credenciais plugável**. As credenciais NÃO ficam aqui —
ficam no **Bitwarden Secrets Manager** e chegam como **variáveis de ambiente**.

## Como usar uma credencial num curl
As env vars já estão no bloco `env` do `~/.claude/settings.json` (sessões novas). Numa
sessão já aberta, sempre carregue o espelho runtime antes (pega rotação na hora):

```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a
```

## Onde está o "como falar com cada API"
Cada serviço tem `services/<id>/README.md` com **auth + env vars + receitas de curl +
link da doc oficial**. Leia o README do serviço antes de montar uma chamada. Hoje:
`services/jira/`, `services/gitlab/`, `services/clickup/`.

- Precisa de algo fora das receitas? Consulte o link **Docs** no topo do README do serviço.
- Operações de **escrita** alteram dados reais — confirme com o usuário antes.
- **Nunca** imprima segredos em texto puro; ao testar, mostre só status HTTP / dados não sensíveis.

## Operações de manutenção (núcleo, não precisa editar)
- `./bootstrap.sh` — busca do Bitwarden → injeta no settings.json + espelho runtime.
- `./refresh.sh` — re-busca após rotação (edite o valor no Bitwarden, depois rode isto).
- `./healthcheck.sh` — roda `services/*/check.sh`, espera HTTP 200 em cada um.

## Adicionar um serviço novo
1. Criar o secret no Bitwarden (name = nome EXATO da env var).
2. Copiar `services/_TEMPLATE/` → `services/<id>/` e ajustar `check.sh` + `README.md`.
3. `./bootstrap.sh && ./healthcheck.sh`. O núcleo descobre a pasta sozinho.
