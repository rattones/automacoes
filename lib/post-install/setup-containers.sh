#!/bin/bash

#########################################
# Módulo: Setup Containers
# Configuração e deploy dos containers (Crafty, HAOS)
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"
BACKUP_DIR="$REPO_DIR/backups"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Criando estrutura de diretórios para containers..."

# Criar pasta do Home Assistant
if [ ! -d "$HOME/haos" ]; then
    mkdir -p "$HOME/haos"
    log_sucesso "Pasta $HOME/haos criada"
else
    log_aviso "Pasta $HOME/haos já existe"
fi

# Criar pasta do Crafty
if [ ! -d "$HOME/crafty" ]; then
    mkdir -p "$HOME/crafty"
    log_sucesso "Pasta $HOME/crafty criada"
else
    log_aviso "Pasta $HOME/crafty já existe"
fi

# Copiar compose.yml do HAOS
if [ -f "$BACKUP_DIR/haos/compose.yml" ]; then
    cp "$BACKUP_DIR/haos/compose.yml" "$HOME/haos/compose.yml"
    log_sucesso "Arquivo compose.yml copiado para $HOME/haos"
else
    log_aviso "Arquivo de backup compose.yml do HAOS não encontrado localmente"
    log "Tentando baixar do repositório GitHub..."
    
    if curl -fsSL https://raw.githubusercontent.com/rattones/automacoes/main/backups/haos/compose.yml -o "$HOME/haos/compose.yml"; then
        log_sucesso "Arquivo compose.yml do HAOS baixado do GitHub"
    else
        log_erro "Falha ao baixar compose.yml do HAOS"
    fi
fi

# Copiar compose.yml do Crafty
if [ -f "$BACKUP_DIR/crafty/compose.yml" ]; then
    cp "$BACKUP_DIR/crafty/compose.yml" "$HOME/crafty/compose.yml"
    log_sucesso "Arquivo compose.yml copiado para $HOME/crafty"
else
    log_aviso "Arquivo de backup compose.yml do Crafty não encontrado localmente"
    log "Tentando baixar do repositório GitHub..."
    
    if curl -fsSL https://raw.githubusercontent.com/rattones/automacoes/main/backups/crafty/compose.yml -o "$HOME/crafty/compose.yml"; then
        log_sucesso "Arquivo compose.yml do Crafty baixado do GitHub"
    else
        log_erro "Falha ao baixar compose.yml do Crafty"
    fi
fi

# Iniciar containers (após adicionar usuário ao grupo docker)
log "Preparando para iniciar containers..."

log_aviso "Aplicando permissões do grupo docker..."
newgrp docker <<EONG

# Iniciar container do Home Assistant
log "Iniciando container do Home Assistant..."

if [ -f "$HOME/haos/compose.yml" ]; then
    cd "$HOME/haos"
    if docker compose pull && docker compose up -d; then
        log_sucesso "Container do Home Assistant iniciado"
        docker compose ps
    else
        log_erro "Falha ao iniciar container do Home Assistant"
    fi
else
    log_erro "Arquivo compose.yml do HAOS não encontrado"
fi

# Iniciar container do Crafty
log "Iniciando container do Crafty..."

if [ -f "$HOME/crafty/compose.yml" ]; then
    cd "$HOME/crafty"
    if docker compose pull && docker compose up -d; then
        log_sucesso "Container do Crafty iniciado"
        docker compose ps
    else
        log_erro "Falha ao iniciar container do Crafty"
    fi
else
    log_erro "Arquivo compose.yml do Crafty não encontrado"
fi

EONG

exit 0
