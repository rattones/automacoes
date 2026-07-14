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
# (lista é capturada antes do grep para evitar SIGPIPE no systemctl quando
# grep -q encontra o padrão e fecha o pipe cedo, o que com `pipefail` fazia
# o pipeline inteiro reportar falha mesmo com o serviço existente)
UNIT_LIST=$(systemctl list-unit-files --type=service 2>/dev/null)
if ! grep -qF "$SERVICE" <<< "$UNIT_LIST"; then
    echo "{\"success\":false,\"output\":\"\",\"error\":\"Serviço não encontrado: ${SERVICE}\"}"
    exit 1
fi

# ── EXECUÇÃO ──────────────────────────────────────────────────────────────────
# `set +e`/`set -e` em vez de `|| true`: preserva o EXIT_CODE real do systemctl
# (com `|| true` dentro da substituição, EXIT_CODE era sempre 0)
set +e
OUTPUT=$(systemctl "$ACTION" "$SERVICE" 2>&1)
EXIT_CODE=$?
set -e

# Pegar status após a ação
STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "unknown")

if [ $EXIT_CODE -eq 0 ]; then
    SUCCESS=true
else
    SUCCESS=false
fi

# Saída/erro passados via env var (não interpolados no código Python) para
# evitar que aspas, barras invertidas etc. no output do systemctl quebrem o script
SUCCESS="$SUCCESS" OUTPUT="$OUTPUT" STATUS="$STATUS" python3 -c "
import json, os
success = os.environ['SUCCESS'] == 'true'
output = os.environ['OUTPUT']
print(json.dumps({
    'success': success,
    'output': output if success else '',
    'error': '' if success else output,
    'status_apos': os.environ['STATUS']
}))
"
