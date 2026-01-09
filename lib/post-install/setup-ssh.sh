#!/bin/bash

#########################################
# Módulo: Setup SSH Server
# Instalação e configuração do OpenSSH Server
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Instalando pacotes: sqlite3, zsh, openssh-server..."

if sudo apt install -y sqlite3 zsh openssh-server; then
    log_sucesso "Pacotes instalados"
else
    log_erro "Falha ao instalar pacotes"
    exit 1
fi

# Configurar SSH Server
log "Configurando SSH Server para acesso remoto..."

if command -v sshd &> /dev/null; then
    # Habilitar e iniciar o serviço SSH
    if sudo systemctl enable ssh && sudo systemctl start ssh; then
        log_sucesso "SSH Server habilitado e iniciado"
        
        # Verificar status
        if sudo systemctl is-active --quiet ssh; then
            log_sucesso "SSH Server está rodando"
            
            # Mostrar informações de conexão
            IP_LOCAL=$(hostname -I | awk '{print $1}')
            log "Informações de acesso remoto:"
            log "  Usuário: $USER"
            log "  IP local: $IP_LOCAL"
            log "  Porta: 22 (padrão)"
            log ""
            log "Para conectar de outro computador:"
            log "  ssh $USER@$IP_LOCAL"
        else
            log_aviso "SSH Server instalado mas não está rodando"
        fi
    else
        log_erro "Falha ao habilitar SSH Server"
        exit 1
    fi
else
    log_erro "SSH Server não foi instalado corretamente"
    exit 1
fi

exit 0
