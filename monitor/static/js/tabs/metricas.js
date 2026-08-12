/**
 * Monitor do Servidor — Aba Métricas (CPU, GPU, Memória, Disco, Sistema).
 */

'use strict';

import { $, esc, formatBytes, formatUptime } from '../utils.js';
import { api } from '../api.js';
import { setGauge } from '../ui.js';

export async function carregarStatus() {
  const dados = await api('/api/status');
  if (!dados) return;

  // CPU
  const cpu = dados.cpu ?? {};
  setGauge('gauge-cpu-fill', cpu.uso);
  $('#cpu-uso').textContent = `${cpu.uso ?? '--'}%`;
  $('#cpu-nucleos').textContent = cpu.nucleos ? `${cpu.nucleos} cores` : '';
  $('#cpu-modelo').textContent = cpu.modelo ?? '';
  $('#cpu-freq').textContent = cpu.frequencia_mhz ? `${cpu.frequencia_mhz} MHz` : '';
  $('#cpu-temp').textContent = cpu.temperatura != null ? `${cpu.temperatura}°C` : '';
  $('#cpu-load').textContent = dados.sistema?.load_1m != null
    ? `Load: ${dados.sistema.load_1m}` : '';

  // Núcleos individuais
  const coresList = $('#cpu-cores-list');
  if (coresList) {
    const cores = (cpu.cores ?? []).slice().sort((a, b) => a.id - b.id);
    coresList.innerHTML = cores.map(c => {
      const nivelClass = c.uso >= 90 ? 'nivel-critico' : c.uso >= 70 ? 'nivel-aviso' : '';
      const usoStyle   = c.uso >= 90 ? 'color:var(--vermelho)' : c.uso >= 70 ? 'color:var(--amarelo)' : '';
      const tempStr    = c.temp != null ? `${c.temp}°C` : '';
      return `<div class="core-tile">
        <div class="core-tile-row">
          <span class="core-tile-label">C${c.id}</span>
          <span class="core-tile-uso" style="${usoStyle}">${c.uso}%</span>
        </div>
        <div class="core-tile-bar-wrap"><div class="core-tile-bar ${nivelClass}" style="width:${c.uso.toFixed(1)}%"></div></div>
        ${tempStr ? `<span class="core-tile-temp">${tempStr}</span>` : ''}
      </div>`;
    }).join('');
  }

  // GPUs
  const gpus = dados.gpus ?? [];
  const gpuList = $('#gpu-list');
  if (gpuList) {
    if (gpus.length === 0) {
      gpuList.innerHTML = '<span class="dimm-unavail">Nenhuma GPU detectada</span>';
    } else {
      gpuList.innerHTML = gpus.map(g => {
        const nivel    = (g.uso ?? 0) >= 90 ? 'nivel-critico' : (g.uso ?? 0) >= 70 ? 'nivel-aviso' : '';
        const usoStyle = (g.uso ?? 0) >= 90 ? 'color:var(--vermelho)' : (g.uso ?? 0) >= 70 ? 'color:var(--amarelo)' : '';
        const usoStr   = g.uso != null ? `${g.uso}%` : '—';
        const usoW     = g.uso != null ? Number(g.uso).toFixed(1) : '0';
        const tempStr  = g.temperatura != null ? `${g.temperatura}°C` : '';
        const tipo     = (g.tipo ?? 'unknown').toLowerCase();
        const chips = [];
        if (g.mem_usado_mb != null) chips.push(`${g.mem_usado_mb} / ${g.mem_total_mb} MB`);
        if (g.driver_version)       chips.push(`Driver ${esc(g.driver_version)}`);
        const chipsHtml = chips.length
          ? `<div class="gpu-item-chips">${chips.map(c => `<span class="gpu-item-chip">${c}</span>`).join('')}</div>`
          : '';
        return `<div class="gpu-item">
          <div class="gpu-item-header">
            <span class="gpu-item-nome" title="${esc(g.nome ?? '')}">${esc(g.nome ?? 'GPU')}</span>
            <span class="gpu-badge gpu-badge-${tipo}">${tipo.toUpperCase()}</span>
          </div>
          <div class="gpu-item-uso-row">
            <span class="gpu-item-pct" style="${usoStyle}">${usoStr}</span>
            <div class="gpu-bar-wrap"><div class="gpu-bar ${nivel}" style="width:${usoW}%"></div></div>
            <span class="gpu-item-temp">${tempStr}</span>
          </div>
          ${chipsHtml}
        </div>`;
      }).join('');
    }
  }

  // Memória
  const mem = dados.memoria ?? {};
  setGauge('gauge-mem-fill', mem.uso_pct);
  $('#mem-uso-pct').textContent = `${mem.uso_pct ?? '--'}%`;
  $('#mem-usado-label').textContent = formatBytes(mem.usado);
  $('#mem-total-chip').textContent = `Total: ${formatBytes(mem.total)}`;
  $('#mem-swap-chip').textContent  = mem.swap_total
    ? `Swap: ${mem.swap_uso_pct}% (${formatBytes(mem.swap_total)})` : 'Sem swap';

  // DIMMs
  const dimmsList = $('#mem-dimms-list');
  if (dimmsList) {
    const dimms = mem.dimms ?? [];
    if (dimms.length === 0) {
      dimmsList.innerHTML = '<span class="dimm-unavail">dmidecode indisponível</span>';
    } else {
      dimmsList.innerHTML = dimms.map(d => {
        const gb = d.tamanho_mb != null ? (d.tamanho_mb / 1024).toFixed(0) + ' GB' : '?';
        const freq = d.velocidade_config_mts ?? d.velocidade_mts;
        const freqStr = freq ? `${freq} MT/s` : '';
        const fabModelo = [d.fabricante, d.modelo].filter(Boolean).join(' · ').trim();
        const tempStr = d.temperatura != null ? `${d.temperatura}°C` : '';
        const tipoStr = d.tipo ? `<span class="dimm-tipo">${esc(d.tipo)}</span>` : '';
        return `<div class="dimm-item">
          <div class="dimm-row">
            <span class="dimm-slot">${esc(d.locator)}${tipoStr}</span>
            <span class="dimm-size">${gb}</span>
            <span class="dimm-speed">${freqStr}</span>
            <span class="dimm-temp">${tempStr}</span>
          </div>
          ${fabModelo ? `<div class="dimm-model">${esc(fabModelo)}</div>` : ''}
        </div>`;
      }).join('');
    }
  }

  // Disco
  const discos = dados.disco ?? [];
  const discoEl = $('#disco-barras');
  if (discos.length === 0) {
    discoEl.innerHTML = '<span style="color:var(--text-muted);font-size:12px">Nenhum disco detectado</span>';
  } else {
    discoEl.innerHTML = discos.map(d => {
      const nivelClass = d.uso_pct >= 90 ? 'nivel-critico' : d.uso_pct >= 75 ? 'nivel-aviso' : '';
      return `<div class="disco-item">
        <div class="disco-row">
          <span class="disco-ponto">${esc(d.ponto)}</span>
          <span class="disco-info">${formatBytes(d.usado)} / ${formatBytes(d.total)} (${d.uso_pct.toFixed(1)}%)</span>
        </div>
        <div class="disco-bar-wrap">
          <div class="disco-bar ${nivelClass}" style="width:${d.uso_pct.toFixed(1)}%"></div>
        </div>
      </div>`;
    }).join('');
  }

  // Sistema
  const sys = dados.sistema ?? {};
  $('#header-hostname').textContent = sys.hostname ? `— ${sys.hostname}` : '';
  $('#header-uptime').textContent  = sys.uptime_seg ? `Uptime: ${formatUptime(sys.uptime_seg)}` : '';
  $('#info-kernel').textContent    = sys.kernel ? `Kernel: ${sys.kernel}` : '';
  $('#info-load').textContent      = sys.load_1m != null
    ? `Load avg: ${sys.load_1m} / ${sys.load_5m} / ${sys.load_15m}` : '';
}
