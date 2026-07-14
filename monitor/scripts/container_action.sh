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
# (lista é capturada antes do grep para evitar SIGPIPE no docker quando
# grep -q encontra o padrão e fecha o pipe cedo, o que com `pipefail` fazia
# o pipeline inteiro reportar falha mesmo com o container existente)
CONTAINER_NAMES=$(docker ps -a --format '{{.Names}}' 2>/dev/null)
if ! grep -qF "$CONTAINER" <<< "$CONTAINER_NAMES"; then
    # Tenta por ID
    CONTAINER_IDS=$(docker ps -a --format '{{.ID}}' 2>/dev/null)
    if ! grep -qF "${CONTAINER:0:12}" <<< "$CONTAINER_IDS"; then
        echo "{\"success\":false,\"output\":\"\",\"error\":\"Container não encontrado: ${CONTAINER}\"}"
        exit 1
    fi
fi

# ── EXECUÇÃO ──────────────────────────────────────────────────────────────────
# `set +e`/`set -e` em vez de `|| true`: preserva o EXIT_CODE real do docker
# (com `|| true` dentro da substituição, EXIT_CODE era sempre 0)
set +e
OUTPUT=$(docker "$ACTION" "$CONTAINER" 2>&1)
EXIT_CODE=$?
set -e

# Estado após a ação
STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")

if [ $EXIT_CODE -eq 0 ]; then
    SUCCESS=true
else
    SUCCESS=false
fi

# Saída/erro passados via env var (não interpolados no código Python) para
# evitar que aspas, barras invertidas etc. no output do docker quebrem o script
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
