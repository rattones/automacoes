#!/bin/bash

#########################################
# Módulo: Setup Docker
# Instalação e configuração do Docker
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Instalando Docker..."

# Remover versões antigas do Docker
log "Removendo versões antigas do Docker..."
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Verificar e limpar configurações antigas/duplicadas do Docker
log_separador
log "Verificando configurações existentes do Docker..."
log_separador

DUPLICATAS_ENCONTRADAS=0

# Verificar arquivos de configuração de repositório
if [ -f /etc/apt/sources.list.d/docker.sources ]; then
    log_aviso "Encontrada configuração duplicada: docker.sources"
    
    # Criar backup antes de remover
    BACKUP_DIR="/tmp/docker-cleanup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    sudo cp /etc/apt/sources.list.d/docker.sources "$BACKUP_DIR/"
    
    log "Removendo docker.sources..."
    sudo rm /etc/apt/sources.list.d/docker.sources
    log_sucesso "Removido: docker.sources (backup em $BACKUP_DIR)"
    DUPLICATAS_ENCONTRADAS=1
fi

# Verificar chaves GPG duplicadas
if [ -f /etc/apt/keyrings/docker.asc ]; then
    log_aviso "Encontrada chave GPG duplicada: docker.asc"
    
    # Criar backup se ainda não existe
    if [ ! -d "$BACKUP_DIR" ]; then
        BACKUP_DIR="/tmp/docker-cleanup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
    fi
    
    sudo cp /etc/apt/keyrings/docker.asc "$BACKUP_DIR/"
    
    log "Removendo docker.asc..."
    sudo rm /etc/apt/keyrings/docker.asc
    log_sucesso "Removido: docker.asc (backup em $BACKUP_DIR)"
    DUPLICATAS_ENCONTRADAS=1
fi

# Verificar outros possíveis conflitos
if [ -f /etc/apt/sources.list.d/docker.list.save ] || [ -f /etc/apt/sources.list.d/docker.list.distUpgrade ]; then
    log_aviso "Encontrados arquivos de backup antigos"
    sudo rm -f /etc/apt/sources.list.d/docker.list.save
    sudo rm -f /etc/apt/sources.list.d/docker.list.distUpgrade
    log_sucesso "Arquivos de backup limpos"
fi

if [ $DUPLICATAS_ENCONTRADAS -eq 1 ]; then
    log_separador
    log_sucesso "Limpeza de duplicatas concluída"
    log_separador
else
    log "Nenhuma configuração duplicada encontrada"
fi

echo ""

# Instalar dependências
log "Instalando dependências..."
sudo apt install -y ca-certificates gnupg lsb-release

# Adicionar chave GPG oficial do Docker
log "Adicionando chave GPG do Docker..."
sudo mkdir -p /etc/apt/keyrings

# Remover chave antiga se existir para garantir atualização
if [ -f /etc/apt/keyrings/docker.gpg ]; then
    log "Atualizando chave GPG existente..."
    sudo rm /etc/apt/keyrings/docker.gpg
fi

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
log_sucesso "Chave GPG configurada"

# Configurar repositório
log "Configurando repositório do Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
log_sucesso "Repositório configurado"

# Atualizar lista de pacotes
log "Atualizando lista de pacotes..."
if sudo apt update; then
    log_sucesso "Lista de pacotes atualizada"
else
    log_erro "Falha ao atualizar lista de pacotes"
    log "Execute 'sudo ./diagnostico_apt.sh' para diagnóstico"
    exit 1
fi

# Instalar Docker
log "Instalando Docker e componentes..."
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

exit 0
