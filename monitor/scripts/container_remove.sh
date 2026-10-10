#!/bin/bash

#########################################
# Remoção de Containers Docker
# Uso: container_remove.sh <remover_volumes: 0|1> <container> [container...]
# Os containers são removidos na ordem recebida (dependentes primeiro).
# Para na primeira falha, para não remover uma dependência cujo dependente
# continuou existindo.
# Saída: JSON
#########################################

set -euo pipefail

REMOVER_VOLUMES="${1:-}"
shift || true

# ── VALIDAÇÃO ─────────────────────────────────────────────────────────────────
if [ "$REMOVER_VOLUMES" != "0" ] && [ "$REMOVER_VOLUMES" != "1" ] || [ $# -eq 0 ]; then
    echo '{"success":false,"removidos":[],"error":"Uso: container_remove.sh <0|1> <container> [container...]"}'
    exit 1
fi

for CONTAINER in "$@"; do
    if ! echo "$CONTAINER" | grep -qE '^[a-zA-Z0-9_.\-]+$'; then
        echo "{\"success\":false,\"removidos\":[],\"error\":\"Nome de container inválido: ${CONTAINER}\"}"
        exit 1
    fi
done

if ! command -v docker &>/dev/null; then
    echo '{"success":false,"removidos":[],"error":"Docker não está disponível"}'
    exit 1
fi

# ── EXECUÇÃO ──────────────────────────────────────────────────────────────────
FLAGS=(-f)
[ "$REMOVER_VOLUMES" = "1" ] && FLAGS+=(-v)

REMOVIDOS=()
ERRO=""
for CONTAINER in "$@"; do
    # `docker rm -f` sai com 0 mesmo se o container não existe
    if ! docker inspect "$CONTAINER" &>/dev/null; then
        ERRO="Container não encontrado: ${CONTAINER}"
        break
    fi
    set +e
    OUTPUT=$(docker rm "${FLAGS[@]}" "$CONTAINER" 2>&1)
    EXIT_CODE=$?
    set -e
    if [ $EXIT_CODE -ne 0 ]; then
        ERRO="Falha ao remover ${CONTAINER}: ${OUTPUT}"
        break
    fi
    REMOVIDOS+=("$CONTAINER")
done

# Valores passados via env var para não quebrar o JSON com aspas/barras
ERRO="$ERRO" REMOVIDOS="${REMOVIDOS[*]:-}" python3 -c "
import json, os
erro = os.environ['ERRO']
print(json.dumps({
    'success': not erro,
    'removidos': os.environ['REMOVIDOS'].split(),
    'error': erro
}))
"
