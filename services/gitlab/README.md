# gitlab (token)
- **Auth:** header `PRIVATE-TOKEN: $GITLAB_TOKEN`
- **Env vars:** `GITLAB_BASE_URL`, `GITLAB_TOKEN`
- **Docs:** REST API: <https://docs.gitlab.com/ee/api/rest/> · índice de endpoints: <https://docs.gitlab.com/ee/api/api_resources.html>

## Receitas
```bash
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_BASE_URL/api/v4/projects?membership=true"
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_BASE_URL/api/v4/projects/traducao%2Fpython%2Fconector2/issues?state=opened"
```
