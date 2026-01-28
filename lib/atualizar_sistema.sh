#!/bin/bash

#########################################
# Atualização de Pacotes do Sistema
#########################################

# Atualizar lista de pacotes
atualizar_lista_pacotes() {
    log "Atualizando lista de pacotes..."
    
    if apt update -qq; then
        log_sucesso "Lista de pacotes atualizada com sucesso"
        return 0
    else
        log_erro "Falha ao atualizar lista de pacotes"
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
    
    if apt upgrade -y -qq; then
        log_sucesso "Pacotes atualizados com sucesso"
        return 0
    else
        log_erro "Falha ao atualizar pacotes"
        return 1
    fi
}

# Fazer dist-upgrade
dist_upgrade_sistema() {
    log "Executando dist-upgrade..."
    
    if apt dist-upgrade -y -qq; then
        log_sucesso "Dist-upgrade concluído com sucesso"
        return 0
    else
        log_erro "Dist-upgrade falhou"
        return 1
    fi
}

# Remover pacotes desnecessários
remover_pacotes_desnecessarios() {
    log "Removendo pacotes desnecessários..."
    
    if apt autoremove -y -qq; then
        log "Nenhum pacote desnecessário encontrado"
        return 0
    else
        log_aviso "Falha ao remover pacotes desnecessários"
        return 1
    fi
}

# Limpar cache do apt
limpar_cache_apt() {
    log "Limpando cache do apt..."
    if apt autoclean -qq; then
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
