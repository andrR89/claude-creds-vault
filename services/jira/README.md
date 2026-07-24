# jira (legado — basic auth via SSO Nexxera)
- **Auth:** básica com as credenciais do **SSO Nexxera** (`-u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS"`)
- **Env vars:** `JIRA_BASE_URL`, `SSO_NEXXERA_LOGIN`, `SSO_NEXXERA_PASS`
- **Nota:** `SSO_NEXXERA_*` são compartilhadas — qualquer outro serviço atrás do mesmo SSO reutiliza essas mesmas envs.
- **Docs:** REST API (Server/DC): <https://docs.atlassian.com/software/jira/docs/api/REST/latest/> · JQL: <https://support.atlassian.com/jira-service-management-cloud/docs/use-advanced-search-with-jira-query-language-jql/>

> Antes de qualquer curl numa sessão já aberta:
> `set -a; source ~/.config/claude-creds/secrets.env; set +a`
> API v2 (Server/Data Center). `<KEY>` é a chave da issue (ex. `CTR-703`).
> **TLS:** o servidor serve cadeia incompleta; se existir
> `~/.config/nexxera/jira-ca-bundle.pem`, passe `--cacert` (como no `A=(…)` abaixo).

## Leitura
```bash
A=(-u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS"); B="$JIRA_BASE_URL/rest/api/2"
[ -f ~/.config/nexxera/jira-ca-bundle.pem ] && A+=(--cacert ~/.config/nexxera/jira-ca-bundle.pem)

curl -s "${A[@]}" "$B/myself"                                  # usuário autenticado
curl -s "${A[@]}" "$B/issue/<KEY>"                             # uma issue
curl -s "${A[@]}" "$B/issue/<KEY>?fields=summary,status,assignee"  # campos específicos
curl -s -G "${A[@]}" "$B/search" \
  --data-urlencode 'jql=project=CTR AND status!=Done ORDER BY updated DESC' \
  --data-urlencode 'maxResults=20'                            # busca por JQL
curl -s "${A[@]}" "$B/issue/<KEY>/transitions"                # transições possíveis (pega o id)
curl -s "${A[@]}" "$B/issue/<KEY>/comment"                    # comentários
```

## Escrita (⚠️ altera dados reais — confirme antes)
```bash
# comentar numa issue
curl -s -X POST "${A[@]}" -H "Content-Type: application/json" \
  "$B/issue/<KEY>/comment" -d '{"body":"meu comentário"}'

# mover de status (id vem de /transitions)
curl -s -X POST "${A[@]}" -H "Content-Type: application/json" \
  "$B/issue/<KEY>/transitions" -d '{"transition":{"id":"<transition_id>"}}'

# criar issue
curl -s -X POST "${A[@]}" -H "Content-Type: application/json" "$B/issue" \
  -d '{"fields":{"project":{"key":"CTR"},"summary":"Título","issuetype":{"name":"Task"}}}'
```
