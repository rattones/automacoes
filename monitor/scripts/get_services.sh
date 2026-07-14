#!/bin/bash

#########################################
# Coleta de Serviços systemd Ativos
# Saída: JSON
#########################################

set -euo pipefail

# Toda a coleta é feita via Python/subprocess para evitar interpolação
# de JSON em strings literais Python (quebra com backslashes).
python3 - <<'PYEOF'
import json, subprocess, re, shutil

FILTRO_EXCLUIR = re.compile(
    r'snapd|dbus|accounts|acpid|apport|blk-availability|console|cryptdisk|dev-|'
    r'e2scrub|finalrd|fstrim|getty|grub|ifup|initrd|keyboard|logrotate|lvm|'
    r'mdadm|motd|multipathd|networkd-dispatcher|packagekit|plymouth|polkit|'
    r'remote-fs|rsyslog|rtkit|setvtrgb|smartd|sysstat|udev|udisks|unattended|'
    r'upower|user@|var-|apparmor|apt-daily|atd|blk-|boot-|emergency|exit-disks|'
    r'final-|hostname|hwclock|kmod|ldconfig|magic|modprobe|mount-|open-iscsi|'
    r'proc-|quotacheck|rc-local|reboot|rescue|shutdown|swap|sysinit|sys-|'
    r'time-sync|tmp-|ureadahead|ctrl-alt',
    re.IGNORECASE
)

# ── Pacotes com atualizações disponíveis ──────────────────────────────────────
pkgs_atualizaveis = {}
try:
    r = subprocess.run(["apt", "list", "--upgradable"],
                       capture_output=True, text=True, timeout=30)
    for linha in r.stdout.splitlines():
        if linha.startswith('Listing'):
            continue
        m = re.match(r'^([^/]+)/\S+\s+(\S+)', linha)
        if m:
            pkgs_atualizaveis[m.group(1)] = m.group(2)
except Exception:
    pass

# ── Listar serviços (ativos, com falha e parados) ─────────────────────────────
# "list-units --all" só enxerga unidades já carregadas ao menos uma vez pelo
# systemd nesta sessão; serviços instalados mas nunca carregados (ex: desabilitados
# desde o boot) não aparecem ali. Por isso complementamos com "list-unit-files",
# que traz todo o catálogo instalado, para não perder serviços parados.
try:
    r = subprocess.run(
        ["systemctl", "list-units", "--type=service",
         "--all", "--output=json", "--no-pager"],
        capture_output=True, text=True, timeout=10
    )
    carregadas = json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else []
except Exception:
    carregadas = []

unidades_por_nome = {u.get("unit", ""): u for u in carregadas}

def eh_template(nome):
    # unidades tipo "foo@.service" (sem instância) não são start/stop-áveis diretamente
    return nome[:-len(".service")].endswith("@")

try:
    r = subprocess.run(
        ["systemctl", "list-unit-files", "--type=service",
         "--no-legend", "--no-pager"],
        capture_output=True, text=True, timeout=10
    )
    linhas_arquivos = r.stdout.splitlines() if r.returncode == 0 else []
except Exception:
    linhas_arquivos = []

nomes_instalados = set()
for linha in linhas_arquivos:
    partes = linha.split()
    if len(partes) < 2:
        continue
    nome_arquivo, estado_arquivo = partes[0], partes[1]
    if estado_arquivo not in ("enabled", "disabled"):
        continue
    if not nome_arquivo.endswith(".service") or eh_template(nome_arquivo):
        continue
    nomes_instalados.add(nome_arquivo)

# Unidades carregadas + unidades instaladas (enabled/disabled) nunca carregadas
nomes_finais = set(unidades_por_nome.keys()) | nomes_instalados

# Buscar estado das que só existem no catálogo (nunca carregadas) em uma única chamada
nomes_sem_dado = sorted(n for n in nomes_instalados if n not in unidades_por_nome)
if nomes_sem_dado:
    try:
        r = subprocess.run(
            ["systemctl", "show"] + nomes_sem_dado +
            ["--property=Id,Description,ActiveState,SubState", "--no-pager"],
            capture_output=True, text=True, timeout=10
        )
        blocos = r.stdout.split("\n\n") if r.returncode == 0 else []
        for bloco in blocos:
            props = dict(l.split("=", 1) for l in bloco.splitlines() if "=" in l)
            nome_id = props.get("Id", "")
            if nome_id:
                unidades_por_nome[nome_id] = {
                    "unit": nome_id,
                    "description": props.get("Description", ""),
                    "active": props.get("ActiveState", "inactive"),
                    "sub": props.get("SubState", "dead"),
                }
    except Exception:
        pass

unidades = [unidades_por_nome[n] for n in nomes_finais if n in unidades_por_nome]

def get_versao(nome):
    try:
        r = subprocess.run(["dpkg", "-l", nome],
                           capture_output=True, text=True, timeout=3)
        for linha in r.stdout.splitlines():
            if linha.startswith('ii'):
                partes = linha.split()
                if len(partes) >= 3:
                    return partes[2]
    except Exception:
        pass
    bin_path = shutil.which(nome)
    if bin_path:
        for flag in ['--version', '-v', '-V', 'version']:
            try:
                r = subprocess.run([nome, flag],
                                   capture_output=True, text=True, timeout=2)
                saida = (r.stdout + r.stderr).strip()
                m = re.search(r'(\d+\.\d+[\.\d]*)', saida)
                if m:
                    return m.group(1)
            except Exception:
                pass
    return None

def pkg_para_servico(nome):
    base = re.sub(r'\.service$', '', nome)
    base = base.split('@')[0]
    base = re.sub(r'-\d+$', '', base)
    return base

resultado = []
for u in unidades:
    nome = u.get("unit", "")
    if not nome.endswith(".service"):
        continue
    if FILTRO_EXCLUIR.search(nome):
        continue

    descricao  = u.get("description", "")
    estado     = u.get("active", "unknown")
    sub_estado = u.get("sub", "")
    pkg        = pkg_para_servico(nome)
    versao     = get_versao(pkg if pkg else nome)
    atualizavel  = pkg in pkgs_atualizaveis
    versao_nova  = pkgs_atualizaveis.get(pkg, None)

    resultado.append({
        "nome":        nome,
        "descricao":   descricao,
        "estado":      estado,
        "sub_estado":  sub_estado,
        "versao":      versao,
        "atualizavel": atualizavel,
        "versao_nova": versao_nova,
        "pkg":         pkg
    })

ORDEM_ESTADO = {"failed": 0, "active": 1}
resultado.sort(key=lambda x: (ORDEM_ESTADO.get(x["estado"], 2), x["nome"]))
print(json.dumps(resultado, indent=2))
PYEOF
