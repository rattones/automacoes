#!/bin/bash

#########################################
# Módulo: Setup GitHub Tools
# Instalação opcional de GitHub CLI e Copilot CLI
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

# Instalar GitHub CLI (gh) - Opcional
echo ""
read -p "Deseja instalar o GitHub CLI (gh)? Permite gerenciar repos, PRs, issues via terminal. (s/N): " resposta_gh
echo ""

if [[ "$resposta_gh" =~ ^[Ss]$ ]]; then
    log "Instalando GitHub CLI (gh)..."
    
    # Adicionar repositório oficial do GitHub CLI
    if ! command -v gh &> /dev/null; then
        sudo mkdir -p /etc/apt/keyrings
        
        if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null; then
            sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            
            if sudo apt update && sudo apt install -y gh; then
                log_sucesso "GitHub CLI instalado com sucesso"
                log "Para autenticar: gh auth login"
            else
                log_erro "Falha ao instalar GitHub CLI"
            fi
        else
            log_erro "Falha ao adicionar repositório do GitHub CLI"
        fi
    else
        log_sucesso "GitHub CLI já está instalado: $(gh --version | head -1)"
    fi
else
    log_aviso "Instalação do GitHub CLI ignorada"
fi

# Instalar GitHub Copilot CLI - Opcional
echo ""
read -p "Deseja instalar o GitHub Copilot CLI? Requer GitHub Copilot ativo. (s/N): " resposta_copilot
echo ""

if [[ "$resposta_copilot" =~ ^[Ss]$ ]]; then
    log "Instalando GitHub Copilot CLI..."
    
    # Verificar se gh está instalado
    if ! command -v gh &> /dev/null; then
        log_erro "GitHub CLI (gh) não está instalado. É necessário para o Copilot CLI."
        log "Execute novamente e instale o GitHub CLI primeiro."
    else
        # Instalar extensão do Copilot
        if gh extension install github/gh-copilot; then
            log_sucesso "GitHub Copilot CLI instalado com sucesso"
            log "Comandos disponíveis:"
            log "  gh copilot suggest - Sugestões de comandos"
            log "  gh copilot explain - Explicar comandos"
        else
            log_aviso "Falha ao instalar GitHub Copilot CLI"
            log "Você pode tentar instalar manualmente: gh extension install github/gh-copilot"
        fi
    fi
else
    log_aviso "Instalação do GitHub Copilot CLI ignorada"
fi

exit 0
