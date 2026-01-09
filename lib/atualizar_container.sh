#!/bin/bash

#########################################
# Atualização de Containers Docker
#########################################

# Atualizar um container Docker Compose específico
atualizar_container() {
    local nome="$1"
    local diretorio="$2"
    
    log_separador
    log "Atualizando container: $nome"
    log_separador
    
    # Verificar se o diretório existe
    if [ ! -d "$diretorio" ]; then
        log_erro "Diretório não encontrado: $diretorio"
        return 1
    fi
    
    # Verificar se o arquivo compose.yml existe
    if [ ! -f "$diretorio/compose.yml" ]; then
        log_erro "Arquivo compose.yml não encontrado em $diretorio"
        return 1
    fi
    
    # Verificar se docker está disponível
    if ! command -v docker &> /dev/null; then
        log_erro "Docker não está instalado ou não está no PATH"
        return 1
    fi
    
    # Salvar diretório atual
    local dir_original=$(pwd)
    
    # Entrar no diretório do container
    log "Acessando diretório: $diretorio"
    cd "$diretorio" || {
        log_erro "Não foi possível acessar o diretório $diretorio"
        return 1
    }
    
    # Fazer pull das imagens
    log "Baixando imagens atualizadas..."
    if docker compose pull >> "$LOG_FILE" 2>&1; then
        log_sucesso "Imagens de $nome atualizadas com sucesso"
    else
        log_erro "Falha ao fazer pull das imagens de $nome"
        cd "$dir_original"
        return 1
    fi
    
    # Reiniciar containers
    log "Reiniciando containers de $nome..."
    if docker compose up -d >> "$LOG_FILE" 2>&1; then
        log_sucesso "Containers de $nome reiniciados com sucesso"
    else
        log_erro "Falha ao reiniciar containers de $nome"
        cd "$dir_original"
        return 1
    fi
    
    # Aguardar e verificar status
    sleep 5
    log "Status dos containers de $nome:"
    docker compose ps >> "$LOG_FILE" 2>&1
    docker compose ps | tee -a "$LOG_FILE"
    
    # Voltar ao diretório original
    cd "$dir_original"
    
    log_sucesso "Atualização de $nome concluída"
    return 0
}

# Limpar imagens Docker antigas
limpar_imagens_antigas() {
    log_separador
    log "Limpando imagens Docker antigas não utilizadas"
    log_separador
    
    if ! command -v docker &> /dev/null; then
        log_aviso "Docker não disponível para limpeza de imagens"
        return 1
    fi
    
    log "Removendo imagens antigas..."
    if docker image prune -f >> "$LOG_FILE" 2>&1; then
        log_sucesso "Imagens antigas removidas com sucesso"
        
        # Mostrar espaço liberado
        local espaco_info=$(docker system df 2>/dev/null)
        if [ -n "$espaco_info" ]; then
            log "Uso de espaço do Docker:"
            echo "$espaco_info" | tee -a "$LOG_FILE"
        fi
        return 0
    else
        log_aviso "Falha ao remover imagens antigas"
        return 1
    fi
}

# Atualizar múltiplos containers
atualizar_containers() {
    local sucesso=0
    local total=0
    
    # Iterar sobre os argumentos (pares de nome e diretório)
    while [ $# -gt 0 ]; do
        local nome="$1"
        local diretorio="$2"
        shift 2
        
        total=$((total + 1))
        
        if atualizar_container "$nome" "$diretorio"; then
            sucesso=$((sucesso + 1))
        fi
    done
    
    # Limpar imagens antigas após atualizar todos
    limpar_imagens_antigas
    
    log_separador
    log_info "Containers atualizados: $sucesso de $total"
    log_separador
    
    return 0
}
