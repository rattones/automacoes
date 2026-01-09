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

exit 0
