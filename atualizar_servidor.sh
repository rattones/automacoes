#!/bin/bash

#########################################
# Script Orquestrador de Atualização do Servidor
# Coordena a execução de módulos de atualização
#########################################

# Diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Configurações
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/atualizacao_$(date +%Y%m%d_%H%M%S).log"
EMAIL_DESTINO=""  # Adicione um email se quiser notificações

# Containers a serem atualizados (nome e diretório)
declare -a CONTAINERS=(
    # "Nome do Container" "/caminho/para/o/container"
    "Crafty" "/home/rattones/crafty"
    "Home Assistant" "/home/rattones/haos"
)

# Carregar bibliotecas
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/atualizar_sistema.sh"
source "$LIB_DIR/atualizar_container.sh"
source "$LIB_DIR/atualizar_nodejs.sh"
source "$LIB_DIR/verificar_sistema.sh"

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Este script precisa ser executado como root (use sudo)"
    exit 1
fi

# Inicializar sistema de logs
inicializar_log "$LOG_DIR" "$LOG_FILE"

# Início do processo
log_separador
log "INICIANDO PROCESSO DE ATUALIZAÇÃO DO SERVIDOR"
log_separador

# Registrar informações do sistema
registrar_info_sistema

# 1. Atualizar sistema operacional
if ! atualizar_sistema_completo; then
    log_erro "Falha crítica na atualização do sistema"
    exit 1
fi

# 2. Atualizar containers Docker
if [ ${#CONTAINERS[@]} -gt 0 ]; then
    log_separador
    log "Iniciando atualização de containers Docker"
    log_separador
    atualizar_containers "${CONTAINERS[@]}"
else
    log_aviso "Nenhum container configurado para atualização"
fi

# 3. Atualizar Node.js, NVM e npm
atualizar_nodejs_completo

# 4. Verificar necessidade de reinicialização
verificar_necessidade_reinicializacao

# 5. Mostrar estatísticas finais
mostrar_estatisticas

# 6. Finalização
log_separador
log "ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!"
log "Log completo salvo em: $LOG_FILE"
log_separador

# 7. Enviar notificação por email (se configurado)
if [ -n "$EMAIL_DESTINO" ]; then
    enviar_notificacao_email "$EMAIL_DESTINO" "Atualização do Servidor - $(hostname)" "$LOG_FILE"
fi

exit 0
