#!/bin/bash

#########################################
# Atualização de Node.js, NVM e npm
#########################################

# Verificar se NVM está instalado
verificar_nvm_instalado() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if command -v nvm &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Atualizar NVM
atualizar_nvm() {
    export NVM_DIR="$HOME/.nvm"
    
    if [ ! -d "$NVM_DIR" ]; then
        log_aviso "NVM não está instalado"
        return 1
    fi
    
    log "Atualizando NVM..."
    
    # Carregar NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    local versao_atual=$(nvm --version 2>/dev/null)
    log "Versão atual do NVM: $versao_atual"
    
    # Atualizar NVM via git
    cd "$NVM_DIR" || return 1
    
    if git fetch --tags origin >> "$LOG_FILE" 2>&1; then
        local latest_tag=$(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
        
        if git checkout "$latest_tag" >> "$LOG_FILE" 2>&1; then
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            log_sucesso "NVM atualizado para versão: $(nvm --version)"
            cd - > /dev/null
            return 0
        else
            log_erro "Falha ao atualizar NVM"
            cd - > /dev/null
            return 1
        fi
    else
        log_aviso "Falha ao buscar atualizações do NVM"
        cd - > /dev/null
        return 1
    fi
}

# Atualizar Node.js para versão LTS
atualizar_nodejs() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command -v nvm &> /dev/null; then
        log_erro "NVM não está disponível"
        return 1
    fi
    
    log "Verificando versão atual do Node.js..."
    
    if command -v node &> /dev/null; then
        log "Versão atual: $(node --version)"
    else
        log "Node.js não está instalado"
    fi
    
    log "Instalando/atualizando para versão LTS..."
    
    if nvm install --lts >> "$LOG_FILE" 2>&1; then
        nvm use --lts >> "$LOG_FILE" 2>&1
        nvm alias default 'lts/*' >> "$LOG_FILE" 2>&1
        log_sucesso "Node.js atualizado: $(node --version)"
        return 0
    else
        log_erro "Falha ao atualizar Node.js"
        return 1
    fi
}

# Atualizar npm
atualizar_npm() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command -v npm &> /dev/null; then
        log_erro "npm não está disponível"
        return 1
    fi
    
    local versao_atual=$(npm --version)
    log "Versão atual do npm: $versao_atual"
    log "Atualizando npm para versão mais recente..."
    
    if npm install -g npm@latest >> "$LOG_FILE" 2>&1; then
        log_sucesso "npm atualizado: $(npm --version)"
        return 0
    else
        log_erro "Falha ao atualizar npm"
        return 1
    fi
}

# Limpar versões antigas do Node.js
limpar_versoes_antigas_nodejs() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command -v nvm &> /dev/null; then
        return 1
    fi
    
    log "Procurando versões antigas do Node.js..."
    
    local versao_atual=$(nvm current)
    local versoes_antigas=$(nvm ls | grep -v "$versao_atual" | grep -E "v[0-9]" | awk '{print $1}' | sed 's/->/ /g' | tr -d '*' | xargs)
    
    if [ -z "$versoes_antigas" ]; then
        log "Nenhuma versão antiga encontrada"
        return 0
    fi
    
    log "Versões antigas encontradas. Removendo..."
    local removidas=0
    
    for versao in $versoes_antigas; do
        if nvm uninstall "$versao" >> "$LOG_FILE" 2>&1; then
            log "  ✓ Removida: $versao"
            removidas=$((removidas + 1))
        fi
    done
    
    if [ $removidas -gt 0 ]; then
        log_sucesso "$removidas versão(ões) antiga(s) removida(s)"
    fi
    
    return 0
}

# Atualizar ecossistema Node.js completo
atualizar_nodejs_completo() {
    log_separador
    log "Iniciando atualização do Node.js"
    log_separador
    
    # Verificar se NVM está instalado
    if ! verificar_nvm_instalado; then
        log_aviso "NVM não está instalado. Pulando atualização do Node.js"
        log "Execute o post-install.sh para instalar NVM e Node.js"
        return 0
    fi
    
    # Atualizar NVM
    atualizar_nvm
    
    # Atualizar Node.js
    if atualizar_nodejs; then
        # Atualizar npm
        atualizar_npm
        
        # Limpar versões antigas
        limpar_versoes_antigas_nodejs
        
        log_sucesso "Atualização do Node.js concluída"
        return 0
    else
        log_aviso "Atualização do Node.js não foi completamente bem-sucedida"
        return 1
    fi
}
