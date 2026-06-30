#!/usr/bin/env bash
# Garante a sessão SSO e confirma acesso ao Elasticsearch (raiz = 200).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
kibana_ensure >/dev/null 2>&1
code=$(curl -sk -b "$KIBANA_JAR" -o /dev/null -w '%{http_code}' --max-time 12 "$KIBANA_URL/elasticsearch/")
echo "kibana: $code"
