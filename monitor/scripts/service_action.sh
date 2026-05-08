#!/bin/bash

#########################################
# Ação em Serviço systemd
# Uso: service_action.sh <action> <service>
# Actions: start | stop | restart | reload
# Saída: JSON
#########################################

set -euo pipefail

ACTION="${1:-}"
SERVICE="${2:-}"

# ── VALIDAÇÃO ─────────────────────────────────────────────────────────────────
if [ -z "$ACTION" ] || [ -z "$SERVICE" ]; then
    echo '{"success":false,"output":"","error":"Parâmetros obrigatórios: action e service"}'
    exit 1
fi

# Whitelist de ações permitidas
case "$ACTION" in
    start|stop|restart|reload) ;;
    *)
        echo "{\"success\":false,\"output\":\"\",\"error\":\"Ação inválida: ${ACTION}. Use: start, stop, restart, reload\"}"
        exit 1
        ;;
esac

# Validar nome do serviço: apenas caracteres seguros
if ! echo "$SERVICE" | grep -qE '^[a-zA-Z0-9_@.\-]+\.service$'; then
    echo "{\"success\":false,\"output\":\"\",\"error\":\"Nome de serviço inválido: ${SERVICE}\"}"
    exit 1
fi

# Verificar se o serviço existe no systemd
if ! systemctl list-unit-files --type=service 2>/dev/null | grep -qF "$SERVICE"; then
    echo "{\"success\":false,\"output\":\"\",\"error\":\"Serviço não encontrado: ${SERVICE}\"}"
    exit 1
fi

# ── EXECUÇÃO ──────────────────────────────────────────────────────────────────
OUTPUT=$(systemctl "$ACTION" "$SERVICE" 2>&1 || true)
EXIT_CODE=$?

# Pegar status após a ação
STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "unknown")

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
