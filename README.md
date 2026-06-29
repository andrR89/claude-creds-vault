# claude-creds-vault

Cofre de credenciais plugável para o Claude Code. Cada serviço vive em
`services/<id>/`. **A fonte da verdade são os segredos no Bitwarden Secrets Manager**
(nada de segredo no git). As credenciais são persistidas no bloco `env` do
`~/.claude/settings.json` e num espelho runtime `~/.config/claude-creds/secrets.env`.

## Pré-requisitos (uma vez, na conta Bitwarden)
1. Ative o **Secrets Manager** (free org) e crie um projeto, ex.: `claude-creds`.
2. Crie um **secret por variável** (key = nome da env var):
   `JIRA_BASE_URL`, `JIRA_USER`, `JIRA_PASS`, `GITLAB_BASE_URL`, `GITLAB_TOKEN`.
3. Crie uma **machine account** com acesso **read** ao projeto e gere um **access token**.
4. Instale o `bws` CLI (releases de `bitwarden/sdk-sm`).

## Máquina nova
```bash
git clone <url-privada> claude-creds-vault && cd claude-creds-vault
mkdir -p ~/.config/claude-creds
printf '%s' '<SEU_BWS_ACCESS_TOKEN>' > ~/.config/claude-creds/bws-token
chmod 600 ~/.config/claude-creds/bws-token
./bootstrap.sh          # busca do Bitwarden → grava no settings.json + espelho runtime
./healthcheck.sh        # confirma cada serviço (espera 200)
# reinicie o Claude Code (o bloco env do settings.json só vale em sessões novas)
```

## Rotacionar uma credencial
1. Edite o valor no Bitwarden (web/app).
2. Em cada máquina: `./refresh.sh` (re-busca do Bitwarden).
Sem git commit/push de segredo, sem re-encriptar.

## Adicionar um serviço novo
1. Adicione o(s) secret(s) no projeto do Bitwarden.
2. Copie `services/_TEMPLATE/` para `services/<id>/` e ajuste `check.sh`/`README.md`.
3. `./bootstrap.sh && ./healthcheck.sh` — o núcleo descobre a pasta sozinho.

## Usar um serviço (sempre o valor atual)
```bash
set -a; source ~/.config/claude-creds/secrets.env; set +a
curl -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/issue/CTR-703"
```
