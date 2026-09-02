#!/usr/bin/env python3
"""
Monitor Web do Servidor
Painel de monitoramento com autenticação PAM e execução controlada de scripts Bash.
Porta padrão: 8180
"""

import os
import re
import json
import socket
import subprocess
import secrets
import time
import logging
import threading
import ssl
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from functools import wraps
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse, urlunparse
from urllib.request import Request, urlopen

from flask import (
    Flask, render_template, request, session,
    redirect, url_for, jsonify
)

# ── Configuração ──────────────────────────────────────────────────────────────

BASE_DIR   = Path(__file__).parent.resolve()
SCRIPTS_DIR = BASE_DIR / "scripts"
PROJ_DIR   = BASE_DIR.parent  # raiz do projeto automacoes
DATA_DIR   = BASE_DIR / "data"
WATCHLIST_PATH = DATA_DIR / "watchlist.json"
HISTORICO_WATCHLIST_PATH = DATA_DIR / "watchlist_historico.json"
HISTORICO_MAX_PONTOS = 20

LOGS_DIR = PROJ_DIR / "logs"
LOGS_POR_PAGINA = 10
LOG_MAX_LINHAS = 5000          # teto de segurança ao ler um log
LOG_MAX_BYTES = 2 * 1024 * 1024  # 2 MB

# Carregar .env se existir
env_file = BASE_DIR / ".env"
if env_file.is_file():
    for linha in env_file.read_text().splitlines():
        if "=" in linha and not linha.startswith("#"):
            k, _, v = linha.partition("=")
            os.environ.setdefault(k.strip(), v.strip())

SECRET_KEY = os.environ.get("SECRET_KEY") or secrets.token_hex(32)
PORTA      = int(os.environ.get("MONITOR_PORTA", 8180))
CERT_PATH  = os.environ.get("CERT_PATH", "").strip()
KEY_PATH   = os.environ.get("KEY_PATH", "").strip()

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
RE_HOST      = re.compile(r'^[a-zA-Z0-9_.\-]+$')
RE_LOG_NOME  = re.compile(r'^[a-zA-Z0-9_.\-]+\.log$')  # anti path traversal

RE_ANSI = re.compile(r'\x1b\[[0-9;]*m')

ACOES_CONTAINER = {"start", "stop", "restart"}
ACOES_SERVICO   = {"start", "stop", "restart", "reload"}

def _validar_campo(valor: str, pattern: re.Pattern, nome: str) -> str:
    """Retorna o valor limpo ou lança ValueError."""
    if not valor or not pattern.match(valor):
        raise ValueError(f"Valor inválido para {nome}: {valor!r}")
    return valor

# ── Watchlist de Rede (alvos TCP/HTTP monitorados manualmente) ───────────────

def _carregar_watchlist() -> list[dict]:
    try:
        if WATCHLIST_PATH.is_file():
            return json.loads(WATCHLIST_PATH.read_text())
    except (json.JSONDecodeError, OSError) as e:
        logger.error(f"Erro ao ler watchlist: {e}")
    return []


def _salvar_watchlist(itens: list[dict]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    WATCHLIST_PATH.write_text(json.dumps(itens, indent=2, ensure_ascii=False))


_historico_lock = threading.Lock()


def _carregar_historico() -> dict[str, list[float | None]]:
    try:
        if HISTORICO_WATCHLIST_PATH.is_file():
            return json.loads(HISTORICO_WATCHLIST_PATH.read_text())
    except (json.JSONDecodeError, OSError) as e:
        logger.error(f"Erro ao ler histórico da watchlist: {e}")
    return {}


def _salvar_historico(historico: dict[str, list[float | None]]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    HISTORICO_WATCHLIST_PATH.write_text(json.dumps(historico, ensure_ascii=False))


def _registrar_historico(item_id: str, ms: float | None) -> list[float | None]:
    """Acrescenta uma leitura ao histórico do item (mantendo os últimos N) e persiste."""
    with _historico_lock:
        historico = _carregar_historico()
        pontos = historico.get(item_id, [])
        pontos.append(ms)
        pontos = pontos[-HISTORICO_MAX_PONTOS:]
        historico[item_id] = pontos
        _salvar_historico(historico)
        return pontos


def _remover_historico(item_ids: list[str]) -> None:
    with _historico_lock:
        historico = _carregar_historico()
        alterado = False
        for item_id in item_ids:
            if historico.pop(item_id, None) is not None:
                alterado = True
        if alterado:
            _salvar_historico(historico)


def _url_do_alvo(item: dict) -> str:
    """Monta a URL de um alvo HTTP(S).

    Itens novos guardam host/https/caminho/porta separados (o usuário informa só
    o host, sem esquema). Itens antigos guardam uma `url` completa — mantida por
    compatibilidade, com a porta opcional aplicada ao netloc.
    """
    porta = item.get("porta")

    if "url" in item:  # formato legado
        url = item["url"]
        if porta:
            partes = urlparse(url)
            netloc = f"{partes.hostname or ''}:{porta}"
            if partes.username:
                userinfo = partes.username + (f":{partes.password}" if partes.password else "")
                netloc = f"{userinfo}@{netloc}"
            url = urlunparse(partes._replace(netloc=netloc))
        return url

    esquema = "https" if item.get("https", True) else "http"
    host = item["host"]
    netloc = f"{host}:{porta}" if porta else host
    caminho = item.get("caminho") or ""
    if caminho and not caminho.startswith("/"):
        caminho = "/" + caminho
    return urlunparse((esquema, netloc, caminho, "", "", ""))


def _campos_http(item: dict) -> dict:
    """Campos derivados de um alvo HTTP(S) para a resposta da API: host, https,
    porta, caminho e a url completa — normalizando itens no formato legado (`url`).
    """
    if "url" in item:  # legado → decompõe
        partes = urlparse(item["url"])
        return {
            "host": partes.hostname or "",
            "https": partes.scheme == "https",
            "porta": item.get("porta") or partes.port,
            "caminho": partes.path or "",
            "url": _url_do_alvo(item),
        }
    return {
        "host": item["host"],
        "https": bool(item.get("https", True)),
        "porta": item.get("porta"),
        "caminho": item.get("caminho") or "",
        "url": _url_do_alvo(item),
    }


def _motivo_erro(err: object) -> str:
    """Razão de falha legível: mensagens comuns de socket/SSL viram texto curto."""
    texto = str(getattr(err, "strerror", None) or err).strip()
    conhecidas = {
        "Connection refused": "Conexão recusada",
        "No route to host": "Sem rota para o host",
        "Name or service not known": "Host não encontrado (DNS)",
        "nodename nor servname provided, or not known": "Host não encontrado (DNS)",
        "timed out": "Tempo esgotado",
        "Connection reset by peer": "Conexão encerrada pelo host",
        "Network is unreachable": "Rede inacessível",
        "WRONG_VERSION_NUMBER": "A porta não responde HTTPS",
        "UNKNOWN_PROTOCOL": "A porta não responde HTTPS",
        "record layer failure": "A porta não responde HTTPS",
    }
    for chave, traducao in conhecidas.items():
        if chave in texto:
            return traducao
    return texto or "Falha desconhecida"


# Erros de handshake TLS que indicam "a porta existe, mas não fala HTTPS"
# (ex.: apontar HTTPS para porta SSH, MySQL, HTTP puro, etc.).
_ERROS_NAO_TLS = ("WRONG_VERSION_NUMBER", "UNKNOWN_PROTOCOL", "record layer failure")


def _porta_do_alvo(item: dict) -> int | None:
    """Porta efetiva de um alvo HTTP(S): explícita, ou a padrão do esquema."""
    porta = item.get("porta")
    if porta:
        return int(porta)
    if "url" in item:
        p = urlparse(item["url"])
        return p.port or (443 if p.scheme == "https" else 80)
    return 443 if item.get("https", True) else 80


def _tcp_responde(host: str, porta: int) -> bool:
    try:
        with socket.create_connection((host, porta), timeout=3):
            return True
    except OSError:
        return False


def _sugestao_tipo(item: dict, motivo: str) -> str | None:
    """Se o alvo HTTP(S) falhou de um jeito que indica tipo errado e a porta
    responde a TCP puro, sugere trocar o tipo. Retorna None se não há sugestão.
    """
    if item["tipo"] != "http":
        return None
    if not any(marca in motivo for marca in _ERROS_NAO_TLS):
        return None
    porta = _porta_do_alvo(item)
    if porta and _tcp_responde(item.get("host") or urlparse(item.get("url", "")).hostname or "", porta):
        return (
            f"A porta {porta} aceita conexão TCP mas não responde HTTPS. "
            f'Troque o tipo deste alvo para "TCP" (verifica só se a porta está aberta).'
        )
    return None


def _checar_alvo(item: dict) -> dict:
    """Testa alcançabilidade de um alvo TCP ou HTTP(S). Nunca lança exceção."""
    inicio = time.monotonic()
    try:
        if item["tipo"] == "tcp":
            with socket.create_connection((item["host"], item["porta"]), timeout=3):
                pass
            ms = round((time.monotonic() - inicio) * 1000)
            historico = _registrar_historico(item["id"], ms)
            return {"online": True, "detalhe": f"TCP · {ms} ms", "historico": historico}

        url = _url_do_alvo(item)

        # Check de alcançabilidade: aceitamos qualquer certificado TLS. Painéis
        # internos (Crafty, roteadores, NAS) quase sempre usam certificado
        # autoassinado — falhar a verificação marcaria como "offline" um serviço
        # que na verdade está no ar.
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = Request(url, method="GET", headers={"User-Agent": "monitor-web"})
        with urlopen(req, timeout=5, context=ctx) as resp:
            codigo = resp.status
        ms = round((time.monotonic() - inicio) * 1000)
        online = codigo < 400
        historico = _registrar_historico(item["id"], ms if online else None)
        return {"online": online, "detalhe": f"HTTP {codigo} · {ms} ms", "historico": historico}
    except HTTPError as e:
        historico = _registrar_historico(item["id"], None)
        return {"online": e.code < 500, "detalhe": f"HTTP {e.code}", "historico": historico}
    except (URLError, OSError) as e:
        raw = str(getattr(e, "reason", None) or e)
        historico = _registrar_historico(item["id"], None)
        resultado = {
            "online": False,
            "detalhe": _motivo_erro(getattr(e, "reason", None) or e),
            "historico": historico,
        }
        sugestao = _sugestao_tipo(item, raw)
        if sugestao:
            resultado["sugestao"] = sugestao
        return resultado

# ── TLS / HTTPS ────────────────────────────────────────────────────────────────

def _carregar_ssl_context() -> ssl.SSLContext | None:
    """
    Monta o contexto TLS a partir de CERT_PATH/KEY_PATH. Retorna None se as
    variáveis não estiverem configuradas (o servidor sobe em HTTP puro).
    Encerra o processo se estiverem configuradas mas o par cert/chave for
    inválido — nunca sobe silenciosamente sem TLS quando HTTPS foi pedido.
    """
    if not CERT_PATH and not KEY_PATH:
        return None

    cert_path = Path(CERT_PATH)
    key_path  = Path(KEY_PATH)

    if not cert_path.is_file():
        logger.error(f"CERT_PATH configurado mas arquivo não encontrado: {cert_path}")
        raise SystemExit(1)
    if not key_path.is_file():
        logger.error(f"KEY_PATH configurado mas arquivo não encontrado: {key_path}")
        raise SystemExit(1)

    contexto = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    try:
        contexto.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))
    except ssl.SSLError as e:
        logger.error(f"Certificado/chave inválidos ({cert_path}, {key_path}): {e}")
        raise SystemExit(1)

    return contexto

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
    try:
        r = subprocess.run(
            ["sudo", "-S", "-v"],
            input=sudo_pass + "\n",
            capture_output=True, text=True, timeout=5,
            env={**os.environ, "TERM": "dumb"}
        )
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "erro": "Tempo esgotado ao validar senha sudo."}), 500
    except OSError as e:
        logger.error(f"Erro ao executar sudo: {e}")
        return jsonify({"success": False, "erro": "Erro ao executar sudo."}), 500

    if r.returncode != 0:
        return jsonify({"success": False, "erro": "Senha sudo incorreta."}), 400

    logger.info(f"Reinicialização do serviço monitor solicitada por {session.get('usuario')}")
    try:
        # Popen com start_new_session para sobreviver ao SIGTERM do restart
        proc = subprocess.Popen(
            ["sudo", "-S", "systemctl", "restart", "monitor-servidor.service"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        proc.stdin.write((sudo_pass + "\n").encode())
        proc.stdin.close()
    except (OSError, BrokenPipeError) as e:
        logger.error(f"Erro ao reiniciar serviço monitor: {e}")
        return jsonify({"success": False, "erro": f"Erro ao reiniciar serviço: {e}"}), 500
    return jsonify({"success": True})


@app.route("/api/system/reboot", methods=["POST"])
@login_required
def api_reboot():
    dados = request.get_json(silent=True) or {}
    sudo_pass = dados.get("sudo_pass", "")
    if not sudo_pass:
        return jsonify({"success": False, "erro": "Senha sudo é obrigatória."}), 400

    # Verificar senha
    try:
        r = subprocess.run(
            ["sudo", "-S", "-v"],
            input=sudo_pass + "\n",
            capture_output=True, text=True, timeout=5,
            env={**os.environ, "TERM": "dumb"}
        )
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "erro": "Tempo esgotado ao validar senha sudo."}), 500
    except OSError as e:
        logger.error(f"Erro ao executar sudo: {e}")
        return jsonify({"success": False, "erro": "Erro ao executar sudo."}), 500

    if r.returncode != 0:
        return jsonify({"success": False, "erro": "Senha sudo incorreta."}), 400

    logger.warning(f"Reinicialização do SERVIDOR solicitada por {session.get('usuario')}")
    try:
        proc = subprocess.Popen(
            ["sudo", "-S", "reboot"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        proc.stdin.write((sudo_pass + "\n").encode())
        proc.stdin.close()
    except (OSError, BrokenPipeError) as e:
        logger.error(f"Erro ao executar reboot: {e}")
        return jsonify({"success": False, "erro": f"Erro ao executar reboot: {e}"}), 500
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


@app.route("/api/network/watchlist")
@login_required
def api_watchlist():
    itens = _carregar_watchlist()
    resultado = []
    if itens:
        with ThreadPoolExecutor(max_workers=min(8, len(itens))) as executor:
            futuros = {executor.submit(_checar_alvo, item): item for item in itens}
            for futuro in futuros:
                item = futuros[futuro]
                extra = _campos_http(item) if item["tipo"] == "http" else {}
                resultado.append({**item, **extra, **futuro.result()})
    resultado.sort(key=lambda x: x["nome"].lower())
    return jsonify({"watchlist": resultado})


@app.route("/api/network/watchlist", methods=["POST"])
@login_required
def api_watchlist_add():
    dados = request.get_json(silent=True) or {}

    nome = (dados.get("nome") or "").strip()
    tipo = dados.get("tipo")

    if not nome or len(nome) > 80:
        return jsonify({"success": False, "erro": "Nome é obrigatório (até 80 caracteres)."}), 400
    if tipo not in ("tcp", "http"):
        return jsonify({"success": False, "erro": "Tipo inválido. Use tcp ou http."}), 400

    item = {"id": secrets.token_hex(8), "nome": nome, "tipo": tipo}

    if tipo == "tcp":
        host = (dados.get("host") or "").strip()
        if not host or not RE_HOST.match(host):
            return jsonify({"success": False, "erro": "Host inválido."}), 400
        try:
            porta = int(dados.get("porta"))
        except (TypeError, ValueError):
            return jsonify({"success": False, "erro": "Porta inválida."}), 400
        if not (1 <= porta <= 65535):
            return jsonify({"success": False, "erro": "Porta deve estar entre 1 e 65535."}), 400
        item["host"]  = host
        item["porta"] = porta
    else:
        host = (dados.get("host") or "").strip()
        # Tolera colar uma URL completa: extrai só o host (e o esquema, se vier).
        if "://" in host:
            partes = urlparse(host)
            if partes.scheme == "http":
                dados.setdefault("https", False)
            host = partes.hostname or ""
            if partes.port and dados.get("porta") in (None, ""):
                dados["porta"] = partes.port
        if not host or not RE_HOST.match(host):
            return jsonify({"success": False, "erro": "Host inválido."}), 400
        item["host"]  = host
        item["https"] = bool(dados.get("https", True))

        porta_raw = dados.get("porta")
        if porta_raw not in (None, ""):
            try:
                porta = int(porta_raw)
            except (TypeError, ValueError):
                return jsonify({"success": False, "erro": "Porta inválida."}), 400
            if not (1 <= porta <= 65535):
                return jsonify({"success": False, "erro": "Porta deve estar entre 1 e 65535."}), 400
            item["porta"] = porta

        caminho = (dados.get("caminho") or "").strip()
        if caminho:
            if not caminho.startswith("/"):
                caminho = "/" + caminho
            item["caminho"] = caminho

    itens = _carregar_watchlist()
    itens.append(item)
    _salvar_watchlist(itens)

    extra = _campos_http(item) if item["tipo"] == "http" else {}
    return jsonify({"success": True, "item": {**item, **extra, **_checar_alvo(item)}})


@app.route("/api/network/watchlist/<item_id>", methods=["DELETE"])
@login_required
def api_watchlist_delete(item_id):
    itens = _carregar_watchlist()
    novos = [i for i in itens if i.get("id") != item_id]
    if len(novos) == len(itens):
        return jsonify({"success": False, "erro": "Item não encontrado."}), 404
    _salvar_watchlist(novos)
    _remover_historico([item_id])
    return jsonify({"success": True})


# ── Logs de execução (arquivos .log gerados pelos scripts de automação) ──────

_TIPOS_LOG = {
    "atualizacao":    "Atualização do servidor",
    "monitor_update": "Atualização de container",
    "setup_monitor":  "Setup do monitor",
}


def _tipo_log(nome: str) -> str:
    for prefixo, rotulo in _TIPOS_LOG.items():
        if nome.startswith(prefixo):
            return rotulo
    return "Outro"


def _classificar_linha(texto: str) -> str:
    """Espelha process_line() de lib/converter_log_md.sh: nível pelo prefixo."""
    if texto.startswith("[ERRO]"):
        return "erro"
    if texto.startswith("[SUCESSO]"):
        return "sucesso"
    if texto.startswith("[AVISO]"):
        return "aviso"
    if texto.startswith("[INFO]") or texto.startswith("[PROGRESSO]"):
        return "info"
    return "normal"


@app.route("/api/logs")
@login_required
def api_logs():
    try:
        pagina = max(1, int(request.args.get("page", 1)))
    except (TypeError, ValueError):
        pagina = 1

    arquivos = []
    if LOGS_DIR.is_dir():
        for caminho in LOGS_DIR.glob("*.log"):
            if not caminho.is_file():
                continue
            try:
                st = caminho.stat()
            except OSError:
                continue
            arquivos.append({
                "nome": caminho.name,
                "tamanho": st.st_size,
                "modificado": st.st_mtime,
                "tipo": _tipo_log(caminho.name),
            })

    arquivos.sort(key=lambda x: x["modificado"], reverse=True)

    total = len(arquivos)
    total_paginas = max(1, (total + LOGS_POR_PAGINA - 1) // LOGS_POR_PAGINA)
    inicio = (pagina - 1) * LOGS_POR_PAGINA
    fatia = arquivos[inicio:inicio + LOGS_POR_PAGINA]

    return jsonify({
        "logs": fatia,
        "pagina": pagina,
        "total_paginas": total_paginas,
        "total": total,
    })


@app.route("/api/logs/<nome>")
@login_required
def api_log_detalhe(nome):
    if not RE_LOG_NOME.match(nome):
        return jsonify({"erro": "Nome de log inválido"}), 400

    caminho = (LOGS_DIR / nome).resolve()
    if caminho.parent != LOGS_DIR.resolve() or not caminho.is_file():
        return jsonify({"erro": "Log não encontrado"}), 404

    try:
        st = caminho.stat()
        truncado = False
        linhas = []
        with caminho.open("r", encoding="utf-8", errors="replace") as fh:
            bytes_lidos = 0
            for bruta in fh:
                bytes_lidos += len(bruta.encode("utf-8", errors="replace"))
                texto = RE_ANSI.sub("", bruta.rstrip("\n"))
                linhas.append({"texto": texto, "nivel": _classificar_linha(texto)})
                if len(linhas) >= LOG_MAX_LINHAS or bytes_lidos >= LOG_MAX_BYTES:
                    truncado = True
                    break
    except OSError as e:
        logger.error(f"Erro ao ler log {nome}: {e}")
        return jsonify({"erro": "Erro ao ler o log"}), 500

    return jsonify({
        "nome": nome,
        "tamanho": st.st_size,
        "modificado": st.st_mtime,
        "truncado": truncado,
        "linhas": linhas,
    })


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
    ssl_context = _carregar_ssl_context()
    esquema = "https" if ssl_context else "http"
    logger.info(f"Monitor iniciando na porta {PORTA} ({esquema.upper()})...")
    logger.info(f"Acesse: {esquema}://0.0.0.0:{PORTA}")
    app.run(host="0.0.0.0", port=PORTA, debug=False, ssl_context=ssl_context)
