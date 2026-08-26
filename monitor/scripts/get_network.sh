#!/bin/bash

#########################################
# Coleta de Dados de Rede
# Saída: JSON com interfaces, IPs, serviços por porta, uso rx/tx
#########################################

set -euo pipefail

# Toda a coleta é feita via Python/subprocess para evitar conflito
# entre pipe e heredoc (stdin conflict → SIGPIPE 141).
python3 - <<'PYEOF'
import json, subprocess, re, time

# ── Interfaces e IPs ──────────────────────────────────────────────────────────
try:
    r = subprocess.run(["ip", "-j", "addr", "show"],
                       capture_output=True, text=True, timeout=5)
    ifaces_raw = json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else []
except Exception:
    ifaces_raw = []

ifaces = []
for iface in ifaces_raw:
    enderecos = []
    for addr in iface.get("addr_info", []):
        enderecos.append({
            "ip":      addr.get("local", ""),
            "prefixo": addr.get("prefixlen", 0),
            "familia": addr.get("family", "")
        })
    ifaces.append({
        "nome":      iface.get("ifname", ""),
        "estado":    iface.get("operstate", "UNKNOWN").lower(),
        "mac":       iface.get("address", ""),
        "enderecos": enderecos
    })

# ── Resolução de serviço systemd a partir do PID ──────────────────────────────
# Lê /proc/<pid>/cgroup diretamente (leitura de arquivo, sem spawnar processo)
# em vez de rodar "systemctl status <pid>" por porta — em hosts com centenas/
# milhares de sockets em escuta (Docker, Samba, etc.), um subprocess por PID
# facilmente estoura o timeout da API (10s). Resultado cacheado por PID, já
# que o mesmo processo pode aparecer em várias linhas do ss.
RE_SERVICE = re.compile(r'([^/]+\.service)$')
_cache_servico: dict[int, str] = {}

def _servico_de_pid(pid: int) -> str:
    if pid in _cache_servico:
        return _cache_servico[pid]
    nome = ""
    try:
        with open(f"/proc/{pid}/cgroup") as f:
            conteudo = f.read()
        m = RE_SERVICE.search(conteudo)
        if m:
            nome = m.group(1)
    except Exception:
        pass
    _cache_servico[pid] = nome
    return nome

# ── Serviços escutando por porta/IP ───────────────────────────────────────────
try:
    r = subprocess.run(["sudo", "ss", "-tlnp"],
                       capture_output=True, text=True, timeout=5)
    linhas = r.stdout.splitlines()
except Exception:
    linhas = []

servicos = []
for linha in linhas[1:]:
    partes = linha.split()
    if len(partes) < 4:
        continue
    estado = partes[0]
    local  = partes[3]
    m = re.match(r'^(?:\[([^\]]+)\]|([^:]+)):(\d+)$', local)
    if m:
        ip    = m.group(1) or m.group(2)
        porta = int(m.group(3))
    else:
        parts2 = local.rsplit(':', 1)
        ip = parts2[0] if len(parts2) == 2 else local
        try:
            porta = int(parts2[1]) if len(parts2) == 2 else 0
        except ValueError:
            porta = 0

    processo = ""
    pid = None
    if len(partes) >= 6:
        proc_raw = ' '.join(partes[5:])
        m_proc = re.search(r'"([^"]+)"', proc_raw)
        m_pid  = re.search(r'pid=(\d+)', proc_raw)
        if m_proc:
            processo = m_proc.group(1)
        if m_pid:
            pid = int(m_pid.group(1))

    servico_nome = _servico_de_pid(pid) if pid else ""

    servicos.append({
        "ip":       ip,
        "porta":    porta,
        "processo": processo,
        "pid":      pid,
        "servico":  servico_nome,
        "estado":   estado
    })

# ── Uso de rede (rx/tx em Mbps) ───────────────────────────────────────────────
def ler_stats():
    stats = {}
    try:
        with open("/proc/net/dev") as f:
            for linha in f:
                if ':' not in linha:
                    continue
                iface, dados = linha.split(':', 1)
                iface = iface.strip()
                vals  = dados.split()
                if len(vals) >= 10:
                    stats[iface] = {"rx": int(vals[0]), "tx": int(vals[8])}
    except Exception:
        pass
    return stats

s1 = ler_stats()
time.sleep(1)
s2 = ler_stats()

uso_rede = {}
for iface in s1:
    if iface in s2:
        rx_bytes = s2[iface]["rx"] - s1[iface]["rx"]
        tx_bytes = s2[iface]["tx"] - s1[iface]["tx"]
        uso_rede[iface] = {
            "rx_mbps":        round(rx_bytes * 8 / 1_000_000, 3),
            "tx_mbps":        round(tx_bytes * 8 / 1_000_000, 3),
            "rx_bytes_total": s2[iface]["rx"],
            "tx_bytes_total": s2[iface]["tx"]
        }

# ── Saída JSON ────────────────────────────────────────────────────────────────
print(json.dumps({
    "interfaces": ifaces,
    "servicos":   servicos,
    "uso_rede":   uso_rede
}, indent=2))
PYEOF
