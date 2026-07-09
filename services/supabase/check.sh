#!/usr/bin/env bash
# Supabase Management API: bearer com personal access token. Base URL é pública/fixa.
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" "https://api.supabase.com/v1/organizations")
echo "supabase: $code"
