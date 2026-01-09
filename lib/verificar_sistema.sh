#!/bin/bash

#########################################
# Verificações e Estatísticas do Sistema
#########################################

# Registrar informações do sistema
registrar_info_sistema() {
    log_separador
    log "Informações do Sistema"
    log_separador
    log "Sistema: $(uname -a)"
    log "Hostname: $(hostname)"
    log "Uptime: $(uptime)"
    log_separador
}

# Verificar se é necessário reiniciar o sistema
verificar_necessidade_reinicializacao() {
    log_separador
    log "Verificando necessidade de reinicialização"
    log_separador
    
    if [ -f /var/run/reboot-required ]; then
        log_aviso "REINICIALIZAÇÃO NECESSÁRIA!"
        
        if [ -f /var/run/reboot-required.pkgs ]; then
            local motivo=$(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' ')
            log_aviso "Pacotes que requerem reinicialização: $motivo"
        fi
        
        log_aviso "Para reiniciar automaticamente, descomente a linha no script principal"
        # shutdown -r +5 "O servidor será reiniciado em 5 minutos devido a atualizações"
        return 1
    else
        log_sucesso "Reinicialização não necessária"
        return 0
    fi
}

# Mostrar estatísticas do sistema
mostrar_estatisticas() {
    log_separador
    log "Estatísticas do Sistema"
    log_separador
    
    # Espaço em disco
    log "Uso de disco:"
    df -h / | tail -1 | awk '{print "  Partição raiz: "$3" usado de "$2" ("$5" de uso)"}' | tee -a "$LOG_FILE"
    
    # Verificar outras partições importantes
    if df -h /home &>/dev/null; then
        df -h /home | tail -1 | awk '{print "  Partição /home: "$3" usado de "$2" ("$5" de uso)"}' | tee -a "$LOG_FILE"
    fi
    
    # Memória
    log "Uso de memória:"
    free -h | grep Mem | awk '{print "  "$3" usado de "$2" (disponível: "$7")"}' | tee -a "$LOG_FILE"
    
    # Swap
    log "Uso de swap:"
    free -h | grep Swap | awk '{print "  "$3" usado de "$2}' | tee -a "$LOG_FILE"
    
    # Processos
    log "Processos em execução: $(ps aux | wc -l)"
    
    # Load average
    log "Load average: $(uptime | awk -F'load average:' '{print $2}')"
    
    log_separador
}

# Enviar notificação por email
enviar_notificacao_email() {
    local email_destino="$1"
    local assunto="$2"
    local arquivo_log="$3"
    
    if [ -z "$email_destino" ]; then
        return 0
    fi
    
    if ! command -v mail &> /dev/null; then
        log_aviso "Comando 'mail' não disponível. Instale mailutils para enviar emails."
        return 1
    fi
    
    if mail -s "$assunto" "$email_destino" < "$arquivo_log" 2>/dev/null; then
        log_sucesso "Email de notificação enviado para $email_destino"
        return 0
    else
        log_aviso "Falha ao enviar email de notificação"
        return 1
    fi
}
