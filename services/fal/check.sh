#!/usr/bin/env bash
# fal.ai não tem endpoint de "ping" gratuito; validamos a key SEM gerar (sem custo):
# GET no endpoint de um modelo → 401 = key inválida; 405 = autenticou (só método errado).
raw=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Key $FAL_AI_API_KEY" "https://fal.run/fal-ai/flux/schnell")
case "$raw" in
  200|405) echo "fal: 200 (auth ok, sem gerar; raw=$raw)" ;;
  *)       echo "fal: $raw" ;;
esac
