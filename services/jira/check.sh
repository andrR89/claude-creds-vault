#!/usr/bin/env bash
code=$(curl -s -o /dev/null -w '%{http_code}' -u "$JIRA_USER:$JIRA_PASS" "$JIRA_BASE_URL/rest/api/2/myself")
echo "jira: $code"
