#!/usr/bin/env bash
# Wrapper de conveniência: consulta o Elasticsearch de um ambiente Kibana.
# Uso: ./es.sh <ENV> '<path-ES>'
#   ./es.sh DEV 'project.cadun-dev.*/_search?size=5&sort=@timestamp:desc'
#   ./es.sh PRD '_cat/indices'      (depende de permissão)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
[ $# -ge 2 ] || { echo "uso: $0 <ENV> '<path-ES>'   (ambientes: $(kibana_envs | tr '\n' ' '))" >&2; exit 2; }
kibana_curl "$1" "$2"
