#!/usr/bin/env bash
# Chama a API do k8s/OpenShift de um cluster (resolve a auth SSO sozinho).
# Uso: ./k8s.sh <ENV> '<k8s-path>'   (path SEM barra inicial)
#   ./k8s.sh PRD 'oapi/v1/projects'
#   ./k8s.sh INT 'api/v1/namespaces/portal-relacionamento-dev/pods'
# ⚠️ Só leitura por padrão. Para escrita (-X POST/DELETE/PATCH) confirme com o usuário.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
[ $# -ge 2 ] || { echo "uso: $0 <ENV> '<k8s-path>'   (clusters: $(okd_envs | tr '\n' ' '))" >&2; exit 2; }
env="$1"; shift
okd_k8s "$env" "$@"
