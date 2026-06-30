#!/usr/bin/env bash
# Biblioteca de sessão do Kibana (logging do OpenShift / Elasticsearch).
# Requer no ambiente: SSO_NEXXERA_LOGIN, SSO_NEXXERA_PASS.
# A sessão é um cookie do openshift-auth-proxy (~1h); renovamos sozinhos.
KIBANA_URL="${KIBANA_URL:-https://kibana.cloudint.nexxera.com}"
KIBANA_JAR="${KIBANA_JAR:-$HOME/.config/claude-creds/kibana-cookie}"

# Faz o fluxo OAuth (authorization-code) via desafio basic-auth do SSO e grava o cookie (600).
_kibana_login() {
  local tmp au rd; tmp="$(mktemp)"
  au=$(curl -sk -c "$tmp" -o /dev/null -w '%{redirect_url}' --max-time 12 "$KIBANA_URL/api/status") || { rm -f "$tmp"; return 1; }
  rd=$(curl -sk -c "$tmp" -b "$tmp" -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" -H 'X-CSRF-Token: 1' \
       -o /dev/null -w '%{redirect_url}' --max-time 15 "$au")
  echo "$rd" | grep -q 'callback' || { rm -f "$tmp"; return 1; }   # IdP não aceitou basic-auth
  curl -sk -c "$tmp" -b "$tmp" -o /dev/null --max-time 12 "$rd"      # callback seta o cookie
  install -m 600 "$tmp" "$KIBANA_JAR"; rm -f "$tmp"
}

# Garante sessão válida: reusa o cookie; se ausente/expirado (ES root != 200), re-loga.
kibana_ensure() {
  if [ -f "$KIBANA_JAR" ]; then
    local code; code=$(curl -sk -b "$KIBANA_JAR" -o /dev/null -w '%{http_code}' --max-time 12 "$KIBANA_URL/elasticsearch/")
    [ "$code" = 200 ] && return 0
  fi
  _kibana_login
}

# Consulta o Elasticsearch via proxy do Kibana: kibana_es <path-ES> [args extra do curl]
kibana_es() {
  local path="$1"; shift
  curl -sk -b "$KIBANA_JAR" -H 'kbn-xsrf: true' --max-time 30 "$@" "$KIBANA_URL/elasticsearch/$path"
}
