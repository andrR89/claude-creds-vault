#!/usr/bin/env bash
code=$(curl -s -o /dev/null -w '%{http_code}' -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_BASE_URL/api/v4/user")
echo "gitlab: $code"
