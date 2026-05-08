#!/bin/bash

#########################################
# Módulo: Setup Monitor Web do Servidor
# Instalação e manutenção do painel de monitoramento
#########################################

# Diretório do repositório
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$REPO_DIR/lib"
MONITOR_DIR="$REPO_DIR/monitor"
VENV_DIR="$MONITOR_DIR/.venv"
ENV_FILE="$MONITOR_DIR/.env"
PORTA="${MONITOR_PORTA:-8180}"
SERVICE_NAME="monitor-servidor"

# Inicializar LOG_FILE se não definido (execução standalone, fora do atualizar_servidor.sh)
if [ -z "${LOG_FILE:-}" ]; then
    LOG_DIR="$REPO_DIR/logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/setup_monitor_$(date +%Y%m%d_%H%M%S).log"
fi

# Carregar biblioteca de logging
source "$LIB_DIR/logging.sh"

log_separador
log "Setup do Monitor Web do Servidor"
log_separador

# ── Verificar se diretório do monitor existe ──────────────────────────────────
if [ ! -d "$MONITOR_DIR" ]; then
    log_erro "Diretório do monitor não encontrado: $MONITOR_DIR"
    log_erro "Clone o repositório de automações completo antes de continuar."
    exit 1
fi

# ── Instalar dependências do sistema ─────────────────────────────────────────
log "Verificando dependências do sistema..."

PKGS_NECESSARIOS=()

# python3-venv (ensurepip)
if ! python3 -c "import ensurepip" &>/dev/null 2>&1; then
    PKGS_NECESSARIOS+=(python3-venv)
fi

# libpam0g-dev + python3-dev + gcc (para compilar python-pam)
if ! dpkg -s libpam0g-dev &>/dev/null 2>&1; then
    PKGS_NECESSARIOS+=(libpam0g-dev python3-dev gcc)
fi

if [ ${#PKGS_NECESSARIOS[@]} -gt 0 ]; then
    log "Instalando pacotes: ${PKGS_NECESSARIOS[*]}"
    if sudo apt install -y "${PKGS_NECESSARIOS[@]}"; then
        log_sucesso "Dependências instaladas"
    else
        log_erro "Falha ao instalar dependências do sistema"
        exit 1
    fi
else
    log "Dependências do sistema já satisfeitas"
fi

# ── Criar / atualizar ambiente virtual Python ─────────────────────────────────
# Verifica se o venv está completo (pip ausente = criação anterior falhou)
if [ ! -f "$VENV_DIR/bin/pip" ] || [ ! -f "$VENV_DIR/bin/python3" ]; then
    if [ -d "$VENV_DIR" ]; then
        log_aviso "Ambiente virtual corrompido (pip ou python3 ausente), recriando..."
        rm -rf "$VENV_DIR"
    else
        log "Criando ambiente virtual Python em $VENV_DIR..."
    fi
    if python3 -m venv "$VENV_DIR"; then
        log_sucesso "Ambiente virtual criado"
    else
        log_erro "Falha ao criar ambiente virtual"
        exit 1
    fi
else
    log "Ambiente virtual íntegro encontrado"
fi

log "Instalando/atualizando pacotes Python no venv..."
"$VENV_DIR/bin/pip" install --upgrade pip --quiet
if "$VENV_DIR/bin/pip" install -r "$MONITOR_DIR/requirements.txt" --quiet; then
    log_sucesso "Pacotes Python instalados: $("$VENV_DIR/bin/pip" freeze | tr '\n' ' ')"
else
    log_erro "Falha ao instalar pacotes Python"
    exit 1
fi

# ── Gerar chave secreta (somente na primeira instalação) ──────────────────────
if [ ! -f "$ENV_FILE" ]; then
    log "Gerando chave secreta aleatória..."
    SECRET_KEY=$("$VENV_DIR/bin/python3" -c "import secrets; print(secrets.token_hex(32))")
    cat > "$ENV_FILE" <<EOF
SECRET_KEY=${SECRET_KEY}
MONITOR_PORTA=${PORTA}
EOF
    chmod 600 "$ENV_FILE"
    log_sucesso "Arquivo .env criado (permissões 600)"
else
    log "Arquivo .env já existe, mantendo configuração"
fi

# ── Permissões dos scripts ────────────────────────────────────────────────────
log "Configurando permissões dos scripts..."
chmod +x "$MONITOR_DIR/server.py"
chmod +x "$MONITOR_DIR/scripts/"*.sh
log_sucesso "Permissões configuradas"

# ── Sudoers: ss sem senha (para get_network.sh ver processos de outros usuários) ──
SUDOERS_FILE="/etc/sudoers.d/monitor-servidor"
SUDOERS_LINE="$(whoami) ALL=(root) NOPASSWD: /usr/bin/ss"
if [ ! -f "$SUDOERS_FILE" ] || ! grep -qF "NOPASSWD: /usr/bin/ss" "$SUDOERS_FILE" 2>/dev/null; then
    log "Configurando permissão sudoers para ss..."
    echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    log_sucesso "Regra sudoers criada: ${SUDOERS_FILE}"
fi

# ── Serviço systemd ───────────────────────────────────────────────────────────
log_separador
log "Configurando serviço systemd: ${SERVICE_NAME}"
log_separador

USUARIO_ATUAL=$(whoami)
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Detectar se o serviço já existe e se precisa ser atualizado
SERVICO_EXISTE=false
SERVICO_DESATUALIZADO=false

if [ -f "$SERVICE_FILE" ]; then
    SERVICO_EXISTE=true
    # Verificar se o ExecStart aponta para o venv correto
    if ! grep -qF "$VENV_DIR/bin/python3" "$SERVICE_FILE" 2>/dev/null; then
        SERVICO_DESATUALIZADO=true
        log_aviso "Serviço existe mas está desatualizado, recriando..."
    else
        log "Serviço systemd já está configurado corretamente"
    fi
fi

if [ "$SERVICO_EXISTE" = false ] || [ "$SERVICO_DESATUALIZADO" = true ]; then
    # Parar serviço existente antes de recriar
    if [ "$SERVICO_EXISTE" = true ]; then
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    fi

    log "Criando arquivo de serviço: $SERVICE_FILE"
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Monitor Web do Servidor
Documentation=https://github.com/rattones/automacoes
After=network.target docker.service
Wants=network.target

[Service]
Type=simple
User=${USUARIO_ATUAL}
WorkingDirectory=${MONITOR_DIR}
ExecStart=${VENV_DIR}/bin/python3 ${MONITOR_DIR}/server.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}
EnvironmentFile=${ENV_FILE}

[Install]
WantedBy=multi-user.target
EOF
    log_sucesso "Arquivo de serviço criado"

    log "Habilitando e iniciando o serviço..."
    sudo systemctl daemon-reload
    if sudo systemctl enable --now "$SERVICE_NAME"; then
        log_sucesso "Serviço '${SERVICE_NAME}' habilitado e iniciado"
    else
        log_erro "Falha ao iniciar o serviço"
        log_aviso "Verifique com: sudo journalctl -u ${SERVICE_NAME} -n 50"
        exit 1
    fi
else
    # Serviço já existe e está atualizado — apenas recarregar se estiver rodando
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Serviço está ativo, reiniciando para aplicar eventuais mudanças..."
        sudo systemctl restart "$SERVICE_NAME"
        log_sucesso "Serviço reiniciado"
    else
        log_aviso "Serviço está parado, iniciando..."
        sudo systemctl start "$SERVICE_NAME"
        log_sucesso "Serviço iniciado"
    fi
fi

# ── Verificação final ─────────────────────────────────────────────────────────
log_separador
log "Verificando status do serviço..."
log_separador

sleep 2  # aguardar inicialização

if systemctl is-active --quiet "$SERVICE_NAME"; then
    IP_LOCAL=$(hostname -I | awk '{print $1}')
    log_sucesso "Monitor está rodando!"
    log_sucesso "Acesse em: http://${IP_LOCAL}:${PORTA}"
    log "Login com usuário e senha do sistema operacional"
    log ""
    log "Comandos úteis:"
    log_indent "Status:   sudo systemctl status ${SERVICE_NAME}"
    log_indent "Logs:     sudo journalctl -u ${SERVICE_NAME} -f"
    log_indent "Parar:    sudo systemctl stop ${SERVICE_NAME}"
    log_indent "Reiniciar: sudo systemctl restart ${SERVICE_NAME}"
else
    log_erro "O serviço não está ativo após a instalação"
    log_aviso "Logs de erro:"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || true
    exit 1
fi

exit 0
