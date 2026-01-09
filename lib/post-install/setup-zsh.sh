#!/bin/bash

#########################################
# Módulo: Setup Zsh + Powerlevel10k
# Instalação e configuração do Zsh com tema Powerlevel10k
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"
BACKUP_DIR="$REPO_DIR/backups"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Configurando Zsh e Powerlevel10k..."

# Instalar Oh My Zsh se ainda não estiver instalado
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Instalando Oh My Zsh..."
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        log_sucesso "Oh My Zsh instalado"
    else
        log_aviso "Falha ao instalar Oh My Zsh (não é crítico)"
    fi
else
    log_sucesso "Oh My Zsh já está instalado"
fi

# Instalar Powerlevel10k
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    log "Instalando tema Powerlevel10k..."
    if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k; then
        log_sucesso "Powerlevel10k instalado"
    else
        log_aviso "Falha ao instalar Powerlevel10k (não é crítico)"
    fi
else
    log_sucesso "Powerlevel10k já está instalado"
fi

# Restaurar configurações do Zsh do backup se existirem
if [ -f "$BACKUP_DIR/zsh/.zshrc" ]; then
    log "Restaurando configuração do Zsh do backup..."
    cp "$BACKUP_DIR/zsh/.zshrc" "$HOME/.zshrc"
    log_sucesso "Arquivo .zshrc restaurado"
else
    log_aviso "Backup de .zshrc não encontrado localmente"
    
    # Tentar baixar do GitHub
    log "Tentando baixar .zshrc do repositório..."
    if curl -fsSL https://raw.githubusercontent.com/rattones/automacoes/main/backups/zsh/.zshrc -o "$HOME/.zshrc" 2>/dev/null; then
        log_sucesso "Arquivo .zshrc baixado do GitHub"
    else
        log_aviso "Não foi possível baixar .zshrc do GitHub"
    fi
fi

# Restaurar configuração do Powerlevel10k do backup se existir
if [ -f "$BACKUP_DIR/zsh/.p10k.zsh" ]; then
    log "Restaurando configuração do Powerlevel10k do backup..."
    cp "$BACKUP_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
    log_sucesso "Arquivo .p10k.zsh restaurado"
else
    log_aviso "Backup de .p10k.zsh não encontrado localmente"
    
    # Tentar baixar do GitHub
    log "Tentando baixar .p10k.zsh do repositório..."
    if curl -fsSL https://raw.githubusercontent.com/rattones/automacoes/main/backups/zsh/.p10k.zsh -o "$HOME/.p10k.zsh" 2>/dev/null; then
        log_sucesso "Arquivo .p10k.zsh baixado do GitHub"
    else
        log_aviso "Não foi possível baixar .p10k.zsh do GitHub"
    fi
fi

# Configurar Zsh como shell padrão
if [ "$SHELL" != "$(which zsh)" ]; then
    log "Configurando Zsh como shell padrão..."
    if sudo chsh -s $(which zsh) $USER; then
        log_sucesso "Zsh configurado como shell padrão"
        log_aviso "Faça logout e login novamente para usar o Zsh"
    else
        log_aviso "Não foi possível configurar Zsh como shell padrão"
        log "Execute manualmente: chsh -s $(which zsh)"
    fi
else
    log_sucesso "Zsh já é o shell padrão"
fi

exit 0
