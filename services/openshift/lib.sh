#!/usr/bin/env bash
# Biblioteca OpenShift — MULTI-CLUSTER, dois estilos de acesso (auth via SSO Nexxera).
# Requer no ambiente: SSO_NEXXERA_LOGIN, SSO_NEXXERA_PASS, e por cluster UMA das URLs:
#   OKD_<ENV>_CONSOLE_URL  → console OKD4 (proxy k8s em /api/kubernetes); login SSO → cookie
#   OKD_<ENV>_API_URL      → API direta (OpenShift 3.x); login SSO challenge → token Bearer
# Sessões cacheadas (600) em ~/.config/claude-creds/okd-cookie-<ENV> / okd-token-<ENV>.

okd_envs() {
  { compgen -A variable | sed -n 's/^OKD_\(.*\)_CONSOLE_URL$/\1/p'
    compgen -A variable | sed -n 's/^OKD_\(.*\)_API_URL$/\1/p'; } | sort -u
}
okd_kind() { local c="OKD_$1_CONSOLE_URL" a="OKD_$1_API_URL"
  if [ -n "${!c:-}" ]; then echo console; elif [ -n "${!a:-}" ]; then echo api; else echo none; fi; }
_okd_console() { local v="OKD_$1_CONSOLE_URL"; echo "${!v%/}"; }
_okd_api()     { local v="OKD_$1_API_URL";     echo "${!v%/}"; }
_okd_jar()     { echo "$HOME/.config/claude-creds/okd-cookie-$1"; }
_okd_tokf()    { echo "$HOME/.config/claude-creds/okd-token-$1"; }

# --- console (OKD4): login OAuth (authorization-code) via desafio basic-auth do SSO ---
_okd_login_console() {
  local env="$1" base jar tmp au cb; base="$(_okd_console "$env")"; jar="$(_okd_jar "$env")"; tmp="$(mktemp)"
  au=$(curl -sk -c "$tmp" -o /dev/null -w '%{redirect_url}' --max-time 12 "$base/auth/login")
  cb=$(curl -sk -c "$tmp" -b "$tmp" -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" -H 'X-CSRF-Token: 1' \
       -o /dev/null -w '%{redirect_url}' --max-time 15 "$au")
  echo "$cb" | grep -q 'callback' || { rm -f "$tmp"; return 1; }
  curl -sk -c "$tmp" -b "$tmp" -o /dev/null --max-time 12 "$cb"
  install -m 600 "$tmp" "$jar"; rm -f "$tmp"
}
_okd_ensure_console() {
  local env="$1" base jar code; base="$(_okd_console "$env")"; jar="$(_okd_jar "$env")"
  if [ -f "$jar" ]; then
    code=$(curl -sk -b "$jar" -o /dev/null -w '%{http_code}' --max-time 10 "$base/api/kubernetes/version" 2>/dev/null)
    [ "$code" = 200 ] && return 0
  fi
  _okd_login_console "$env"
}

# --- api direta (OS 3.x): token via desafio SSO (response_type=token) ---
_okd_login_api() {
  local env="$1" base tf loc tok; base="$(_okd_api "$env")"; tf="$(_okd_tokf "$env")"
  loc=$(curl -sk -D - -o /dev/null --max-time 15 -u "$SSO_NEXXERA_LOGIN:$SSO_NEXXERA_PASS" -H 'X-CSRF-Token: 1' \
        "$base/oauth/authorize?client_id=openshift-challenging-client&response_type=token" 2>/dev/null \
        | grep -i '^location:' | head -1)
  tok=$(echo "$loc" | sed -n 's/.*access_token=\([^&]*\).*/\1/p')
  [ -n "$tok" ] || return 1
  printf '%s' "$tok" > "$tf"; chmod 600 "$tf"
}
_okd_ensure_api() {
  local env="$1" base tf code; base="$(_okd_api "$env")"; tf="$(_okd_tokf "$env")"
  if [ -f "$tf" ]; then
    code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 -H "Authorization: Bearer $(cat "$tf")" "$base/oapi/v1/users/~" 2>/dev/null)
    [ "$code" = 200 ] && return 0
  fi
  _okd_login_api "$env"
}

# Núcleo: chama a API do k8s/OpenShift de um cluster, resolvendo a auth sozinho.
# Uso: okd_k8s <ENV> <k8s-path> [args extra do curl]   (path SEM barra inicial)
okd_k8s() {
  local env="$1" path="$2"; shift 2
  case "$(okd_kind "$env")" in
    console) _okd_ensure_console "$env" || { echo "❌ login console falhou ($env)" >&2; return 1; }
      curl -sk -b "$(_okd_jar "$env")" --max-time 30 "$@" "$(_okd_console "$env")/api/kubernetes/$path" ;;
    api)     _okd_ensure_api "$env" || { echo "❌ login api falhou ($env)" >&2; return 1; }
      curl -sk -H "Authorization: Bearer $(cat "$(_okd_tokf "$env")")" --max-time 30 "$@" "$(_okd_api "$env")/$path" ;;
    *) echo "❌ $env não definido (OKD_${env}_CONSOLE_URL ou OKD_${env}_API_URL)" >&2; return 1 ;;
  esac
}

# Status HTTP do cluster (após auth). Uso: okd_status <ENV>
okd_status() {
  case "$(okd_kind "$1")" in
    console) okd_k8s "$1" "version" -o /dev/null -w '%{http_code}' ;;
    api)     okd_k8s "$1" "oapi/v1/users/~" -o /dev/null -w '%{http_code}' ;;
    *) echo "000" ;;
  esac
}

# Logs de um pod. Uso: okd_logs <ENV> <ns> <pod> [tailLines=50] [container]
okd_logs() {
  local env="$1" ns="$2" pod="$3" tail="${4:-50}" cont="${5:-}"
  local q="tailLines=$tail"; [ -n "$cont" ] && q="$q&container=$cont"
  okd_k8s "$env" "api/v1/namespaces/$ns/pods/$pod/log?$q"
}
