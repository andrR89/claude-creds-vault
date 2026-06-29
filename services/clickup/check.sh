#!/usr/bin/env bash
# ClickUp: header Authorization simples (token pessoal, sem "Bearer"). Base URL é pública/fixa.
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: $CLICKUP_API_KEY" "https://api.clickup.com/api/v2/user")
echo "clickup: $code"
