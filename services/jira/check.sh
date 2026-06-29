#!/usr/bin/env bash
code=$(curl -s -o /dev/null -w '%{http_code}' -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" "$JIRA_BASE_URL/rest/api/2/myself")
echo "jira: $code"
