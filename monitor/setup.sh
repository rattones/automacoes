#!/bin/bash

#########################################
# Setup do Monitor Web do Servidor
# Atalho: delega para o módulo oficial de automação
#########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULO="$SCRIPT_DIR/../lib/post-install/setup-monitor.sh"

if [ ! -f "$MODULO" ]; then
    echo "ERRO: Módulo não encontrado: $MODULO"
    exit 1
fi

exec bash "$MODULO" "$@"
