# clickup
- **Auth:** header `Authorization: $CLICKUP_API_KEY` (token pessoal, **sem** "Bearer")
- **Env vars:** `CLICKUP_API_KEY`
- **Base URL:** `https://api.clickup.com/api/v2` (pública/fixa, não é segredo)
- **Docs:** API reference: <https://developer.clickup.com/reference/> · autenticação: <https://developer.clickup.com/docs/authentication>

> Antes de qualquer curl numa sessão já aberta:
> `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> Hierarquia: **workspace (team) → space → folder → list → task**.

## Leitura
```bash
B="https://api.clickup.com/api/v2"; H="Authorization: $CLICKUP_API_KEY"

curl -s -H "$H" "$B/user"                              # usuário autenticado (health check)
curl -s -H "$H" "$B/team"                              # workspaces (pega o team_id)
curl -s -H "$H" "$B/team/<team_id>/space?archived=false"   # spaces do workspace
curl -s -H "$H" "$B/space/<space_id>/folder"           # folders de um space
curl -s -H "$H" "$B/space/<space_id>/list"             # lists SEM folder
curl -s -H "$H" "$B/folder/<folder_id>/list"           # lists DENTRO de um folder
curl -s -H "$H" "$B/list/<list_id>/task?archived=false"    # tasks de uma list
curl -s -H "$H" "$B/task/<task_id>"                    # uma task
curl -s -H "$H" "$B/task/<task_id>/comment"            # comentários de uma task
# filtros úteis em /list/<id>/task: &statuses[]=open &assignees[]=<user_id> &subtasks=true
```

## Escrita (⚠️ altera dados reais — confirme antes)
```bash
# criar task numa list
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  "$B/list/<list_id>/task" -d '{"name":"Título","description":"Detalhe","status":"to do"}'

# atualizar task (status, nome, etc.)
curl -s -X PUT -H "$H" -H "Content-Type: application/json" \
  "$B/task/<task_id>" -d '{"status":"in progress"}'

# comentar numa task
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  "$B/task/<task_id>/comment" -d '{"comment_text":"meu comentário"}'
```
