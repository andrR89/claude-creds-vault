#!/usr/bin/env bash
# Wrapper de conveniência: garante a sessão SSO e consulta o Elasticsearch.
# Uso: ./es.sh '<path-ES>'
#   ./es.sh 'project.cadun-dev.*/_search?size=5&sort=@timestamp:desc'
#   ./es.sh '_cat/indices'        (pode dar 403 — APIs de cluster são restritas)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
[ $# -ge 1 ] || { echo "uso: $0 '<path-ES>'" >&2; exit 2; }
kibana_ensure >/dev/null || { echo "❌ login SSO falhou" >&2; exit 1; }
kibana_es "$1"
