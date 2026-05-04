#!/bin/bash

#########################################
# Ação em Container Docker
# Uso: container_action.sh <action> <container_name_or_id>
# Actions: start | stop | restart
# Saída: JSON
#########################################

set -euo pipefail

ACTION="${1:-}"
CONTAINER="${2:-}"

# ── VALIDAÇÃO ─────────────────────────────────────────────────────────────────
if [ -z "$ACTION" ] || [ -z "$CONTAINER" ]; then
    echo '{"success":false,"output":"","error":"Parâmetros obrigatórios: action e container"}'
    exit 1
fi

# Whitelist de ações permitidas
case "$ACTION" in
    start|stop|restart) ;;
    *)
        echo "{\"success\":false,\"output\":\"\",\"error\":\"Ação inválida: ${ACTION}. Use: start, stop, restart\"}"
        exit 1
        ;;
esac

# Validar nome do container: apenas caracteres seguros
if ! echo "$CONTAINER" | grep -qE '^[a-zA-Z0-9_.\-]+$'; then
    echo "{\"success\":false,\"output\":\"\",\"error\":\"Nome de container inválido: ${CONTAINER}\"}"
    exit 1
fi

# Verificar se docker está disponível
if ! command -v docker &>/dev/null; then
    echo '{"success":false,"output":"","error":"Docker não está disponível"}'
    exit 1
fi

# Verificar se o container existe
if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qF "$CONTAINER"; then
    # Tenta por ID
    if ! docker ps -a --format '{{.ID}}' 2>/dev/null | grep -qF "${CONTAINER:0:12}"; then
        echo "{\"success\":false,\"output\":\"\",\"error\":\"Container não encontrado: ${CONTAINER}\"}"
        exit 1
    fi
fi

# ── EXECUÇÃO ──────────────────────────────────────────────────────────────────
OUTPUT=$(docker "$ACTION" "$CONTAINER" 2>&1 || true)
EXIT_CODE=$?

# Estado após a ação
STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")

if [ $EXIT_CODE -eq 0 ]; then
    python3 -c "
import json
print(json.dumps({
    'success': True,
    'output': '''${OUTPUT}''',
    'error': '',
    'status_apos': '${STATUS}'
}))
"
else
    python3 -c "
import json
print(json.dumps({
    'success': False,
    'output': '',
    'error': '''${OUTPUT}''',
    'status_apos': '${STATUS}'
}))
"
fi
