#!/bin/bash

#########################################
# Diagnóstico e Correção de Problemas APT
# Analisa e corrige conflitos de repositórios
#########################################

# Cores para output
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${AZUL}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_erro() {
    echo -e "${VERMELHO}[ERRO][$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_sucesso() {
    echo -e "${VERDE}[SUCESSO][$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_aviso() {
    echo -e "${AMARELO}[AVISO][$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_separador() {
    echo "=========================================="
}

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    log_erro "Este script deve ser executado como root"
    log "Execute: sudo $0"
    exit 1
fi

log_separador
log "DIAGNÓSTICO DE PROBLEMAS APT"
log_separador
echo ""

# 1. Testar apt update
log "Testando apt update..."
if apt update > /tmp/apt_test.log 2>&1; then
    log_sucesso "APT funcionando corretamente!"
    rm -f /tmp/apt_test.log
    exit 0
else
    log_erro "Problemas detectados no APT"
    echo ""
fi

# 2. Analisar erros
log_separador
log "Analisando erros..."
log_separador
echo ""

# Conflito Docker
if grep -i "docker.com.*Conflicting values.*Signed-By" /tmp/apt_test.log > /dev/null 2>&1; then
    log_erro "PROBLEMA CRÍTICO: Conflito de configuração do repositório Docker"
    echo ""
    
    log "Detalhes do problema:"
    log "  - Múltiplos arquivos de configuração do Docker encontrados"
    log "  - Chaves GPG conflitantes"
    echo ""
    
    # Listar arquivos problemáticos
    log "Arquivos de repositório Docker:"
    ls -lh /etc/apt/sources.list.d/docker* 2>/dev/null | awk '{print "  "$9" ("$5")"}'
    echo ""
    
    log "Chaves GPG Docker:"
    ls -lh /etc/apt/keyrings/docker* 2>/dev/null | awk '{print "  "$9" ("$5")"}'
    echo ""
    
    # Propor solução
    log_separador
    log "SOLUÇÃO RECOMENDADA"
    log_separador
    echo ""
    
    read -p "Deseja corrigir automaticamente? (s/N): " resposta
    
    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        log "Iniciando correção..."
        echo ""
        
        # Backup dos arquivos
        log "Criando backup dos arquivos..."
        mkdir -p /root/apt-backup-$(date +%Y%m%d)
        cp /etc/apt/sources.list.d/docker* /root/apt-backup-$(date +%Y%m%d)/ 2>/dev/null
        cp /etc/apt/keyrings/docker* /root/apt-backup-$(date +%Y%m%d)/ 2>/dev/null
        log_sucesso "Backup criado em: /root/apt-backup-$(date +%Y%m%d)/"
        echo ""
        
        # Remover arquivos duplicados
        log "Removendo configurações duplicadas..."
        
        # Manter apenas docker.list (formato mais recente usado pelo script)
        if [ -f /etc/apt/sources.list.d/docker.sources ]; then
            rm -f /etc/apt/sources.list.d/docker.sources
            log_sucesso "Removido: docker.sources (duplicado)"
        fi
        
        # Manter apenas docker.gpg
        if [ -f /etc/apt/keyrings/docker.asc ]; then
            rm -f /etc/apt/keyrings/docker.asc
            log_sucesso "Removido: docker.asc (chave duplicada)"
        fi
        
        echo ""
        
        # Verificar se docker.gpg existe, senão baixar novamente
        if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
            log "Baixando chave GPG do Docker..."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            log_sucesso "Chave GPG instalada"
        fi
        
        echo ""
        
        # Testar novamente
        log "Testando correção..."
        if apt update > /tmp/apt_test2.log 2>&1; then
            log_sucesso "✓ APT corrigido com sucesso!"
            rm -f /tmp/apt_test.log /tmp/apt_test2.log
        else
            log_erro "Ainda há problemas. Verifique manualmente:"
            cat /tmp/apt_test2.log
            rm -f /tmp/apt_test.log /tmp/apt_test2.log
            exit 1
        fi
    else
        log_aviso "Correção cancelada pelo usuário"
        echo ""
        log "Para corrigir manualmente:"
        log "  1. Remover arquivo duplicado:"
        log "     sudo rm /etc/apt/sources.list.d/docker.sources"
        log "  2. Remover chave duplicada:"
        log "     sudo rm /etc/apt/keyrings/docker.asc"
        log "  3. Testar:"
        log "     sudo apt update"
    fi
fi

# Outros erros comuns
if grep -i "Could not resolve\|Failed to fetch\|Unable to connect" /tmp/apt_test.log > /dev/null 2>&1; then
    log_erro "PROBLEMA: Erro de rede/conectividade"
    log "Verifique sua conexão com a internet"
    echo ""
fi

if grep -i "NO_PUBKEY" /tmp/apt_test.log > /dev/null 2>&1; then
    log_erro "PROBLEMA: Chave GPG ausente"
    grep "NO_PUBKEY" /tmp/apt_test.log | while read linha; do
        log_aviso "  $linha"
    done
    echo ""
fi

if grep -i "broken\|quebrado" /tmp/apt_test.log > /dev/null 2>&1; then
    log_erro "PROBLEMA: Dependências quebradas"
    log "Execute: sudo apt --fix-broken install"
    echo ""
fi

# Limpar
rm -f /tmp/apt_test.log

log_separador
log "Diagnóstico concluído"
log_separador

exit 0
