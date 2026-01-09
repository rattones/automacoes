#!/bin/bash

#########################################
# Módulo: Setup Cockpit
# Instalação do Cockpit Web Console (Red Hat)
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Instalando Cockpit Web Console..."

if sudo apt install -y cockpit cockpit-dashboard cockpit-podman cockpit-machines cockpit-networkmanager cockpit-packagekit cockpit-storaged; then
    log_sucesso "Cockpit instalado com sucesso"
    
    # Habilitar e iniciar o serviço
    sudo systemctl enable --now cockpit.socket
    log_sucesso "Cockpit habilitado e iniciado"
    
    IP_LOCAL=$(hostname -I | awk '{print $1}')
    log "Acesse o Cockpit em: https://$IP_LOCAL:9090"
else
    log_aviso "Falha ao instalar Cockpit (não é crítico)"
fi

exit 0
