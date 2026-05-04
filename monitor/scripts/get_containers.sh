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
        "id":              c.get("ID", c.get("Id", ""))[:12],
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
        "compose_dir":     compose_dir
    })

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
