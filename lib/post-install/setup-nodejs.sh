#!/bin/bash

#########################################
# Módulo: Setup Node.js
# Instalação do Node.js via NVM
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Instalando Node.js (versão LTS)..."

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

exit 0
