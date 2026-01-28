#!/bin/bash

#########################################
# Backup de Configurações dos Containers
# Faz backup das configurações dos apps gerenciados
#########################################

# Função para fazer backup das configurações do Crafty
backup_crafty() {
    local crafty_dir="$1"
    local backup_dir="$SCRIPT_DIR/backups/crafty"

    log "Fazendo backup das configurações do Crafty..."

    # Verificar se o diretório existe
    if [ ! -d "$crafty_dir" ]; then
        log_aviso "Diretório do Crafty não encontrado: $crafty_dir"
        return 1
    fi

    # Criar diretório de backup se não existir
    mkdir -p "$backup_dir"

    # Backup da configuração
    if [ -d "$crafty_dir/docker/config" ]; then
        log "Copiando configurações do Crafty..."
        cp -r "$crafty_dir/docker/config"/* "$backup_dir/" 2>/dev/null || true
        log_sucesso "Configurações do Crafty backupadas"
    else
        log_aviso "Pasta de configuração do Crafty não encontrada"
    fi

    # Backup do compose.yml
    if [ -f "$crafty_dir/compose.yml" ]; then
        cp "$crafty_dir/compose.yml" "$backup_dir/"
        log_sucesso "Compose.yml do Crafty backupado"
    fi

    return 0
}

# Função para fazer backup das configurações do Home Assistant
backup_home_assistant() {
    local haos_dir="$1"
    local backup_dir="$SCRIPT_DIR/backups/haos"

    log "Fazendo backup das configurações do Home Assistant..."

    # Verificar se o diretório existe
    if [ ! -d "$haos_dir" ]; then
        log_aviso "Diretório do Home Assistant não encontrado: $haos_dir"
        return 1
    fi

    # Criar diretório de backup se não existir
    mkdir -p "$backup_dir"

    # Procurar pasta de configuração (pode estar montada externamente)
    local config_dirs=("$haos_dir/config" "/home/rattones/.homeassistant" "/config")

    for config_dir in "${config_dirs[@]}"; do
        if [ -d "$config_dir" ]; then
            log "Encontrada pasta de configuração: $config_dir"
            # Criar arquivo tar.gz da configuração
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local backup_file="$backup_dir/homeassistant_config_$timestamp.tar.gz"

            cd "$(dirname "$config_dir")"
            tar -czf "$backup_file" "$(basename "$config_dir")" 2>/dev/null

            if [ $? -eq 0 ]; then
                log_sucesso "Configuração do Home Assistant backupada: $backup_file"
            else
                log_erro "Falha ao criar backup da configuração do Home Assistant"
            fi
            cd - >/dev/null
            break
        fi
    done

    # Backup do compose.yml
    if [ -f "$haos_dir/compose.yml" ]; then
        cp "$haos_dir/compose.yml" "$backup_dir/"
        log_sucesso "Compose.yml do Home Assistant backupado"
    fi

    return 0
}

# Função para fazer backup de um container específico
backup_container_config() {
    local container_name="$1"
    local container_dir="$2"

    case "$container_name" in
        "Crafty")
            backup_crafty "$container_dir"
            ;;
        "Home Assistant")
            backup_home_assistant "$container_dir"
            ;;
        *)
            log_aviso "Container '$container_name' não possui backup de configuração definido"
            ;;
    esac

    return 0
}

# Função principal para backup de todas as configurações
backup_todas_configs() {
    log_separador
    log "INICIANDO BACKUP DAS CONFIGURAÇÕES DOS CONTAINERS"
    log_separador

    # Carregar configurações dos containers do script principal
    if [ -z "$CONTAINERS" ]; then
        log_erro "Array CONTAINERS não definido. Carregue o script principal primeiro."
        return 1
    fi

    local total_containers=$((${#CONTAINERS[@]} / 2))
    local success_count=0

    for ((i=0; i<${#CONTAINERS[@]}; i+=2)); do
        local name="${CONTAINERS[i]}"
        local dir="${CONTAINERS[i+1]}"

        log_separador
        log "Processando backup de: $name ($dir)"
        log_separador

        if backup_container_config "$name" "$dir"; then
            ((success_count++))
        fi
    done

    log_separador
    log "BACKUP CONCLUÍDO: $success_count/$total_containers containers processados com sucesso"
    log_separador

    return 0
}

# Função para listar backups existentes
listar_backups() {
    log "Backups de configuração existentes:"

    local backup_root="$SCRIPT_DIR/backups"

    for container_dir in "$backup_root"/*/; do
        if [ -d "$container_dir" ]; then
            local container_name=$(basename "$container_dir")
            echo ""
            echo "📁 $container_name:"
            ls -la "$container_dir" | grep -v "^total" | grep -v "^d"
        fi
    done
}

# Função para restaurar backup (template - seria implementado conforme necessidade)
restaurar_backup() {
    local container_name="$1"
    local backup_file="$2"

    log_aviso "Função de restauração ainda não implementada"
    log "Container: $container_name"
    log "Arquivo: $backup_file"

    return 1
}