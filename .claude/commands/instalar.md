---
description: Onboarding completo do creds-vault nesta máquina (instala bws, configura o token, bootstrap + healthcheck)
---

Você vai instalar/configurar o **claude-creds-vault** nesta máquina, do zero, de forma
idempotente (pode rodar de novo sem quebrar). Trabalhe a partir da raiz do repo (a pasta
que contém `bootstrap.sh`). Execute na ordem e **pare e reporte** se algum passo falhar.

**Regra de ouro:** NUNCA imprima segredos (token, senhas, valores de env) no chat. Ao
testar, mostre só status HTTP / nomes de chave mascarados.

## 1. Conferir dependências
Verifique `git`, `python3`, `curl`. Se faltar alguma, avise o usuário (não tente
instalar essas — são do sistema).

## 2. Instalar o `bws` (Bitwarden Secrets Manager CLI) se faltar
Se `command -v bws` falhar, baixe o binário do `bitwarden/sdk-sm` para `~/.local/bin`,
detectando SO/arch:

```bash
OS=$(uname -s); ARCH=$(uname -m); T=""
case "$OS/$ARCH" in
  Linux/x86_64)  T=x86_64-unknown-linux-gnu ;;
  Linux/aarch64) T=aarch64-unknown-linux-gnu ;;
  Darwin/arm64)  T=aarch64-apple-darwin ;;
  Darwin/x86_64) T=x86_64-apple-darwin ;;
  *) echo "arch não mapeada: $OS/$ARCH — instale o bws manualmente"; exit 1 ;;
esac
TAG=$(curl -s https://api.github.com/repos/bitwarden/sdk-sm/releases \
  | python3 -c "import sys,json;print(next(r['tag_name'] for r in json.load(sys.stdin) if r['tag_name'].startswith('bws-v')))")
VER=${TAG#bws-v}
curl -sL -o /tmp/bws.zip "https://github.com/bitwarden/sdk-sm/releases/download/${TAG}/bws-${T}-${VER}.zip"
mkdir -p ~/.local/bin
command -v unzip >/dev/null && unzip -o /tmp/bws.zip -d ~/.local/bin \
  || python3 -c "import zipfile;zipfile.ZipFile('/tmp/bws.zip').extractall('$HOME/.local/bin')"
chmod +x ~/.local/bin/bws && rm -f /tmp/bws.zip
~/.local/bin/bws --version
```

Se `~/.local/bin` não estiver no PATH, avise o usuário para adicioná-lo ao shell profile
(`export PATH="$HOME/.local/bin:$PATH"`).

## 3. Configurar o access token do Bitwarden
Cheque `~/.config/claude-creds/bws-token`. Se **não existir** ou ainda contiver o
placeholder `COLE_SEU_TOKEN_AQUI`, **peça ao usuário o BWS_ACCESS_TOKEN** (token da
machine account, com acesso read ao projeto). Grave sem quebra de linha e com permissão
restrita — sem ecoar o valor:

```bash
mkdir -p ~/.config/claude-creds
printf '%s' 'TOKEN_QUE_O_USUARIO_PASSOU' > ~/.config/claude-creds/bws-token
chmod 600 ~/.config/claude-creds/bws-token
```

## 4. Bootstrap
Rode `./bootstrap.sh`. Ele busca os segredos no Bitwarden, injeta no bloco `env` do
`~/.claude/settings.json`, cria o espelho runtime (600) e atualiza a ponte no
`~/.claude/CLAUDE.md`. Se gravar **0 variáveis**, diagnostique: `bws project list` /
`bws secret list` — provável falta de acesso read da machine account ao projeto.

## 5. Healthcheck
Rode `./healthcheck.sh` e reporte o status de cada serviço. Se algum não for 200,
explique brevemente o provável motivo (key inválida, sessão expirada, host inacessível).

## 6. Finalizar
Avise o usuário para **reiniciar o Claude Code** — o bloco `env` do `settings.json` só
vale em sessões novas. Resuma o que ficou pronto e o que (se algo) ficou pendente.
