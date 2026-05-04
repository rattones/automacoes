#!/bin/bash

#########################################
# Coleta de Métricas: CPU / GPU / RAM / Disco / Uptime
# Saída: JSON
#########################################

set -euo pipefail

# ── CPU ───────────────────────────────────────────────────────────────────────
get_cpu() {
    # Lê /proc/stat duas vezes com 500ms de intervalo para calcular % real
    read_stat() { awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8}' /proc/stat; }

    stat1=$(read_stat)
    sleep 0.5
    stat2=$(read_stat)

    python3 - <<PYEOF
s1 = list(map(int, "$stat1".split()))
s2 = list(map(int, "$stat2".split()))
d = [b-a for a,b in zip(s1,s2)]
idle  = d[3]
total = sum(d)
uso   = round((1 - idle/total) * 100, 1) if total > 0 else 0
print(uso)
PYEOF
}

# Número de núcleos
cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Desconhecido")
cpu_uso=$(get_cpu)

# Frequência atual (MHz) — pode não existir em VMs
cpu_freq="null"
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    freq_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
    cpu_freq=$(( freq_khz / 1000 ))
fi

# Temperatura da CPU (via thermal_zone0 ou coretemp)
cpu_temp="null"
for zone in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$zone" ]; then
        t=$(cat "$zone" 2>/dev/null || echo 0)
        # Filtrar leituras razoáveis (entre 10°C e 120°C)
        t_c=$(( t / 1000 ))
        if [ "$t_c" -gt 10 ] && [ "$t_c" -lt 120 ]; then
            cpu_temp=$t_c
            break
        fi
    fi
done

# ── GPU ───────────────────────────────────────────────────────────────────────
gpu_info="null"

if command -v nvidia-smi &>/dev/null; then
    # NVIDIA
    raw=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
        --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "")
    if [ -n "$raw" ]; then
        gpu_name=$(echo "$raw" | cut -d, -f1 | xargs)
        gpu_uso_pct=$(echo "$raw" | cut -d, -f2 | xargs)
        gpu_mem_usado=$(echo "$raw" | cut -d, -f3 | xargs)
        gpu_mem_total=$(echo "$raw" | cut -d, -f4 | xargs)
        gpu_temp=$(echo "$raw" | cut -d, -f5 | xargs)
        gpu_info="{\"tipo\":\"nvidia\",\"nome\":\"${gpu_name}\",\"uso\":${gpu_uso_pct},\"mem_usado_mb\":${gpu_mem_usado},\"mem_total_mb\":${gpu_mem_total},\"temperatura\":${gpu_temp}}"
    fi
elif command -v rocm-smi &>/dev/null; then
    # AMD via ROCm
    gpu_uso_pct=$(rocm-smi --showuse 2>/dev/null | grep -oP '\d+(?=%)' | head -1 || echo 0)
    gpu_temp=$(rocm-smi --showtemp 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo 0)
    gpu_name=$(rocm-smi --showproductname 2>/dev/null | awk '/Card series/ {print $NF}' | head -1 || echo "AMD GPU")
    gpu_info="{\"tipo\":\"amd\",\"nome\":\"${gpu_name}\",\"uso\":${gpu_uso_pct},\"temperatura\":${gpu_temp}}"
elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then
    # AMD via sysfs (sem ROCm)
    gpu_uso_pct=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0)
    gpu_name="AMD GPU"
    gpu_info="{\"tipo\":\"amd_sysfs\",\"nome\":\"${gpu_name}\",\"uso\":${gpu_uso_pct}}"
elif command -v intel_gpu_top &>/dev/null; then
    # Intel
    raw=$(timeout 1 intel_gpu_top -J -s 500 2>/dev/null | python3 -c "
import sys,json
for line in sys.stdin:
    try:
        d=json.loads(line.strip().rstrip(','))
        if 'engines' in d:
            # soma todos os engines
            total=sum(e.get('busy',0) for e in d['engines'].values() if isinstance(e,dict))
            count=len([e for e in d['engines'].values() if isinstance(e,dict)])
            print(round(total/count,1) if count else 0)
            break
    except: pass
" 2>/dev/null || echo 0)
    gpu_info="{\"tipo\":\"intel\",\"nome\":\"Intel GPU\",\"uso\":${raw}}"
fi

# ── MEMÓRIA ───────────────────────────────────────────────────────────────────
mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_livre=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
mem_usado=$(( mem_total - mem_livre ))
mem_uso_pct=$(python3 -c "print(round($mem_usado/$mem_total*100,1))")
# kB → bytes
mem_total_b=$(( mem_total * 1024 ))
mem_usado_b=$(( mem_usado * 1024 ))

swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
swap_livre=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
swap_usado=$(( swap_total - swap_livre ))
swap_uso_pct=0
if [ "$swap_total" -gt 0 ]; then
    swap_uso_pct=$(python3 -c "print(round($swap_usado/$swap_total*100,1))")
fi

# ── DISCO ─────────────────────────────────────────────────────────────────────
disco_info=$(python3 - <<'PYEOF'
import subprocess, json
try:
    r = subprocess.run(
        ["df", "-B1", "--output=source,size,used,avail,pcent,target"],
        capture_output=True, text=True, timeout=10
    )
    linhas = r.stdout.splitlines()[1:]
except Exception:
    linhas = []
discos = []
for linha in linhas:
    partes = linha.split()
    if not partes or partes[0] in ('tmpfs', 'devtmpfs', 'udev', 'none'):
        continue
    if len(partes) >= 6:
        try:
            discos.append({
                "device":  partes[0],
                "total":   int(partes[1]),
                "usado":   int(partes[2]),
                "livre":   int(partes[3]),
                "uso_pct": float(partes[4].rstrip('%')),
                "ponto":   partes[5]
            })
        except (ValueError, IndexError):
            pass
print(json.dumps(discos))
PYEOF
)

# ── UPTIME / LOAD ─────────────────────────────────────────────────────────────
uptime_seg=$(awk '{print int($1)}' /proc/uptime)
load_avg=$(cat /proc/loadavg | awk '{print $1,$2,$3}')
load1=$(echo $load_avg | cut -d' ' -f1)
load5=$(echo $load_avg | cut -d' ' -f2)
load15=$(echo $load_avg | cut -d' ' -f3)
hostname=$(hostname)
kernel=$(uname -r)

# ── SAÍDA JSON ────────────────────────────────────────────────────────────────
cat <<EOF
{
  "cpu": {
    "uso": ${cpu_uso},
    "nucleos": ${cpu_cores},
    "modelo": $(python3 -c "import json; print(json.dumps('${cpu_model}'))"),
    "frequencia_mhz": ${cpu_freq},
    "temperatura": ${cpu_temp}
  },
  "gpu": ${gpu_info},
  "memoria": {
    "total": ${mem_total_b},
    "usado": ${mem_usado_b},
    "uso_pct": ${mem_uso_pct},
    "swap_total": $(( swap_total * 1024 )),
    "swap_usado": $(( swap_usado * 1024 )),
    "swap_uso_pct": ${swap_uso_pct}
  },
  "disco": ${disco_info},
  "sistema": {
    "hostname": $(python3 -c "import json; print(json.dumps('${hostname}'))"),
    "kernel": $(python3 -c "import json; print(json.dumps('${kernel}'))"),
    "uptime_seg": ${uptime_seg},
    "load_1m": ${load1},
    "load_5m": ${load5},
    "load_15m": ${load15}
  }
}
EOF
