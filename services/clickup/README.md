# clickup
- **Auth:** header `Authorization: $CLICKUP_API_KEY` (token pessoal, **sem** "Bearer")
- **Env vars:** `CLICKUP_API_KEY`
- **Base URL:** `https://api.clickup.com/api/v2` (pública/fixa, não é segredo)
- **Docs:** API reference: <https://developer.clickup.com/reference/> · autenticação: <https://developer.clickup.com/docs/authentication>

## Receitas (para o Claude usar)
```bash
# usuário autenticado (health check)
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/user"

# workspaces (teams) a que você pertence — pega o team_id
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team"

# spaces de um workspace
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/team/<team_id>/space"

# uma task específica
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/task/<task_id>"

# tasks de uma lista
curl -s -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/list/<list_id>/task"
```
