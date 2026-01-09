#!/bin/bash

#########################################
# Módulo: Setup Projects
# Restauração de backups de projetos
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"
BACKUP_DIR="$REPO_DIR/backups"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log "Configurando pasta de projetos..."

if [ ! -d "$HOME/projetos" ]; then
    mkdir -p "$HOME/projetos"
    log_sucesso "Pasta $HOME/projetos criada"
else
    log_aviso "Pasta $HOME/projetos já existe"
fi

# Verificar se existe backup para restaurar
if [ -d "$BACKUP_DIR/projetos" ]; then
    BACKUP_FILES=$(find "$BACKUP_DIR/projetos" -name "*.zip" 2>/dev/null)
    
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
        log_aviso "Nenhum backup (.zip) encontrado em $BACKUP_DIR/projetos"
    fi
else
    log_aviso "Pasta de backups de projetos não encontrada"
fi

exit 0
