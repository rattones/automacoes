#!/usr/bin/env python3
"""
Monitor Web do Servidor
Painel de monitoramento com autenticação PAM e execução controlada de scripts Bash.
Porta padrão: 8180
"""

import os
import re
import json
import subprocess
import secrets
import time
import logging
from collections import defaultdict
from functools import wraps
from pathlib import Path

from flask import (
    Flask, render_template, request, session,
    redirect, url_for, jsonify
)

# ── Configuração ──────────────────────────────────────────────────────────────

BASE_DIR   = Path(__file__).parent.resolve()
SCRIPTS_DIR = BASE_DIR / "scripts"
PROJ_DIR   = BASE_DIR.parent  # raiz do projeto automacoes

# Carregar .env se existir
env_file = BASE_DIR / ".env"
if env_file.is_file():
    for linha in env_file.read_text().splitlines():
        if "=" in linha and not linha.startswith("#"):
            k, _, v = linha.partition("=")
            os.environ.setdefault(k.strip(), v.strip())

SECRET_KEY = os.environ.get("SECRET_KEY") or secrets.token_hex(32)
PORTA      = int(os.environ.get("MONITOR_PORTA", 8180))

app = Flask(__name__)
app.secret_key = SECRET_KEY
app.config["SESSION_COOKIE_HTTPONLY"] = True
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["PERMANENT_SESSION_LIFETIME"] = 3600  # 1 hora

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

# ── Rate Limiting (in-memory, simples) ───────────────────────────────────────

_login_attempts: dict[str, list[float]] = defaultdict(list)
MAX_TENTATIVAS = 5
JANELA_SEGUNDOS = 300  # 5 minutos

def _ip_bloqueado(ip: str) -> bool:
    agora = time.time()
    tentativas = [t for t in _login_attempts[ip] if agora - t < JANELA_SEGUNDOS]
    _login_attempts[ip] = tentativas
    return len(tentativas) >= MAX_TENTATIVAS

def _registrar_tentativa(ip: str):
    _login_attempts[ip].append(time.time())

# ── Autenticação PAM ─────────────────────────────────────────────────────────

def autenticar_pam(usuario: str, senha: str) -> bool:
    """Autentica usuário/senha contra o sistema via PAM."""
    try:
        import pam  # python-pam
        p = pam.pam()
        return p.authenticate(usuario, senha, service="login")
    except ImportError:
        # Fallback: tenta via su para verificar credencial (não recomendado em produção)
        logger.warning("python-pam não disponível, usando fallback via su")
        try:
            r = subprocess.run(
                ["su", "-c", "true", usuario],
                input=f"{senha}\n",
                capture_output=True, text=True, timeout=5
            )
            return r.returncode == 0
        except Exception:
            return False
    except Exception as e:
        logger.error(f"Erro na autenticação PAM: {e}")
        return False

# ── Decoradores ───────────────────────────────────────────────────────────────

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "usuario" not in session:
            if request.is_json:
                return jsonify({"erro": "Não autenticado", "redirect": "/"}), 401
            return redirect(url_for("index"))
        return f(*args, **kwargs)
    return decorated

# ── Validação de Entradas ─────────────────────────────────────────────────────

RE_SERVICO   = re.compile(r'^[a-zA-Z0-9_@.\-]+\.service$')
RE_CONTAINER = re.compile(r'^[a-zA-Z0-9_.\-]+$')
RE_ACTION    = re.compile(r'^(start|stop|restart|reload)$')
RE_USERNAME  = re.compile(r'^[a-z_][a-z0-9_\-]{0,31}$')

ACOES_CONTAINER = {"start", "stop", "restart"}
ACOES_SERVICO   = {"start", "stop", "restart", "reload"}

def _validar_campo(valor: str, pattern: re.Pattern, nome: str) -> str:
    """Retorna o valor limpo ou lança ValueError."""
    if not valor or not pattern.match(valor):
        raise ValueError(f"Valor inválido para {nome}: {valor!r}")
    return valor

# ── Execução de Scripts ───────────────────────────────────────────────────────

TIMEOUT_SCRIPT = 30  # segundos para scripts de status
TIMEOUT_ACAO   = 60  # segundos para ações (stop pode demorar)
TIMEOUT_UPDATE = 300 # 5 min para atualizações

def _executar_script(caminho: Path, args: list[str] = None, timeout: int = TIMEOUT_SCRIPT,
                     sudo_pass: str = None) -> tuple[bool, str]:
    """
    Executa um script Bash e retorna (sucesso, saida_stdout).
    Se sudo_pass for fornecido, executa com sudo -S.
    """
    if not caminho.is_file():
        return False, f"Script não encontrado: {caminho}"

    cmd: list[str]
    env = os.environ.copy()
    env["TERM"] = "dumb"

    if sudo_pass:
        # Nunca logar a senha
        cmd = ["sudo", "-S", str(caminho)] + (args or [])
        stdin_data = sudo_pass + "\n"
    else:
        cmd = [str(caminho)] + (args or [])
        stdin_data = None

    try:
        r = subprocess.run(
            cmd,
            input=stdin_data,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env
        )
        saida = r.stdout.strip()
        if r.returncode != 0:
            logger.warning(f"Script {caminho.name} saiu com código {r.returncode}")
            erro = r.stderr.strip()
            # Remover linha com senha do sudo no stderr (pode aparecer "[sudo] password for ...")
            erro = re.sub(r'\[sudo\].*\n?', '', erro)
            return False, json.dumps({"success": False, "error": erro, "output": saida})
        return True, saida
    except subprocess.TimeoutExpired:
        return False, json.dumps({"success": False, "error": f"Timeout após {timeout}s", "output": ""})
    except Exception as e:
        return False, json.dumps({"success": False, "error": str(e), "output": ""})

# ── Rotas ─────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    if "usuario" not in session:
        return render_template("index.html", autenticado=False)
    return render_template("index.html", autenticado=True, usuario=session["usuario"])


@app.route("/login", methods=["POST"])
def login():
    ip = request.remote_addr or "unknown"

    if _ip_bloqueado(ip):
        return jsonify({
            "success": False,
            "erro": "Muitas tentativas. Aguarde 5 minutos."
        }), 429

    dados = request.get_json(silent=True) or {}
    usuario = dados.get("usuario", "").strip()
    senha   = dados.get("senha", "")

    if not usuario or not senha:
        return jsonify({"success": False, "erro": "Usuário e senha são obrigatórios."}), 400

    if not RE_USERNAME.match(usuario):
        return jsonify({"success": False, "erro": "Nome de usuário inválido."}), 400

    if autenticar_pam(usuario, senha):
        session.permanent = True
        session["usuario"] = usuario
        logger.info(f"Login bem-sucedido: {usuario} de {ip}")
        return jsonify({"success": True})
    else:
        _registrar_tentativa(ip)
        logger.warning(f"Falha no login: {usuario} de {ip}")
        return jsonify({"success": False, "erro": "Usuário ou senha incorretos."}), 401


@app.route("/logout", methods=["POST"])
def logout():
    usuario = session.pop("usuario", None)
    if usuario:
        logger.info(f"Logout: {usuario}")
    return jsonify({"success": True})


@app.route("/api/system/restart-monitor", methods=["POST"])
@login_required
def api_restart_monitor():
    dados = request.get_json(silent=True) or {}
    sudo_pass = dados.get("sudo_pass", "")
    if not sudo_pass:
        return jsonify({"success": False, "erro": "Senha sudo é obrigatória."}), 400

    # Verificar senha antes de agendar o restart
    r = subprocess.run(
        ["sudo", "-S", "-v"],
        input=sudo_pass + "\n",
        capture_output=True, text=True, timeout=5,
        env={**os.environ, "TERM": "dumb"}
    )
    if r.returncode != 0:
        return jsonify({"success": False, "erro": "Senha sudo incorreta."}), 400

    logger.info(f"Reinicialização do serviço monitor solicitada por {session.get('usuario')}")
    # Popen com start_new_session para sobreviver ao SIGTERM do restart
    proc = subprocess.Popen(
        ["sudo", "-S", "systemctl", "restart", "monitor-servidor.service"],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    proc.stdin.write((sudo_pass + "\n").encode())
    proc.stdin.close()
    return jsonify({"success": True})


@app.route("/api/system/reboot", methods=["POST"])
@login_required
def api_reboot():
    dados = request.get_json(silent=True) or {}
    sudo_pass = dados.get("sudo_pass", "")
    if not sudo_pass:
        return jsonify({"success": False, "erro": "Senha sudo é obrigatória."}), 400

    # Verificar senha
    r = subprocess.run(
        ["sudo", "-S", "-v"],
        input=sudo_pass + "\n",
        capture_output=True, text=True, timeout=5,
        env={**os.environ, "TERM": "dumb"}
    )
    if r.returncode != 0:
        return jsonify({"success": False, "erro": "Senha sudo incorreta."}), 400

    logger.warning(f"Reinicialização do SERVIDOR solicitada por {session.get('usuario')}")
    proc = subprocess.Popen(
        ["sudo", "-S", "reboot"],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    proc.stdin.write((sudo_pass + "\n").encode())
    proc.stdin.close()
    return jsonify({"success": True})


@app.route("/api/status")
@login_required
def api_status():
    ok, saida = _executar_script(SCRIPTS_DIR / "get_status.sh")
    if ok:
        try:
            return jsonify(json.loads(saida))
        except json.JSONDecodeError:
            return jsonify({"erro": "Resposta inválida do script"}), 500
    return jsonify({"erro": saida}), 500


@app.route("/api/network")
@login_required
def api_network():
    ok, saida = _executar_script(SCRIPTS_DIR / "get_network.sh", timeout=10)
    if ok:
        try:
            return jsonify(json.loads(saida))
        except json.JSONDecodeError:
            return jsonify({"erro": "Resposta inválida do script"}), 500
    return jsonify({"erro": saida}), 500


@app.route("/api/services")
@login_required
def api_services():
    ok_svc, saida_svc = _executar_script(SCRIPTS_DIR / "get_services.sh")
    ok_ctn, saida_ctn = _executar_script(SCRIPTS_DIR / "get_containers.sh")

    servicos   = json.loads(saida_svc) if ok_svc else []
    containers = {}
    if ok_ctn:
        try:
            containers = json.loads(saida_ctn)
        except json.JSONDecodeError:
            containers = {}

    return jsonify({
        "servicos":   servicos,
        "containers": containers
    })


@app.route("/api/service/action", methods=["POST"])
@login_required
def api_service_action():
    dados = request.get_json(silent=True) or {}

    try:
        servico    = _validar_campo(dados.get("service", ""), RE_SERVICO, "service")
        acao       = _validar_campo(dados.get("action", ""), RE_ACTION, "action")
    except ValueError as e:
        return jsonify({"success": False, "erro": str(e)}), 400

    if acao not in ACOES_SERVICO:
        return jsonify({"success": False, "erro": f"Ação não permitida: {acao}"}), 400

    sudo_pass = dados.get("sudo_pass", "")
    if not sudo_pass:
        return jsonify({"success": False, "erro": "Senha sudo é obrigatória para esta ação."}), 400

    script = SCRIPTS_DIR / "service_action.sh"
    ok, saida = _executar_script(script, args=[acao, servico],
                                 timeout=TIMEOUT_ACAO, sudo_pass=sudo_pass)
    try:
        return jsonify(json.loads(saida))
    except (json.JSONDecodeError, TypeError):
        return jsonify({"success": ok, "output": saida, "erro": "" if ok else saida})


@app.route("/api/container/action", methods=["POST"])
@login_required
def api_container_action():
    dados = request.get_json(silent=True) or {}

    try:
        container = _validar_campo(dados.get("container", ""), RE_CONTAINER, "container")
        acao      = _validar_campo(dados.get("action", ""), re.compile(r'^(start|stop|restart)$'), "action")
    except ValueError as e:
        return jsonify({"success": False, "erro": str(e)}), 400

    if acao not in ACOES_CONTAINER:
        return jsonify({"success": False, "erro": f"Ação não permitida: {acao}"}), 400

    script = SCRIPTS_DIR / "container_action.sh"
    ok, saida = _executar_script(script, args=[acao, container], timeout=TIMEOUT_ACAO)
    try:
        return jsonify(json.loads(saida))
    except (json.JSONDecodeError, TypeError):
        return jsonify({"success": ok, "output": saida, "erro": "" if ok else saida})


@app.route("/api/update/system", methods=["POST"])
@login_required
def api_update_system():
    dados = request.get_json(silent=True) or {}
    sudo_pass = dados.get("sudo_pass", "")

    if not sudo_pass:
        return jsonify({"success": False, "erro": "Senha sudo é obrigatória."}), 400

    script = PROJ_DIR / "atualizar_servidor.sh"
    ok, saida = _executar_script(script, timeout=TIMEOUT_UPDATE, sudo_pass=sudo_pass)

    return jsonify({"success": ok, "output": saida if ok else "", "erro": "" if ok else saida})


@app.route("/api/update/container", methods=["POST"])
@login_required
def api_update_container():
    dados = request.get_json(silent=True) or {}
    sudo_pass = dados.get("sudo_pass", "")

    try:
        nome    = _validar_campo(dados.get("nome", ""),    RE_CONTAINER, "nome")
        caminho = dados.get("caminho", "").strip()
    except ValueError as e:
        return jsonify({"success": False, "erro": str(e)}), 400

    if not sudo_pass:
        return jsonify({"success": False, "erro": "Senha sudo é obrigatória."}), 400

    # Validar que o caminho existe e está sob /home ou /opt (evitar path traversal)
    if not re.match(r'^/(home|opt|srv|docker)/[a-zA-Z0-9_/\-\.]+$', caminho):
        return jsonify({"success": False, "erro": "Caminho inválido."}), 400

    if not Path(caminho).is_dir():
        return jsonify({"success": False, "erro": f"Diretório não encontrado: {caminho}"}), 400

    # Cria script temporário que importa as libs e chama atualizar_container
    script_tmp = PROJ_DIR / "monitor" / "_run_update_container.sh"
    script_tmp.write_text(f"""#!/bin/bash
SCRIPT_DIR="{PROJ_DIR}"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/monitor_update_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/atualizar_container.sh"
inicializar_log "$LOG_DIR" "$LOG_FILE"
atualizar_container "{nome}" "{caminho}"
cat "$LOG_FILE"
""")
    script_tmp.chmod(0o750)

    ok, saida = _executar_script(script_tmp, timeout=TIMEOUT_UPDATE, sudo_pass=sudo_pass)
    script_tmp.unlink(missing_ok=True)

    return jsonify({"success": ok, "output": saida if ok else "", "erro": "" if ok else saida})


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    logger.info(f"Monitor iniciando na porta {PORTA}...")
    logger.info(f"Acesse: http://0.0.0.0:{PORTA}")
    app.run(host="0.0.0.0", port=PORTA, debug=False)
