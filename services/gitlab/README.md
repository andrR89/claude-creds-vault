# gitlab (token)
- **Auth:** header `PRIVATE-TOKEN: $GITLAB_TOKEN`
- **Env vars:** `GITLAB_BASE_URL`, `GITLAB_TOKEN`
- **Docs:** REST API: <https://docs.gitlab.com/ee/api/rest/> · índice de endpoints: <https://docs.gitlab.com/ee/api/api_resources.html>

> Antes de qualquer curl numa sessão já aberta:
> `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> `<project>` pode ser o **ID numérico** ou o **caminho URL-encoded** (`grupo%2Fsub%2Frepo`).

## Leitura
```bash
H="PRIVATE-TOKEN: $GITLAB_TOKEN"; B="$GITLAB_BASE_URL/api/v4"

curl -s -H "$H" "$B/user"                                          # usuário autenticado
curl -s -H "$H" "$B/projects?membership=true&per_page=100"         # meus projetos
curl -s -H "$H" "$B/projects/<project>"                            # um projeto
curl -s -H "$H" "$B/projects/<project>/issues?state=opened"        # issues abertas
curl -s -H "$H" "$B/projects/<project>/merge_requests?state=opened"  # MRs abertos
curl -s -H "$H" "$B/projects/<project>/pipelines?per_page=5"       # últimos pipelines
curl -s -G -H "$H" "$B/search" --data-urlencode 'scope=projects' --data-urlencode 'search=conector'  # busca global
```

## Escrita (⚠️ altera dados reais — confirme antes)
```bash
# criar issue
curl -s -X POST -H "$H" -G "$B/projects/<project>/issues" \
  --data-urlencode 'title=Bug X' --data-urlencode 'description=detalhe'

# comentar numa issue (iid = número da issue no projeto)
curl -s -X POST -H "$H" -G "$B/projects/<project>/issues/<iid>/notes" \
  --data-urlencode 'body=meu comentário'

# fechar issue
curl -s -X PUT -H "$H" "$B/projects/<project>/issues/<iid>?state_event=close"
```
