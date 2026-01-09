#!/bin/bash

#########################################
# Biblioteca de Funções de Logging
#########################################

# Cores para output
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Função para logging de erros
log_erro() {
    echo -e "${VERMELHO}[ERRO][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Função para logging de sucesso
log_sucesso() {
    echo -e "${VERDE}[SUCESSO][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Função para logging de aviso
log_aviso() {
    echo -e "${AMARELO}[AVISO][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Função para logging de informação
log_info() {
    echo -e "${AZUL}[INFO][$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Função para separador visual
log_separador() {
    log "=========================================="
}

# Função para inicializar log
inicializar_log() {
    local log_dir="$1"
    local log_file="$2"
    
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        echo "Diretório de logs criado: $log_dir"
    fi
    
    LOG_FILE="$log_file"
}
