# gitlab (token)
- **Auth:** header `PRIVATE-TOKEN: $GITLAB_TOKEN`
- **Env vars:** `GITLAB_BASE_URL`, `GITLAB_TOKEN`

## Receitas
```bash
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_BASE_URL/api/v4/projects?membership=true"
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_BASE_URL/api/v4/projects/traducao%2Fpython%2Fconector2/issues?state=opened"
```
