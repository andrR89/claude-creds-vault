#!/usr/bin/env bash
# Biblioteca de sessão do Kibana — MULTI-AMBIENTE (logging do OpenShift / Elasticsearch).
# Ambientes descobertos por env vars KIBANA_BASE_URL_<ENV> (ex.: _DEV, _PRD).
# Auth detectada por host:
#   - OAuth proxy (openshift-auth-proxy): login via desafio basic-auth do SSO → cookie ~1h.
#       requer: SSO_NEXXERA_LOGIN, SSO_NEXXERA_PASS
#   - X-Pack/basic: usa credencial dedicada do ambiente:
#       KIBANA_<ENV>_APIKEY  (header Authorization: ApiKey)  OU
#       KIBANA_<ENV>_USER + KIBANA_<ENV>_PASS  (basic auth)
# Sem credencial válida, o ambiente simplesmente falha o healthcheck (pendente).

# Lista os ambientes definidos (ex.: "DEV PRD").
kibana_envs() { compgen -A variable | sed -n 's/^KIBANA_BASE_URL_\(.*\)$/\1/p' | sort; }

_kibana_url() { local v="KIBANA_BASE_URL_$1"; echo "${!v%/}"; }
_kibana_jar() { echo "$HOME/.config/claude-creds/kibana-cookie-$1"; }

# Detecta o tipo de auth do host: "oauth" | "xpack" | "open" | "unknown:<code>"
_kibana_auth_kind() {
  local code; code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$1/api/status")
  case "$code" in 302) echo oauth ;; 401) echo xpack ;; 200) echo open ;; *) echo "unknown:$code" ;; esac
}

# Login OAuth (authorization-code) via desafio basic-auth do SSO → grava o cookie (600).
_kibana_login_oauth() {
  local url="$1" jar="$2" tmp au rd; tmp="$(mktemp)"
  au=$(curl -sk -c "$tmp" -o /dev/null -w '%{redirect_url}' --max-time 12 "$url/api/status")
  rd=$(curl -sk -c "$tmp" -b "$tmp" -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" -H 'X-CSRF-Token: 1' \
       -o /dev/null -w '%{redirect_url}' --max-time 15 "$au")
  echo "$rd" | grep -q 'callback' || { rm -f "$tmp"; return 1; }
  curl -sk -c "$tmp" -b "$tmp" -o /dev/null --max-time 12 "$rd"
  install -m 600 "$tmp" "$jar"; rm -f "$tmp"
}

# Núcleo: consulta o ES de um ambiente via proxy do Kibana, resolvendo a auth sozinho.
# Uso: kibana_curl <ENV> <path-ES> [args extra do curl]
kibana_curl() {
  local env="$1" path="$2"; shift 2
  local url; url="$(_kibana_url "$env")"
  [ -n "$url" ] || { echo "❌ KIBANA_BASE_URL_$env não definida" >&2; return 1; }
  case "$(_kibana_auth_kind "$url")" in
    oauth)
      local jar code; jar="$(_kibana_jar "$env")"
      code=$(curl -sk -b "$jar" -o /dev/null -w '%{http_code}' --max-time 10 "$url/elasticsearch/" 2>/dev/null)
      [ "$code" = 200 ] || _kibana_login_oauth "$url" "$jar" || { echo "❌ login SSO falhou ($env)" >&2; return 1; }
      curl -sk -b "$jar" -H 'kbn-xsrf: true' --max-time 30 "$@" "$url/elasticsearch/$path"
      ;;
    xpack)
      local kvar="KIBANA_${env}_APIKEY" uvar="KIBANA_${env}_USER" pvar="KIBANA_${env}_PASS"
      if [ -n "${!kvar:-}" ]; then
        curl -sk -H "Authorization: ApiKey ${!kvar}" -H 'kbn-xsrf: true' --max-time 30 "$@" "$url/elasticsearch/$path"
      elif [ -n "${!uvar:-}" ] && [ -n "${!pvar:-}" ]; then
        curl -sk -u "${!uvar}:${!pvar}" -H 'kbn-xsrf: true' --max-time 30 "$@" "$url/elasticsearch/$path"
      else
        echo "❌ sem credencial p/ $env (X-Pack): defina KIBANA_${env}_APIKEY ou KIBANA_${env}_USER/_PASS" >&2
        return 2
      fi
      ;;
    *) echo "❌ auth não reconhecida em $env" >&2; return 1 ;;
  esac
}

# Status HTTP do ES root de um ambiente (após resolver a auth). Uso: kibana_status <ENV>
kibana_status() { kibana_curl "$1" "" -o /dev/null -w '%{http_code}'; }
