#!/bin/bash

#########################################
# Atualização de Pacotes do Sistema
#########################################

# Atualizar lista de pacotes
atualizar_lista_pacotes() {
    log "Atualizando lista de pacotes..."
    
    local temp_log="/tmp/apt_update_$$.log"
    
    if apt update > "$temp_log" 2>&1; then
        log_sucesso "Lista de pacotes atualizada com sucesso"
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 0
    else
        log_erro "Falha ao atualizar lista de pacotes"
        
        # Extrair e mostrar erros específicos
        if grep -i "error\|err\|failed\|falhou" "$temp_log" > /dev/null; then
            log_erro "Detalhes do erro:"
            grep -i "error\|err\|failed\|falhou" "$temp_log" | while read linha; do
                log_erro "  $linha"
            done
        fi
        
        # Verificar problemas de rede
        if grep -i "could not resolve\|temporary failure\|network\|connection" "$temp_log" > /dev/null; then
            log_erro "Problema de rede detectado. Verifique sua conexão com a internet."
        fi
        
        # Verificar problemas de repositório
        if grep -i "repository\|repositório\|release file" "$temp_log" > /dev/null; then
            log_erro "Problema com repositórios. Verifique /etc/apt/sources.list"
        fi
        
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 1
    fi
}

# Verificar pacotes disponíveis para atualização
verificar_pacotes_disponiveis() {
    local pacotes_disponiveis=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    log "Pacotes disponíveis para atualização: $pacotes_disponiveis"
    return $pacotes_disponiveis
}

# Fazer upgrade dos pacotes
upgrade_pacotes() {
    log "Iniciando upgrade dos pacotes..."
    
    local temp_log="/tmp/apt_upgrade_$$.log"
    
    if apt upgrade -y > "$temp_log" 2>&1; then
        log_sucesso "Pacotes atualizados com sucesso"
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 0
    else
        log_erro "Falha ao atualizar pacotes"
        
        # Extrair pacotes com problemas
        if grep -E "E: |Err:|dpkg: error|Errors were encountered" "$temp_log" > /dev/null; then
            log_erro "Pacotes com problemas:"
            grep -E "E: |Err:|dpkg: error|Errors were encountered" "$temp_log" | while read linha; do
                log_erro "  $linha"
            done
        fi
        
        # Verificar pacotes quebrados
        if grep -i "broken\|quebrado" "$temp_log" > /dev/null; then
            log_erro "Dependências quebradas detectadas!"
            log "Tente executar: sudo apt --fix-broken install"
        fi
        
        # Verificar pacotes retidos
        if grep -i "held back\|retidos" "$temp_log" > /dev/null; then
            log_aviso "Alguns pacotes foram retidos:"
            grep -i "held back\|retidos" "$temp_log" | while read linha; do
                log_aviso "  $linha"
            done
        fi
        
        # Verificar espaço em disco
        if grep -i "no space\|sem espaço\|disk full" "$temp_log" > /dev/null; then
            log_erro "Espaço em disco insuficiente!"
            df -h / | tail -1 | awk '{print "  Usado: "$3" de "$2" ("$5" de uso)"}' | tee -a "$LOG_FILE"
        fi
        
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 1
    fi
}

# Fazer dist-upgrade
dist_upgrade_sistema() {
    log "Executando dist-upgrade..."
    
    local temp_log="/tmp/apt_dist_upgrade_$$.log"
    
    if apt dist-upgrade -y > "$temp_log" 2>&1; then
        log_sucesso "Dist-upgrade concluído com sucesso"
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 0
    else
        log_aviso "Dist-upgrade falhou"
        
        # Mostrar erros específicos
        if grep -E "E: |Err:" "$temp_log" > /dev/null; then
            log_erro "Erros encontrados:"
            grep -E "E: |Err:" "$temp_log" | while read linha; do
                log_erro "  $linha"
            done
        fi
        
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 1
    fi
}

# Remover pacotes desnecessários
remover_pacotes_desnecessarios() {
    log "Removendo pacotes desnecessários..."
    
    local temp_log="/tmp/apt_autoremove_$$.log"
    
    if apt autoremove -y > "$temp_log" 2>&1; then
        # Verificar se algum pacote foi removido
        if grep -i "removing\|removendo" "$temp_log" > /dev/null; then
            local removidos=$(grep -oP '\d+(?= (to remove|upgraded|newly installed|to remove))' "$temp_log" | head -1)
            if [ -n "$removidos" ] && [ "$removidos" -gt 0 ]; then
                log_sucesso "$removidos pacote(s) desnecessário(s) removido(s)"
            else
                log_sucesso "Pacotes desnecessários removidos"
            fi
        else
            log "Nenhum pacote desnecessário encontrado"
        fi
        
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 0
    else
        log_aviso "Falha ao remover pacotes desnecessários"
        
        if grep -E "E: |Err:" "$temp_log" > /dev/null; then
            grep -E "E: |Err:" "$temp_log" | while read linha; do
                log_erro "  $linha"
            done
        fi
        
        cat "$temp_log" >> "$LOG_FILE"
        rm -f "$temp_log"
        return 1
    fi
}

# Limpar cache do apt
limpar_cache_apt() {
    log "Limpando cache do apt..."
    if apt autoclean >> "$LOG_FILE" 2>&1; then
        log_sucesso "Cache limpo com sucesso"
        return 0
    else
        log_aviso "Falha ao limpar cache"
        return 1
    fi
}

# Executar atualização completa do sistema
atualizar_sistema_completo() {
    log_separador
    log "Iniciando atualização do sistema operacional"
    log_separador
    
    # Atualizar lista de pacotes
    atualizar_lista_pacotes || return 1
    
    # Verificar se há pacotes disponíveis
    verificar_pacotes_disponiveis
    local pacotes=$?
    
    if [ $pacotes -eq 0 ]; then
        log_aviso "Nenhum pacote disponível para atualização"
        return 0
    fi
    
    # Executar upgrades
    upgrade_pacotes || return 1
    dist_upgrade_sistema
    remover_pacotes_desnecessarios
    limpar_cache_apt
    
    log_sucesso "Atualização do sistema concluída"
    return 0
}
