/**
 * Monitor do Servidor — Aba Containers Docker.
 */

'use strict';

import { $, esc, formatBytes } from '../utils.js';
import { api, toast } from '../api.js';
import { pedirSudo, mostrarOutput, setGauge } from '../ui.js';

// Nomes de containers com a linha de stats expandida — preservado entre
// refreshes silenciosos, que re-renderizam a tabela inteira via innerHTML.
const expandidos = new Set();

export async function carregarContainers(silencioso = false) {
  if (!silencioso) {
    $('#tbody-containers').innerHTML = '<tr><td colspan="6" class="loading-row">Carregando...</td></tr>';
  }

  const dados = await api('/api/services');
  if (!dados) return;

  const ctnDados = dados.containers ?? {};
  const containers = ctnDados.containers ?? [];
  const stacks = ctnDados.stacks ?? [];

  // Mapear container → stack (diretório)
  const containerParaStack = {};
  stacks.forEach(stack => {
    stack.containers.forEach(nome => {
      containerParaStack[nome] = { nome: stack.nome, diretorio: stack.diretorio };
    });
  });

  if (containers.length === 0) {
    $('#tbody-containers').innerHTML = '<tr><td colspan="6" class="loading-row">Nenhum container encontrado (ou Docker não está rodando)</td></tr>';
    return;
  }

  $('#tbody-containers').innerHTML = containers.map(c => {
    const badgeClass = {
      running:    'badge-running',
      exited:     'badge-stopped',
      paused:     'badge-paused',
      restarting: 'badge-restarting',
      dead:       'badge-failed',
    }[c.estado] ?? 'badge-unknown';

    const imagemHtml = `<div>${esc(c.imagem_nome)}</div>
      <span class="versao-chip">${esc(c.imagem_tag)}</span>`;

    const portasHtml = c.portas
      ? `<code style="font-size:11px">${esc(c.portas)}</code>`
      : '—';

    const stack = containerParaStack[c.nome];
    const updateBtn = stack
      ? `<button class="btn btn-warning btn-xs"
           onclick="atualizarContainer('${esc(stack.nome)}', '${esc(stack.diretorio)}')">
           Atualizar</button>`
      : '';

    const idGauge = `gauge-ctn-${esc(c.id)}`;
    const expandido = expandidos.has(c.nome);

    return `<tr>
      <td>
        <button class="btn-expandir${expandido ? ' expandido' : ''}"
          onclick="toggleStatsContainer(this, '${esc(c.nome)}')" title="Ver uso de recursos">▶</button>
      </td>
      <td>
        <div><strong>${esc(c.nome)}</strong></div>
        <div style="font-size:11px;color:var(--text-dim)">${esc(c.id)}</div>
      </td>
      <td>${imagemHtml}</td>
      <td>
        <span class="badge ${badgeClass}">${esc(c.estado)}</span>
        <div style="font-size:11px;color:var(--text-dim);margin-top:2px">${esc(c.status_texto)}</div>
      </td>
      <td>${portasHtml}</td>
      <td>
        <div class="acoes">
          <button class="btn btn-ghost btn-sm" onclick="acaoContainer('restart', '${esc(c.nome)}')">Reiniciar</button>
          <button class="btn btn-ghost btn-sm" onclick="acaoContainer('stop',    '${esc(c.nome)}')">Parar</button>
          <button class="btn btn-ghost btn-sm" onclick="acaoContainer('start',   '${esc(c.nome)}')">Iniciar</button>
          ${updateBtn}
        </div>
      </td>
    </tr>
    <tr class="container-stats-row${expandido ? '' : ' hidden'}" data-stats-de="${esc(c.nome)}">
      <td colspan="6">${renderizarStatsContainer(c.stats, idGauge)}</td>
    </tr>`;
  }).join('');

  // Gauges são SVG com atributos próprios — precisam ser inicializados via
  // setGauge() depois de inseridos no DOM (innerHTML não executa isso sozinho).
  containers.forEach(c => {
    if (c.stats?.cpu_pct != null) setGauge(`gauge-ctn-${c.id}`, c.stats.cpu_pct);
  });
}

function nivelClasse(pct) {
  if (pct == null) return '';
  return pct >= 90 ? 'nivel-critico' : pct >= 70 ? 'nivel-aviso' : '';
}

function renderizarStatsContainer(stats, idGauge) {
  if (!stats) {
    return '<div class="container-stats-sem-dados">Sem dados de uso (container parado ou stats indisponível)</div>';
  }

  const memPct = stats.mem_pct;
  const memBarClass = nivelClasse(memPct);

  const cpuHtml = `<div class="stat-item">
    <span class="stat-item-label">CPU</span>
    <div class="gauge-wrap gauge-wrap-sm">
      <svg class="gauge" viewBox="0 0 120 120">
        <circle class="gauge-track" cx="60" cy="60" r="50"/>
        <circle class="gauge-fill" id="${idGauge}" cx="60" cy="60" r="50" stroke-dasharray="0 314"/>
      </svg>
      <div class="gauge-center"><span class="gauge-value">${stats.cpu_pct != null ? stats.cpu_pct.toFixed(1) + '%' : '—'}</span></div>
    </div>
  </div>`;

  const memHtml = `<div class="stat-item">
    <span class="stat-item-label">Memória</span>
    <div class="stat-bar-wrap"><div class="stat-bar ${memBarClass}" style="width:${memPct ?? 0}%"></div></div>
    <span class="stat-item-valor">${stats.mem_usado != null ? `${formatBytes(stats.mem_usado)} / ${formatBytes(stats.mem_limite)}` : '—'}</span>
  </div>`;

  const redeHtml = `<div class="stat-item">
    <span class="stat-item-label">Rede (rx / tx)</span>
    <span class="stat-item-valor">${stats.net_rx != null ? `↓ ${formatBytes(stats.net_rx)} / ↑ ${formatBytes(stats.net_tx)}` : '—'}</span>
  </div>`;

  const discoHtml = `<div class="stat-item">
    <span class="stat-item-label">Disco (leitura / escrita)</span>
    <span class="stat-item-valor">${stats.disco_leitura != null ? `${formatBytes(stats.disco_leitura)} / ${formatBytes(stats.disco_escrita)}` : '—'}</span>
  </div>`;

  const swapHtml = `<div class="stat-item">
    <span class="stat-item-label">Swap</span>
    <span class="stat-item-valor">${stats.swap_usado != null ? (stats.swap_usado > 0 ? formatBytes(stats.swap_usado) : 'Sem swap') : '—'}</span>
  </div>`;

  return `<div class="container-stats-grid">${cpuHtml}${memHtml}${redeHtml}${discoHtml}${swapHtml}</div>`;
}

function toggleStatsContainer(botao, nome) {
  if (expandidos.has(nome)) {
    expandidos.delete(nome);
  } else {
    expandidos.add(nome);
  }

  botao.classList.toggle('expandido');
  $(`tr[data-stats-de="${nome}"]`)?.classList.toggle('hidden');
}
window.toggleStatsContainer = toggleStatsContainer;

async function acaoContainer(acao, container) {
  const r = await api('/api/container/action', {
    method: 'POST',
    body: { action: acao, container }
  });
  if (r?.success) {
    toast(`${acao} em ${container}: OK`, 'ok');
    await carregarContainers(true);
  } else {
    toast(`Erro: ${r?.error ?? r?.erro ?? 'Falha'}`, 'erro', 5000);
  }
}
window.acaoContainer = acaoContainer;

async function atualizarContainer(nome, caminho) {
  pedirSudo(
    `Atualizar o container "${nome}" requer sudo (para docker pull e docker compose up).`,
    async (sudoPass) => {
      toast(`Atualizando container ${nome}...`, 'aviso', 10000);
      const r = await api('/api/update/container', {
        method: 'POST',
        body: { nome, caminho, sudo_pass: sudoPass }
      });
      if (r?.success) {
        toast(`Container ${nome} atualizado!`, 'ok');
        mostrarOutput(r.output);
        await carregarContainers(true);
      } else {
        toast(`Erro: ${r?.erro ?? 'Falha na atualização'}`, 'erro', 6000);
      }
    }
  );
}
window.atualizarContainer = atualizarContainer;

$('#btn-refresh-containers')?.addEventListener('click', () => carregarContainers());
