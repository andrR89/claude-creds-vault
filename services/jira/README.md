# jira (legado — basic auth)
- **Auth:** básica (`-u "$JIRA_USER:$JIRA_PASS"`)
- **Env vars:** `JIRA_BASE_URL`, `JIRA_USER`, `JIRA_PASS`

## Receitas
```bash
curl -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/issue/CTR-703"
curl -s -G -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/search" \
  --data-urlencode 'jql=project=CTR ORDER BY updated DESC'
```
