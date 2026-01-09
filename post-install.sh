#!/bin/bash

#########################################
# Script de Bootstrap - Post-Instalação
# Instala dependências mínimas e clona repositório
#########################################

# Cores para output
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

# Funções de logging simplificadas
log() {
    echo -e "${AZUL}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_erro() {
    echo -e "${VERMELHO}[ERRO][$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_sucesso() {
    echo -e "${VERDE}[SUCESSO][$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_aviso() {
    echo -e "${AMARELO}[AVISO][$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_separador() {
    echo "=========================================="
}

# Verificar se está rodando como usuário normal (não root)
if [ "$EUID" -eq 0 ]; then 
    log_erro "Este script NÃO deve ser executado como root"
    log "Execute como usuário normal. O script pedirá senha quando necessário."
    exit 1
fi

log_separador
log "BOOTSTRAP - POST-INSTALAÇÃO DO SERVIDOR"
log_separador


# 1. Atualizar o sistema
log_separador
log "Atualizando o sistema operacional..."
log_separador

if sudo apt update && sudo apt upgrade -y; then
    log_sucesso "Sistema atualizado com sucesso"
else
    log_erro "Falha ao atualizar o sistema"
    exit 1
fi

# 2. Instalar pacotes essenciais mínimos
log_separador
log "Instalando pacotes essenciais (curl, git)..."
log_separador

if sudo apt install -y curl git; then
    log_sucesso "Pacotes essenciais instalados"
else
    log_erro "Falha ao instalar pacotes essenciais"
    exit 1
fi

# 3. Clonar repositório de automações
log_separador
log "Clonando repositório de automações..."
log_separador

REPO_DIR="$HOME/projetos/automacoes"

if [ -d "$REPO_DIR/.git" ]; then
    log_aviso "Repositório já existe em $REPO_DIR"
    log "Atualizando repositório..."
    
    cd "$REPO_DIR"
    if git pull origin main; then
        log_sucesso "Repositório atualizado"
    else
        log_aviso "Falha ao atualizar repositório (continuando...)"
    fi
else
    log "Clonando de https://github.com/rattones/automacoes.git"
    mkdir -p "$HOME/projetos"
    
    if git clone https://github.com/rattones/automacoes.git "$REPO_DIR"; then
        log_sucesso "Repositório clonado em $REPO_DIR"
    else
        log_erro "Falha ao clonar repositório"
        exit 1
    fi
fi

# 4. Executar instalação principal do repositório
log_separador
log "Iniciando instalação completa..."
log_separador

MAIN_INSTALL="$REPO_DIR/lib/post-install/main-install.sh"

if [ -f "$MAIN_INSTALL" ]; then
    log "Executando: $MAIN_INSTALL"
    echo ""
    
    # Executar script principal
    bash "$MAIN_INSTALL"
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        log_separador
        log_sucesso "INSTALAÇÃO COMPLETA CONCLUÍDA!"
        log_separador
    else
        log_separador
        log_erro "Instalação finalizada com erros (código: $EXIT_CODE)"
        log_separador
        exit $EXIT_CODE
    fi
else
    log_erro "Script principal não encontrado: $MAIN_INSTALL"
    log "Verifique se o repositório foi clonado corretamente"
    exit 1
fi

exit 0

