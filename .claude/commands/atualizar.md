---
description: Re-sincroniza o creds-vault (git pull + re-busca do Bitwarden + bootstrap) e roda o healthcheck
---

Você vai **atualizar** o claude-creds-vault nesta máquina: puxar novidades de código e
re-sincronizar as credenciais do Bitwarden. Trabalhe a partir da raiz do repo (a pasta
que contém `refresh.sh`). Assuma que `bws` e `~/.config/claude-creds/bws-token` já
existem — se faltarem, oriente o usuário a rodar `/instalar`.

**Regra de ouro:** NUNCA imprima segredos no chat; mascare valores, mostre só status.

## 1. Refresh
Rode `./refresh.sh`. Ele faz `git pull --ff-only` (pega código/serviços novos), re-busca
os segredos no Bitwarden e re-executa o bootstrap — o que também **poda envs órfãs**
(que você apagou no Bitwarden) e **atualiza as pontes de contexto** das ferramentas
detectadas (`~/.claude/CLAUDE.md`, `~/.gemini/GEMINI.md`, OpenCode, Kilo Code…).

## 2. Healthcheck
Rode `./healthcheck.sh`. Reporte o status por serviço numa lista clara.

## 3. Reportar
- Se **tudo 200**: confirme que está tudo verde e diga quantos serviços/variáveis.
- Se **algum não-200**: destaque qual e dê um diagnóstico curto e acionável
  (ex.: `400 API_KEY_INVALID` → key inválida no Bitwarden; sessão expirada → re-login;
  `000` → host inacessível desta rede). Sugira o próximo passo.
- Se o `bootstrap` removeu órfãs ou a ponte mudou (serviço novo), mencione.

Lembre o usuário: rotação de credencial só precisa de `/atualizar`; serviço novo que
mexa em `settings.json`/`.env` pode pedir **reiniciar a ferramenta** para valer em
sessões já abertas (ou `source` no espelho runtime na sessão atual).
