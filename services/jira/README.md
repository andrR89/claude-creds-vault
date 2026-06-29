# jira (legado — basic auth)
- **Auth:** básica (`-u "$JIRA_USER:$JIRA_PASS"`)
- **Env vars:** `JIRA_BASE_URL`, `JIRA_USER`, `JIRA_PASS`
- **Docs:** REST API (Server/DC): <https://docs.atlassian.com/software/jira/docs/api/REST/latest/> · JQL: <https://support.atlassian.com/jira-service-management-cloud/docs/use-advanced-search-with-jira-query-language-jql/>

## Receitas
```bash
curl -s -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/issue/CTR-703"
curl -s -G -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/search" \
  --data-urlencode 'jql=project=CTR ORDER BY updated DESC'
```
