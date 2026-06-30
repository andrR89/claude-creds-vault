#!/usr/bin/env bash
# Logs de um pod via OpenShift. Uso: ./logs.sh <ENV> <namespace> <pod> [tailLines=50] [container]
#   ./logs.sh INT <namespace> <pod> 50
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
[ $# -ge 3 ] || { echo "uso: $0 <ENV> <ns> <pod> [tailLines] [container]   (clusters: $(okd_envs | tr '\n' ' '))" >&2; exit 2; }
okd_logs "$@"
