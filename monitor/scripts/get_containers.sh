#!/bin/bash

#########################################
# Coleta de Containers Docker
# Saída: JSON
#########################################

set -euo pipefail

# Caminhos conhecidos de stacks Docker Compose
COMPOSE_DIRS=(
    "/home/rattones/crafty"
    "/home/rattones/haos"
)

if ! command -v docker &>/dev/null; then
    echo '{"erro": "Docker não disponível", "containers": [], "stacks": []}'
    exit 0
fi

if ! docker info &>/dev/null 2>&1; then
    echo '{"erro": "Docker daemon não está rodando", "containers": [], "stacks": []}'
    exit 0
fi

# Toda a coleta é feita via Python/subprocess para evitar interpolação
# de JSON em strings Python (quebra com backslashes e caracteres especiais).
COMPOSE_DIRS_STR="${COMPOSE_DIRS[*]}"

python3 - "$COMPOSE_DIRS_STR" <<'PYEOF'
import json, subprocess, os, re, sys

compose_dirs = sys.argv[1].split() if len(sys.argv) > 1 else []

# ── Containers ────────────────────────────────────────────────────────────────
containers = []
try:
    r = subprocess.run(
        ["docker", "ps", "-a", "--format", "{{json .}}"],
        capture_output=True, text=True, timeout=10
    )
    linhas = r.stdout.strip().splitlines()
except Exception:
    linhas = []

for linha in linhas:
    if not linha.strip():
        continue
    try:
        c = json.loads(linha)
    except json.JSONDecodeError:
        continue

    imagem = c.get("Image", "")
    imagem_partes = imagem.split(":")
    imagem_nome = imagem_partes[0]
    imagem_tag  = imagem_partes[1] if len(imagem_partes) > 1 else "latest"

    id_imagem = ""
    try:
        r2 = subprocess.run(
            ["docker", "image", "inspect", imagem, "--format", "{{.Id}}"],
            capture_output=True, text=True, timeout=3
        )
        id_imagem = r2.stdout.strip()[:12] if r2.stdout.strip() else ""
    except Exception:
        pass

    # "docker ps" só dá o ID curto (12 chars); o ID completo é necessário
    # para montar o path do cgroup (leitura de swap, mais abaixo).
    id_curto = c.get("ID", c.get("Id", ""))
    id_completo = id_curto
    try:
        r3 = subprocess.run(
            ["docker", "inspect", id_curto, "--format", "{{.Id}}"],
            capture_output=True, text=True, timeout=3
        )
        if r3.stdout.strip():
            id_completo = r3.stdout.strip()
    except Exception:
        pass

    labels_raw = c.get("Labels", {})
    if isinstance(labels_raw, str):
        labels_dict = {}
        for kv in labels_raw.split(","):
            kv = kv.strip()
            if "=" in kv:
                k, v = kv.split("=", 1)
                labels_dict[k] = v
    else:
        labels_dict = labels_raw if isinstance(labels_raw, dict) else {}

    compose_project = labels_dict.get("com.docker.compose.project", "")
    compose_service = labels_dict.get("com.docker.compose.service", "")
    compose_dir     = labels_dict.get("com.docker.compose.project.working_dir", "")

    estado_raw = c.get("State", c.get("Status", "unknown")).lower()
    if "up" in estado_raw or "running" in estado_raw:
        estado = "running"
    elif "exit" in estado_raw:
        estado = "exited"
    elif "paus" in estado_raw:
        estado = "paused"
    elif "restart" in estado_raw:
        estado = "restarting"
    else:
        estado = estado_raw

    containers.append({
        "id":              id_curto,
        "id_completo":     id_completo,
        "nome":            c.get("Names", c.get("Name", "")).lstrip("/"),
        "imagem":          imagem,
        "imagem_nome":     imagem_nome,
        "imagem_tag":      imagem_tag,
        "imagem_id":       id_imagem,
        "estado":          estado,
        "status_texto":    c.get("Status", ""),
        "criado":          c.get("CreatedAt", c.get("Created", "")),
        "portas":          c.get("Ports", ""),
        "compose_project": compose_project,
        "compose_service": compose_service,
        "compose_dir":     compose_dir,
        "stats":           None
    })

# ── Stats de uso de recursos (CPU/Mem/Rede/Disco/Swap) ─────────────────────────
# Uma única chamada a "docker stats" cobre todos os containers de uma vez —
# evita repetir o padrão de "uma subprocess por container" usado acima para
# docker image inspect. Qualquer falha aqui não deve derrubar a coleta de
# metadados já feita: cada container simplesmente fica com stats=None.

def parse_tamanho(s):
    # Converte strings como "1.093GiB", "184MB", "0B" para bytes (int).
    m = re.match(r"^([\d.]+)\s*([a-zA-Z]*)$", s.strip())
    if not m:
        return None
    valor, unidade = float(m.group(1)), m.group(2).lower()
    fatores = {
        "b": 1,
        "kb": 1000, "mb": 1000**2, "gb": 1000**3, "tb": 1000**4,
        "kib": 1024, "mib": 1024**2, "gib": 1024**3, "tib": 1024**4,
    }
    return int(valor * fatores.get(unidade, 1))

def parse_par(s, conv=parse_tamanho):
    # "1.093GiB / 15.56GiB" -> (bytes_usado, bytes_total)
    partes = [p.strip() for p in s.split("/")]
    if len(partes) != 2:
        return None, None
    return conv(partes[0]), conv(partes[1])

stats_por_id = {}
try:
    r = subprocess.run(
        ["docker", "stats", "--no-stream", "--format", "{{json .}}"],
        capture_output=True, text=True, timeout=8
    )
    for linha in r.stdout.strip().splitlines():
        if not linha.strip():
            continue
        try:
            s = json.loads(linha)
        except json.JSONDecodeError:
            continue

        cpu_pct = None
        m = re.match(r"^([\d.]+)%$", s.get("CPUPerc", "").strip())
        if m:
            cpu_pct = float(m.group(1))

        mem_usado, mem_limite = parse_par(s.get("MemUsage", ""))
        mem_pct = None
        m = re.match(r"^([\d.]+)%$", s.get("MemPerc", "").strip())
        if m:
            mem_pct = float(m.group(1))

        net_rx, net_tx = parse_par(s.get("NetIO", ""))
        disco_leitura, disco_escrita = parse_par(s.get("BlockIO", ""))

        stats_por_id[s.get("ID", "")] = {
            "cpu_pct":       cpu_pct,
            "mem_usado":     mem_usado,
            "mem_limite":    mem_limite,
            "mem_pct":       mem_pct,
            "net_rx":        net_rx,
            "net_tx":        net_tx,
            "disco_leitura": disco_leitura,
            "disco_escrita": disco_escrita,
            "swap_usado":    None,
        }
except Exception:
    stats_por_id = {}

for c in containers:
    st = stats_por_id.get(c["id"])
    if st is None or c["estado"] != "running":
        continue

    # Swap não vem do "docker stats" — lido diretamente do cgroup v2.
    # O caminho depende do driver systemd/cgroup do host (confirmado neste
    # ambiente); se não existir (outro driver, outro slice), fica None.
    try:
        cgroup_path = f"/sys/fs/cgroup/system.slice/docker-{c['id_completo']}.scope/memory.swap.current"
        with open(cgroup_path) as f:
            st["swap_usado"] = int(f.read().strip())
    except Exception:
        pass

    c["stats"] = st

# ── Stacks Compose ────────────────────────────────────────────────────────────
stacks = []
for d in compose_dirs:
    for fname in ["compose.yml", "compose.yaml", "docker-compose.yml", "docker-compose.yaml"]:
        compose_file = os.path.join(d, fname)
        if os.path.isfile(compose_file):
            nome_stack = os.path.basename(d)
            containers_stack = [
                c for c in containers
                if c["compose_dir"] == d or c["compose_project"] == nome_stack
            ]
            stacks.append({
                "nome":       nome_stack,
                "diretorio":  d,
                "arquivo":    compose_file,
                "containers": [c["nome"] for c in containers_stack]
            })
            break

print(json.dumps({"containers": containers, "stacks": stacks}, indent=2))
PYEOF
