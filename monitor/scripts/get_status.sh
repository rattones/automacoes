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

# ── GPUs (multi-GPU via lshw + sysfs/nvidia-smi) ────────────────────────────
gpus_data=$(python3 - <<'PYEOF'
import subprocess, json, re, os, glob

def run(*cmd):
    try:
        r = subprocess.run(list(cmd), capture_output=True, text=True, timeout=10)
        return r.stdout if r.returncode == 0 else ''
    except Exception:
        return ''

# ── Descoberta via lshw (suporta PT-BR e EN) ─────────────────────────────────
lshw_out = run('sudo', '-n', 'lshw', '-C', 'video')

def parse_lshw(text):
    gpus = []
    for bloco in re.split(r'\*-display', text):
        if not bloco.strip():
            continue
        def field(*labels):
            for lbl in labels:
                m = re.search(rf'^\s*{lbl}\s*:\s*(.+)$', bloco, re.MULTILINE | re.IGNORECASE)
                if m:
                    return m.group(1).strip()
            return ''
        produto = field('product', 'produto')
        if not produto:
            continue
        fabricante = field('vendor', 'fabricante')
        pci_m = re.search(r'pci@([\w:.]+)', bloco, re.IGNORECASE)
        pci   = pci_m.group(1) if pci_m else ''
        drv_m = re.search(r'driver=(\S+)', bloco, re.IGNORECASE)
        driver = drv_m.group(1) if drv_m else ''
        gpus.append({
            'nome': produto, 'fabricante': fabricante, 'driver': driver, 'pci': pci,
            'tipo': None, 'uso': None,
            'mem_usado_mb': None, 'mem_total_mb': None, 'mem_livre_mb': None,
            'temperatura': None, 'driver_version': None,
        })
    return gpus

gpus = parse_lshw(lshw_out)

# Fallback: lspci -vmm + lspci -k
if not gpus:
    current = {}
    for line in run('lspci', '-vmm').splitlines():
        if not line.strip():
            cls = current.get('Class', '')
            if any(k in cls for k in ('VGA', 'Display', '3D')):
                slot = current.get('Slot', '')
                drv_out = run('lspci', '-k', '-s', slot)
                drv_m = re.search(r'Kernel driver in use:\s*(\S+)', drv_out)
                gpus.append({
                    'nome': current.get('SDevice') or current.get('Device', 'GPU'),
                    'fabricante': current.get('SVendor') or current.get('Vendor', ''),
                    'driver': drv_m.group(1) if drv_m else '',
                    'pci': slot,
                    'tipo': None, 'uso': None,
                    'mem_usado_mb': None, 'mem_total_mb': None, 'mem_livre_mb': None,
                    'temperatura': None, 'driver_version': None,
                })
            current = {}
        else:
            k, _, v = line.partition(':')
            current[k.strip()] = v.strip()

# ── NVIDIA (driver=nvidia) via nvidia-smi ─────────────────────────────────────
def enrich_nvidia(gpu_list):
    smi = run('nvidia-smi',
              '--query-gpu=pci.bus_id,utilization.gpu,memory.used,memory.total,memory.free,temperature.gpu,driver_version',
              '--format=csv,noheader,nounits')
    if not smi:
        return
    for line in smi.strip().splitlines():
        parts = [x.strip() for x in line.split(',')]
        if len(parts) < 7:
            continue
        pci_smi = parts[0].lower().split(':',1)[-1]  # "00000000:01:00.0" → "01:00.0"
        for g in gpu_list:
            if g['driver'] != 'nvidia':
                continue
            gpci = g['pci'].lower().replace('0000:', '')
            if gpci and (gpci == pci_smi or pci_smi.endswith(gpci)):
                g['tipo'] = 'nvidia'
                try: g['uso'] = float(parts[1])
                except: pass
                try: g['mem_usado_mb'] = int(parts[2])
                except: pass
                try: g['mem_total_mb'] = int(parts[3])
                except: pass
                try: g['mem_livre_mb'] = int(parts[4])
                except: pass
                try: g['temperatura'] = float(parts[5])
                except: pass
                g['driver_version'] = parts[6]

# ── AMD (driver=amdgpu) via sysfs ─────────────────────────────────────────────
def enrich_drm_sysfs(g, driver_tipo):
    drm_dev = None
    if g['pci']:
        pci_short = g['pci'].lower().replace('0000:', '')
        for lp in glob.glob('/sys/class/drm/card*/device'):
            real = os.path.realpath(lp)
            if pci_short in real or g['pci'].lower() in real:
                drm_dev = lp
                break
    if not drm_dev:
        candidates = sorted(glob.glob('/sys/class/drm/card*/device/gpu_busy_percent'))
        if candidates:
            drm_dev = os.path.dirname(candidates[0])
    if not drm_dev:
        return
    def _r(p):
        try: return open(p).read().strip()
        except: return None
    g['tipo'] = driver_tipo
    busy = _r(f'{drm_dev}/gpu_busy_percent')
    if busy is not None:
        try: g['uso'] = float(busy)
        except: pass
    vt = _r(f'{drm_dev}/mem_info_vram_total')
    vu = _r(f'{drm_dev}/mem_info_vram_used')
    if vt and int(vt) > 0:
        g['mem_total_mb'] = int(vt) // 1048576
        g['mem_usado_mb'] = int(vu or 0) // 1048576
        g['mem_livre_mb'] = g['mem_total_mb'] - g['mem_usado_mb']
    for tf in sorted(glob.glob(f'{drm_dev}/hwmon/hwmon*/temp*_input')):
        try:
            val = int(open(tf).read().strip())
            if 20000 < val < 120000:
                g['temperatura'] = val // 1000
                break
        except: pass
    ver = _r(f'{drm_dev}/driver/module/version')
    if ver:
        g['driver_version'] = ver

enrich_nvidia(gpus)
for g in gpus:
    if g['driver'] == 'amdgpu':
        enrich_drm_sysfs(g, 'amd')
    elif g['driver'] == 'nouveau':
        enrich_drm_sysfs(g, 'nvidia')  # é NVIDIA mas com driver open-source

# Inferir tipo para GPUs sem métricas
for g in gpus:
    if not g['tipo']:
        fab = g['fabricante'].lower()
        drv = g['driver'].lower()
        if 'nvidia' in fab or drv in ('nvidia', 'nouveau'):
            g['tipo'] = 'nvidia'
        elif 'amd' in fab or 'ati' in fab or drv in ('amdgpu', 'radeon'):
            g['tipo'] = 'amd'
        elif 'intel' in fab or drv in ('i915', 'xe'):
            g['tipo'] = 'intel'
        else:
            g['tipo'] = 'unknown'

print(json.dumps(gpus))
PYEOF
)

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
    for cmd in [['sudo', '-n', 'dmidecode', '--type', '17'],
                ['dmidecode', '--type', '17']]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if r.returncode == 0 and 'Memory Device' in r.stdout:
                return r.stdout
        except Exception:
            pass
    return ''

raw = run_dmi()
dimms = []

RUIDO_FAB = {'Unknown', 'Not Specified', '', '0000', 'NO DIMM', 'Undefined'}

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

    fab    = campo('Manufacturer')
    modelo = campo('Part Number')
    locator = campo('Locator')
    tipo   = campo('Type')  # DDR3, DDR4, LPDDR4...

    # Normalizar ruído
    if fab in RUIDO_FAB or re.fullmatch(r'[0-9A-Fa-f]+', fab):
        fab = ''
    if modelo in {'Unknown', 'Not Specified', ''}:
        modelo = ''
    if tipo in {'Unknown', ''}:
        tipo = None

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
        'tipo': tipo,
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
  "gpus": ${gpus_data},
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
