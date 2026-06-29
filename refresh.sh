#!/usr/bin/env bash
# Rotina de manutenção: re-busca os segredos do Bitwarden e re-injeta tudo.
# Rode SEMPRE que uma credencial mudar no Bitwarden (a rotação é central — sem git).
# O git pull aqui serve só para puxar CÓDIGO/serviços novos de outra máquina.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "⤓ git pull (pega código/serviços novos, NÃO segredos)…"
git -C "$HERE" pull --ff-only 2>/dev/null || echo "  (sem remote/ahead — seguindo só com o local)"
exec "$HERE/bootstrap.sh"   # re-busca do bws → settings.json + espelho runtime atualizados
