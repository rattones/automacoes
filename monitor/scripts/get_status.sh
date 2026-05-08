#!/bin/bash

#########################################
# Coleta de Métricas: CPU / GPU / RAM / Disco / Uptime
# Saída: JSON
#########################################

set -euo pipefail

# ── CPU ───────────────────────────────────────────────────────────────────────
cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Desconhecido")

# Coleta uso geral + por núcleo em uma única leitura de /proc/stat
cpu_json=$(python3 - <<'PYEOF'
import json, time, glob

def read_stat():
    r = {}
    with open('/proc/stat') as f:
        for line in f:
            if not line.startswith('cpu'): continue
            p = line.split()
            r[p[0]] = list(map(int, p[1:8]))
    return r

s1 = read_stat()
time.sleep(0.5)
s2 = read_stat()

def uso(key):
    if key not in s1 or key not in s2: return 0.0
    d = [b - a for a, b in zip(s1[key], s2[key])]
    idle = d[3]; tot = sum(d)
    return round((1 - idle / tot) * 100, 1) if tot > 0 else 0.0

cores = [{'id': int(k[3:]), 'uso': uso(k)} for k in sorted(s1) if k[3:].isdigit()]

# Temperaturas por núcleo via Intel coretemp
for f in sorted(glob.glob('/sys/devices/platform/coretemp.*/hwmon/hwmon*/temp*_label')):
    try:
        label = open(f).read().strip()
        if not label.startswith('Core'): continue
        num = int(label.split()[1])
        val = int(open(f.replace('_label', '_input')).read().strip())
        for c in cores:
            if c['id'] == num:
                c['temp'] = val // 1000
    except Exception:
        pass

print(json.dumps({'uso': uso('cpu'), 'cores': cores}))
PYEOF
)

cpu_uso=$(echo "$cpu_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['uso'])")
cpu_cores_data=$(echo "$cpu_json" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['cores']))")

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
    raw=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,memory.free,temperature.gpu,driver_version \
        --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "")
    if [ -n "$raw" ]; then
        gpu_name=$(echo "$raw" | cut -d, -f1 | xargs)
        gpu_uso_pct=$(echo "$raw" | cut -d, -f2 | xargs)
        gpu_mem_usado=$(echo "$raw" | cut -d, -f3 | xargs)
        gpu_mem_total=$(echo "$raw" | cut -d, -f4 | xargs)
        gpu_mem_livre=$(echo "$raw" | cut -d, -f5 | xargs)
        gpu_temp=$(echo "$raw" | cut -d, -f6 | xargs)
        gpu_driver=$(echo "$raw" | cut -d, -f7 | xargs)
        gpu_info="{\"tipo\":\"nvidia\",\"nome\":\"${gpu_name}\",\"uso\":${gpu_uso_pct},\"mem_usado_mb\":${gpu_mem_usado},\"mem_total_mb\":${gpu_mem_total},\"mem_livre_mb\":${gpu_mem_livre},\"temperatura\":${gpu_temp},\"driver_version\":\"${gpu_driver}\"}"
    fi
elif command -v rocm-smi &>/dev/null; then
    # AMD via ROCm
    gpu_uso_pct=$(rocm-smi --showuse 2>/dev/null | grep -oP '\d+(?=%)' | head -1 || echo 0)
    gpu_temp=$(rocm-smi --showtemp 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo 0)
    gpu_name=$(rocm-smi --showproductname 2>/dev/null | awk '/Card series/ {print $NF}' | head -1 || echo "AMD GPU")
    gpu_driver=$(rocm-smi --showdriverversion 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "")
    gpu_driver_json=$([ -n "$gpu_driver" ] && echo "\"${gpu_driver}\"" || echo "null")
    gpu_info="{\"tipo\":\"amd\",\"nome\":\"${gpu_name}\",\"uso\":${gpu_uso_pct},\"temperatura\":${gpu_temp},\"driver_version\":${gpu_driver_json}}"
elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then
    # AMD via sysfs (sem ROCm)
    gpu_uso_pct=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0)
    gpu_name="AMD GPU"
    gpu_mem_usado_b=$(cat /sys/class/drm/card0/device/mem_info_vram_used 2>/dev/null || echo "")
    gpu_mem_total_b=$(cat /sys/class/drm/card0/device/mem_info_vram_total 2>/dev/null || echo "")
    gpu_mem_usado_mb="null"; gpu_mem_total_mb="null"; gpu_mem_livre_mb="null"
    if [ -n "$gpu_mem_total_b" ] && [ "${gpu_mem_total_b:-0}" -gt 0 ] 2>/dev/null; then
        gpu_mem_total_mb=$(( gpu_mem_total_b / 1048576 ))
        gpu_mem_usado_mb=$(( ${gpu_mem_usado_b:-0} / 1048576 ))
        gpu_mem_livre_mb=$(( gpu_mem_total_mb - gpu_mem_usado_mb ))
    fi
    gpu_driver_file="/sys/class/drm/card0/device/driver/module/version"
    gpu_driver_json="null"
    [ -f "$gpu_driver_file" ] && gpu_driver_json="\"$(cat "$gpu_driver_file" 2>/dev/null | xargs)\""
    gpu_info="{\"tipo\":\"amd_sysfs\",\"nome\":\"${gpu_name}\",\"uso\":${gpu_uso_pct},\"mem_usado_mb\":${gpu_mem_usado_mb},\"mem_total_mb\":${gpu_mem_total_mb},\"mem_livre_mb\":${gpu_mem_livre_mb},\"driver_version\":${gpu_driver_json}}"
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
    gpu_driver_file="/sys/class/drm/card0/device/driver/module/version"
    gpu_driver_json="null"
    [ -f "$gpu_driver_file" ] && gpu_driver_json="\"$(cat "$gpu_driver_file" 2>/dev/null | xargs)\""
    gpu_info="{\"tipo\":\"intel\",\"nome\":\"Intel GPU\",\"uso\":${raw},\"driver_version\":${gpu_driver_json}}"
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

# ── DIMMS DE MEMÓRIA ──────────────────────────────────────────────────────────
dimms_data=$(python3 - <<'PYEOF'
import subprocess, json, re, glob

def run_dmi():
    for cmd in [['dmidecode', '-t', 'memory'], ['sudo', '-n', 'dmidecode', '-t', 'memory']]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if r.returncode == 0 and 'Memory Device' in r.stdout:
                return r.stdout
        except Exception:
            pass
    return ''

raw = run_dmi()
dimms = []

for bloco in raw.split('\nMemory Device\n'):
    if 'Size:' not in bloco:
        continue

    def campo(label):
        m = re.search(rf'^\s*{label}:\s*(.+)$', bloco, re.MULTILINE)
        return m.group(1).strip() if m else ''

    size_str = campo('Size')
    if not size_str or 'No Module' in size_str or size_str == 'Unknown':
        continue

    tamanho_mb = None
    m = re.match(r'(\d+)\s*(MB|GB)', size_str, re.I)
    if m:
        tamanho_mb = int(m.group(1)) if m.group(2).upper() == 'MB' else int(m.group(1)) * 1024

    def parse_mts(s):
        m = re.search(r'(\d+)', s)
        return int(m.group(1)) if m else None

    fab = campo('Manufacturer')
    modelo = campo('Part Number')
    locator = campo('Locator')

    for ruido in ('Unknown', 'Not Specified', ''):
        if fab == ruido: fab = ''
        if modelo == ruido: modelo = ''

    # Temperatura via hwmon (labels DIMM* ou DDR*)
    temp = None
    for lf in sorted(glob.glob('/sys/class/hwmon/hwmon*/temp*_label')):
        try:
            label = open(lf).read().strip().upper()
            if 'DIMM' in label or 'DDR' in label:
                val = int(open(lf.replace('_label', '_input')).read().strip())
                temp = val // 1000
                break
        except Exception:
            pass

    dimms.append({
        'locator': locator,
        'tamanho_mb': tamanho_mb,
        'velocidade_mts': parse_mts(campo('Speed')),
        'velocidade_config_mts': parse_mts(campo('Configured Memory Speed')),
        'fabricante': fab,
        'modelo': modelo.strip(),
        'temperatura': temp,
    })

print(json.dumps(dimms))
PYEOF
)

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
    "temperatura": ${cpu_temp},
    "cores": ${cpu_cores_data}
  },
  "gpu": ${gpu_info},
  "memoria": {
    "total": ${mem_total_b},
    "usado": ${mem_usado_b},
    "uso_pct": ${mem_uso_pct},
    "swap_total": $(( swap_total * 1024 )),
    "swap_usado": $(( swap_usado * 1024 )),
    "swap_uso_pct": ${swap_uso_pct},
    "dimms": ${dimms_data}
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
