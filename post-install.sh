#!/bin/bash

#########################################
# Script de Post-Instalação do Servidor
# Configuração inicial completa do ambiente
#########################################

# Diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores para output
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para logging
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
log "INICIANDO POST-INSTALAÇÃO DO SERVIDOR"
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

# 2. Instalar pacotes essenciais
log_separador
log "Instalando pacotes essenciais (curl, git, sqlite3, zsh)..."
log_separador

if sudo apt install -y curl git sqlite3 zsh; then
    log_sucesso "Pacotes essenciais instalados"
else
    log_erro "Falha ao instalar pacotes essenciais"
    exit 1
fi

# 2a. Instalar e configurar Zsh com Powerlevel10k
log_separador
log "Configurando Zsh e Powerlevel10k..."
log_separador

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
if [ -f "$SCRIPT_DIR/backups/zsh/.zshrc" ]; then
    log "Restaurando configuração do Zsh do backup..."
    cp "$SCRIPT_DIR/backups/zsh/.zshrc" "$HOME/.zshrc"
    log_sucesso "Arquivo .zshrc restaurado"
else
    log_aviso "Backup de .zshrc não encontrado"
    
    # Tentar baixar do GitHub
    log "Tentando baixar .zshrc do repositório..."
    if curl -fsSL https://raw.githubusercontent.com/rattones/automacoes/main/backups/zsh/.zshrc -o "$HOME/.zshrc" 2>/dev/null; then
        log_sucesso "Arquivo .zshrc baixado do GitHub"
    else
        log_aviso "Não foi possível baixar .zshrc do GitHub"
    fi
fi

# Restaurar configuração do Powerlevel10k do backup se existir
if [ -f "$SCRIPT_DIR/backups/zsh/.p10k.zsh" ]; then
    log "Restaurando configuração do Powerlevel10k do backup..."
    cp "$SCRIPT_DIR/backups/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
    log_sucesso "Arquivo .p10k.zsh restaurado"
else
    log_aviso "Backup de .p10k.zsh não encontrado"
    
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

# 2b. Clonar repositório se ainda não existir
log_separador
log "Verificando repositório do projeto..."
log_separador

REPO_DIR="$HOME/projetos/automacoes"

if [ ! -d "$REPO_DIR/.git" ]; then
    log "Clonando repositório do GitHub..."
    mkdir -p "$HOME/projetos"
    
    if git clone https://github.com/rattones/automacoes.git "$REPO_DIR"; then
        log_sucesso "Repositório clonado em $REPO_DIR"
        
        # Atualizar SCRIPT_DIR para usar o repositório clonado
        SCRIPT_DIR="$REPO_DIR"
        log_sucesso "Usando arquivos do repositório clonado"
    else
        log_aviso "Falha ao clonar repositório (não é crítico)"
        log "Continuando com download direto dos arquivos..."
    fi
else
    log_sucesso "Repositório já existe em $REPO_DIR"
    
    # Se já existe, fazer pull para atualizar
    cd "$REPO_DIR"
    if git pull origin main 2>/dev/null; then
        log_sucesso "Repositório atualizado"
        SCRIPT_DIR="$REPO_DIR"
    fi
fi

# 3. Instalar Cockpit (Web Console da Red Hat)
log_separador
log "Instalando Cockpit Web Console..."
log_separador

if sudo apt install -y cockpit cockpit-dashboard cockpit-podman cockpit-machines cockpit-networkmanager cockpit-packagekit cockpit-storaged; then
    log_sucesso "Cockpit instalado com sucesso"
    
    # Habilitar e iniciar o serviço
    sudo systemctl enable --now cockpit.socket
    log_sucesso "Cockpit habilitado e iniciado"
    log "Acesse o Cockpit em: https://$(hostname -I | awk '{print $1}'):9090"
else
    log_aviso "Falha ao instalar Cockpit (não é crítico)"
fi

# 4. Instalar Docker
log_separador
log "Instalando Docker..."
log_separador

# Remover versões antigas
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Instalar dependências
sudo apt install -y ca-certificates gnupg lsb-release

# Adicionar chave GPG oficial do Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurar repositório
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
if sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    log_sucesso "Docker instalado com sucesso"
else
    log_erro "Falha ao instalar Docker"
    exit 1
fi

# Configurar Docker para rodar sem sudo
log "Configurando Docker para rodar sem sudo..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER

log_sucesso "Usuário $USER adicionado ao grupo docker"
log_aviso "IMPORTANTE: Você precisa fazer logout e login novamente para usar docker sem sudo"
log_aviso "Ou execute: newgrp docker"

# Habilitar Docker na inicialização
sudo systemctl enable docker
log_sucesso "Docker configurado para iniciar automaticamente"

# 5. Instalar Node.js (versão stable)
log_separador
log "Instalando Node.js (versão stable)..."
log_separador

# Instalar NVM (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Carregar NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Instalar versão LTS do Node.js
if nvm install --lts; then
    nvm use --lts
    nvm alias default 'lts/*'
    log_sucesso "Node.js instalado: $(node --version)"
    log_sucesso "NPM instalado: $(npm --version)"
else
    log_aviso "Falha ao instalar Node.js via NVM (não é crítico)"
fi

# 6. Criar pastas e copiar arquivos compose.yml
log_separador
log "Criando estrutura de diretórios..."
log_separador

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
if [ -f "$SCRIPT_DIR/backups/haos/compose.yml" ]; then
    cp "$SCRIPT_DIR/backups/haos/compose.yml" "$HOME/haos/compose.yml"
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
if [ -f "$SCRIPT_DIR/backups/crafty/compose.yml" ]; then
    cp "$SCRIPT_DIR/backups/crafty/compose.yml" "$HOME/crafty/compose.yml"
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

# 7. Iniciar containers (após adicionar usuário ao grupo docker)
log_separador
log "Preparando para iniciar containers..."
log_separador

log_aviso "Aplicando permissões do grupo docker..."
newgrp docker <<EONG

# Iniciar container do Home Assistant
log_separador
log "Iniciando container do Home Assistant..."
log_separador

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
log_separador
log "Iniciando container do Crafty..."
log_separador

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

# 8. Criar pasta projetos e restaurar backup
log_separador
log "Configurando pasta de projetos..."
log_separador

if [ ! -d "$HOME/projetos" ]; then
    mkdir -p "$HOME/projetos"
    log_sucesso "Pasta $HOME/projetos criada"
else
    log_aviso "Pasta $HOME/projetos já existe"
fi

# Verificar se existe backup para restaurar
if [ -d "$SCRIPT_DIR/backups/projetos" ]; then
    BACKUP_FILES=$(find "$SCRIPT_DIR/backups/projetos" -name "*.zip" 2>/dev/null)
    
    if [ -n "$BACKUP_FILES" ]; then
        log "Backups encontrados:"
        echo "$BACKUP_FILES"
        
        for backup in $BACKUP_FILES; do
            log "Restaurando: $backup"
            if unzip -o "$backup" -d "$HOME/projetos/"; then
                log_sucesso "Backup restaurado: $(basename $backup)"
            else
                log_erro "Falha ao restaurar: $(basename $backup)"
            fi
        done
    else
        log_aviso "Nenhum backup (.zip) encontrado em $SCRIPT_DIR/backups/projetos"
    fi
else
    log_aviso "Pasta de backups de projetos não encontrada"
fi

# 9. Resumo final
log_separador
log "RESUMO DA INSTALAÇÃO"
log_separador

echo ""
log_sucesso "✓ Sistema atualizado"
log_sucesso "✓ Pacotes essenciais instalados (curl, git, sqlite3)"
log_sucesso "✓ Cockpit Web Console instalado"
log_sucesso "✓ Docker instalado e configurado"
log_sucesso "✓ Node.js instalado"
log_sucesso "✓ Estrutura de diretórios criada"
log_sucesso "✓ Containers configurados"
log_sucesso "✓ Pasta de projetos preparada"
echo ""

log_separador
log "INFORMAÇÕES IMPORTANTES"
log_separador

echo ""
log "📌 Cockpit Web Console: https://$(hostname -I | awk '{print $1}'):9090"
log "📌 Home Assistant: Verifique as portas configuradas no compose.yml"
log "📌 Crafty Controller: http://$(hostname -I | awk '{print $1}'):8000"
echo ""

log_separador
log "PRÓXIMOS PASSOS"
log_separador

echo ""
log "1. Faça LOGOUT e LOGIN novamente para usar docker sem sudo"
log "2. Ou execute: newgrp docker (temporário para esta sessão)"
log "3. Verifique os containers: docker ps"
log "4. Configure o sistema de automação se necessário"
echo ""

log_separador
log "POST-INSTALAÇÃO CONCLUÍDA!"
log_separador

exit 0
