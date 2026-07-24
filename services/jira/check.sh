#!/usr/bin/env bash
# O Jira Nexxera serve cadeia TLS incompleta — usa o CA bundle local se existir
# (~/.config/nexxera/jira-ca-bundle.pem); sem ele, vale o trust store do sistema.
JIRA_CA=~/.config/nexxera/jira-ca-bundle.pem
CA=(); [ -f "$JIRA_CA" ] && CA=(--cacert "$JIRA_CA")
code=$(curl -s -o /dev/null -w '%{http_code}' "${CA[@]}" -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" "$JIRA_BASE_URL/rest/api/2/myself")
echo "jira: $code"
