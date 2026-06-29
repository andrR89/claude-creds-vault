#!/usr/bin/env bash
# Testa toda env var que termine em GEMINI_API_KEY (MY_..., NEXXERA_..., etc.)
# via ListModels. Cada linha imprime o status; healthcheck espera 200.
B="https://generativelanguage.googleapis.com/v1beta/models"
found=0
for var in $(compgen -A variable | grep -E 'GEMINI_API_KEY$'); do
  found=1
  key="${!var}"
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "x-goog-api-key: $key" "$B")
  echo "gemini ($var): $code"
done
[ "$found" = 1 ] || echo "gemini: nenhuma *GEMINI_API_KEY no ambiente"
