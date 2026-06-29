#!/usr/bin/env bash
# Troque <SVC> e a URL/headers. Deve imprimir "<nome>: <http_code>".
code=$(curl -s -o /dev/null -w '%{http_code}' "$SVC_BASE_URL/endpoint/de/saude")
echo "<nome>: $code"
