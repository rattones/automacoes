#!/bin/bash

#########################################
# Instalação Principal - Post-Install
# Orquestra todos os módulos de instalação
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"
POST_INSTALL_DIR="$LIB_DIR/post-install"

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

# Verificar se está rodando como usuário normal (não root)
if [ "$EUID" -eq 0 ]; then 
    log_erro "Este script NÃO deve ser executado como root"
    log "Execute como usuário normal. O script pedirá senha quando necessário."
    exit 1
fi

log_separador
log "INSTALAÇÃO PRINCIPAL - POST-INSTALL"
log_separador

# Módulos de instalação (ordem de execução)
MODULOS=(
    "setup-ssh.sh:SSH Server"
    "setup-zsh.sh:Zsh + Powerlevel10k"
    "setup-github-tools.sh:GitHub Tools (opcional)"
    "setup-cockpit.sh:Cockpit Web Console"
    "setup-docker.sh:Docker"
    "setup-nodejs.sh:Node.js (NVM)"
    "setup-containers.sh:Containers (Crafty, HAOS)"
    "setup-projects.sh:Restauração de Projetos"
    "setup-monitor.sh:Monitor Web do Servidor"
)

# Executar cada módulo
for modulo_info in "${MODULOS[@]}"; do
    # Separar nome do arquivo e descrição
    modulo_arquivo="${modulo_info%%:*}"
    modulo_desc="${modulo_info##*:}"
    modulo_path="$POST_INSTALL_DIR/$modulo_arquivo"
    
    log_separador
    log "Executando módulo: $modulo_desc"
    log_separador
    
    if [ -f "$modulo_path" ]; then
        # Executar módulo
        if bash "$modulo_path"; then
            log_sucesso "Módulo $modulo_desc concluído"
        else
            log_erro "Falha no módulo $modulo_desc"
            log_aviso "Continuando com próximo módulo..."
        fi
    else
        log_erro "Módulo não encontrado: $modulo_path"
        log_aviso "Continuando com próximo módulo..."
    fi
    
    echo ""
done

# Resumo final
log_separador
log "RESUMO DA INSTALAÇÃO"
log_separador

echo ""
log_sucesso "✓ SSH Server configurado"
log_sucesso "✓ Zsh + Powerlevel10k instalado"
log_sucesso "✓ Cockpit Web Console instalado"
log_sucesso "✓ Docker instalado e configurado"
log_sucesso "✓ Node.js instalado via NVM"
log_sucesso "✓ Containers configurados (Crafty, HAOS)"
log_sucesso "✓ Projetos restaurados"
log_sucesso "✓ Monitor Web instalado (porta 8180)"
echo ""

log_separador
log "ACESSAR SERVIÇOS"
log_separador

IP_LOCAL=$(hostname -I | awk '{print $1}')
echo ""
log "📌 SSH: ssh $USER@$IP_LOCAL"
log "📌 Cockpit Web Console: https://$IP_LOCAL:9090"
log "📌 Crafty Controller: http://$IP_LOCAL:8000"
log "📌 Home Assistant: Verifique portas no compose.yml"
echo ""

log_separador
log "PRÓXIMOS PASSOS"
log_separador

echo ""
log "1. Faça LOGOUT e LOGIN novamente para:"
log "   - Usar Zsh como shell padrão"
log "   - Usar Docker sem sudo"
log ""
log "2. Ou execute temporariamente: newgrp docker"
log ""
log "3. Verifique os containers: docker ps"
log ""
log "4. Configure o sistema de automação:"
log "   cd $REPO_DIR"
log "   sudo ./atualizar_servidor.sh"
echo ""

log_separador
log_sucesso "INSTALAÇÃO PRINCIPAL CONCLUÍDA!"
log_separador

exit 0
