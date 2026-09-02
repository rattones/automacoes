/**
 * Monitor do Servidor — Aba Rede (interfaces, serviços em escuta e watchlist).
 */

'use strict';

import { $, esc } from '../utils.js';
import { api, toast } from '../api.js';
import { estado } from '../state.js';

export async function carregarRede(silencioso = false) {
  if (!silencioso) {
    $('#tbody-interfaces').innerHTML  = '<tr><td colspan="6" class="loading-row">Carregando...</td></tr>';
    $('#tbody-portas').innerHTML      = '<tr><td colspan="7" class="loading-row">Carregando...</td></tr>';
    $('#tbody-portas-auto').innerHTML = '<tr><td colspan="4" class="loading-row">Carregando...</td></tr>';
  }

  const [dados, dadosWatch] = await Promise.all([
    api('/api/network'),
    api('/api/network/watchlist'),
  ]);
  if (!dados) return;
  estado.dadosRede = dados;

  // Interfaces
  const uso = dados.uso_rede ?? {};
  const ifaces = (dados.interfaces ?? []).filter(i =>
    i.nome !== 'lo' && !i.nome.startsWith('docker') && !i.nome.startsWith('br-')
  );

  if (ifaces.length === 0) {
    $('#tbody-interfaces').innerHTML = '<tr><td colspan="6" class="loading-row">Nenhuma interface encontrada</td></tr>';
  } else {
    $('#tbody-interfaces').innerHTML = ifaces.map(iface => {
      const u = uso[iface.nome] ?? {};
      const estadoBadge = iface.estado === 'up' ? 'badge-running' : 'badge-stopped';
      const ips = (iface.enderecos ?? [])
        .map(a => `<span class="versao-chip">${esc(a.ip)}/${a.prefixo}</span>`)
        .join(' ');
      return `<tr>
        <td><strong>${esc(iface.nome)}</strong></td>
        <td><span class="badge ${estadoBadge}">${esc(iface.estado)}</span></td>
        <td><code style="font-size:11px;color:var(--text-muted)">${esc(iface.mac || '—')}</code></td>
        <td>${ips || '—'}</td>
        <td>${u.rx_mbps != null ? u.rx_mbps.toFixed(3) : '—'}</td>
        <td>${u.tx_mbps != null ? u.tx_mbps.toFixed(3) : '—'}</td>
      </tr>`;
    }).join('');
  }

  // Portas detectadas automaticamente — deduplicar por número de porta, apenas com processo identificado
  const servicosBrutos = (dados.servicos ?? [])
    .filter(s => s.porta > 0 && s.processo);

  // Agrupar por porta: coletar todos os IPs e manter o mais completo
  const porMap = new Map();
  for (const s of servicosBrutos) {
    if (!porMap.has(s.porta)) {
      porMap.set(s.porta, { ...s, ips: [s.ip] });
    } else {
      porMap.get(s.porta).ips.push(s.ip);
      if (!porMap.get(s.porta).servico && s.servico) {
        porMap.get(s.porta).servico = s.servico;
      }
    }
  }
  estado._portasAuto = [...porMap.values()].sort((a, b) => a.porta - b.porta);

  estado._servicosPorta = (dadosWatch?.watchlist ?? [])
    .map(w => ({ origem: 'watch', ...w }));

  aplicarFiltroPortas();
  aplicarFiltroPortasAuto();
}

// Mini gráfico (sparkline) em SVG com os últimos N pontos de latência (ms).
// Pontos `null` (leitura offline) ficam com um marcador na base, sem interpolar a linha.
function sparklineSvg(pontos) {
  const W = 70, H = 22, PAD = 2;
  const validos = (pontos ?? []).filter(v => v != null);
  if (validos.length < 2) {
    return '<span class="sparkline-vazio">—</span>';
  }

  const max = Math.max(...validos);
  const min = Math.min(...validos);
  const faixa = max - min || 1;
  const n = pontos.length;
  const passo = n > 1 ? (W - PAD * 2) / (n - 1) : 0;

  const coordY = (v) => H - PAD - ((v - min) / faixa) * (H - PAD * 2);

  let pathD = '';
  let comeco = true;
  const marcadoresOffline = [];
  pontos.forEach((v, i) => {
    const x = PAD + i * passo;
    if (v == null) {
      marcadoresOffline.push(`<circle cx="${x.toFixed(1)}" cy="${(H - PAD).toFixed(1)}" r="1.6" class="sparkline-offline-pt"/>`);
      comeco = true;
      return;
    }
    const y = coordY(v).toFixed(1);
    pathD += `${comeco ? 'M' : 'L'}${x.toFixed(1)},${y} `;
    comeco = false;
  });

  const ultimo = pontos[pontos.length - 1];
  const corLinha = ultimo == null ? 'var(--vermelho)' : 'var(--verde)';

  return `<svg class="sparkline" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <path d="${pathD.trim()}" fill="none" stroke="${corLinha}" stroke-width="1.4" stroke-linejoin="round" stroke-linecap="round"/>
    ${marcadoresOffline.join('')}
  </svg>`;
}

// Rótulo do alvo na coluna "Alvo" — mesmo padrão host:porta para TCP e HTTP(S).
// Para HTTP(S) sem porta explícita, usa a padrão do esquema (443 HTTPS / 80 HTTP).
function alvoDoServico(s) {
  if (s.tipo === 'tcp') return `${s.host}:${s.porta}`;
  const porta = s.porta ?? (s.https === false ? 80 : 443);
  const caminho = s.caminho ?? '';
  return `${s.host}:${porta}${caminho}`;
}

function renderizarPortas(lista) {
  if (lista.length === 0) {
    $('#tbody-portas').innerHTML = '<tr><td colspan="7" class="loading-row">Nenhum serviço monitorado. Use "+ Adicionar" para incluir um alvo.</td></tr>';
    return;
  }
  $('#tbody-portas').innerHTML = lista.map(s => {
    const alvo = alvoDoServico(s);
    const badgeStatus = s.online ? 'badge-active' : 'badge-failed';
    return `<tr>
      <td><code style="font-size:11px">${esc(alvo)}</code></td>
      <td><strong>${esc(s.nome)}</strong></td>
      <td><span class="versao-chip">${s.tipo === 'tcp' ? 'TCP' : (s.https === false ? 'HTTP' : 'HTTPS')}</span></td>
      <td>${esc(s.detalhe ?? '—')}</td>
      <td>${sparklineSvg(s.historico)}</td>
      <td><span class="badge ${badgeStatus}">${s.online ? 'online' : 'offline'}</span></td>
      <td><button class="btn btn-ghost-danger btn-xs" onclick="excluirWatchlist('${esc(s.id)}')" title="Remover monitoramento">✕</button></td>
    </tr>`;
  }).join('');
}

function aplicarFiltroPortas() {
  const termo = ($('#filtro-portas')?.value ?? '').toLowerCase().trim();
  const lista = estado._servicosPorta ?? [];
  if (!termo) { renderizarPortas(lista); return; }
  renderizarPortas(lista.filter(s => {
    const alvo = alvoDoServico(s);
    return s.nome.toLowerCase().includes(termo) || alvo.toLowerCase().includes(termo);
  }));
}

$('#filtro-portas')?.addEventListener('input', aplicarFiltroPortas);

// ── Portas detectadas automaticamente (não monitoradas manualmente) ──────────

function renderizarPortasAuto(lista) {
  const contagem = $('#contagem-portas-auto');
  if (contagem) contagem.textContent = lista.length;

  if (lista.length === 0) {
    $('#tbody-portas-auto').innerHTML = '<tr><td colspan="4" class="loading-row">Nenhuma porta detectada</td></tr>';
    return;
  }
  $('#tbody-portas-auto').innerHTML = lista.map(s => {
    const ipsUnicos = [...new Set(s.ips)].slice(0, 6);
    const ipsHtml = ipsUnicos.map(ip => `<code style="font-size:11px;margin-right:4px">${esc(ip)}</code>`).join('');
    return `<tr>
      <td><strong>${esc(s.porta)}</strong></td>
      <td>${esc(s.processo)}</td>
      <td>${s.servico ? `<span class="versao-chip">${esc(s.servico)}</span>` : '—'}</td>
      <td>${ipsHtml}</td>
    </tr>`;
  }).join('');
}

function aplicarFiltroPortasAuto() {
  const termo = ($('#filtro-portas-auto')?.value ?? '').toLowerCase().trim();
  const lista = estado._portasAuto ?? [];
  if (!termo) { renderizarPortasAuto(lista); return; }
  renderizarPortasAuto(lista.filter(s =>
    String(s.porta).includes(termo) ||
    s.processo.toLowerCase().includes(termo) ||
    (s.servico ?? '').toLowerCase().includes(termo) ||
    s.ips.some(ip => ip.includes(termo))
  ));
}

$('#filtro-portas-auto')?.addEventListener('input', aplicarFiltroPortasAuto);

// Atualização silenciosa da watchlist, independente da aba ativa: enquanto
// houver ao menos um alvo monitorado, a sessão recheca o status a cada 15s
// sem depender do usuário estar na aba Rede nem recarregar a página.
export async function atualizarWatchlistSilencioso() {
  const dadosWatch = await api('/api/network/watchlist');
  const watchlist = dadosWatch?.watchlist ?? [];
  if (watchlist.length === 0) return;

  estado._servicosPorta = watchlist.map(w => ({ origem: 'watch', ...w }));

  if (estado.tabAtiva === 'rede') aplicarFiltroPortas();
}

// ── Watchlist (alvos TCP/HTTP monitorados manualmente) ────────────────────────

function abrirModalWatchlist() {
  $('#wl-nome').value = '';
  $('#wl-tipo').value = 'tcp';
  $('#wl-host').value = '';
  $('#wl-porta').value = '';
  $('#wl-http-host').value = '';
  $('#wl-http-porta').value = '';
  $('#wl-http-caminho').value = '';
  $('#wl-http-https').checked = true;
  $('#wl-campos-tcp').classList.remove('hidden');
  $('#wl-campos-http').classList.add('hidden');
  $('#wl-erro').classList.add('hidden');
  $('#watchlist-modal').classList.remove('hidden');
  setTimeout(() => $('#wl-nome').focus(), 50);
}

$('#btn-add-watchlist')?.addEventListener('click', abrirModalWatchlist);

$('#wl-tipo')?.addEventListener('change', (e) => {
  const ehTcp = e.target.value === 'tcp';
  $('#wl-campos-tcp').classList.toggle('hidden', !ehTcp);
  $('#wl-campos-http').classList.toggle('hidden', ehTcp);
});

$('#wl-cancelar')?.addEventListener('click', () => {
  $('#watchlist-modal').classList.add('hidden');
});

$('#wl-confirmar')?.addEventListener('click', async () => {
  const erroEl = $('#wl-erro');
  erroEl.classList.add('hidden');

  const nome = $('#wl-nome').value.trim();
  const tipo = $('#wl-tipo').value;
  const body = { nome, tipo };

  if (!nome) {
    erroEl.textContent = 'Informe um nome.';
    erroEl.classList.remove('hidden');
    return;
  }

  if (tipo === 'tcp') {
    body.host  = $('#wl-host').value.trim();
    body.porta = $('#wl-porta').value;
    if (!body.host || !body.porta) {
      erroEl.textContent = 'Informe host e porta.';
      erroEl.classList.remove('hidden');
      return;
    }
  } else {
    body.host  = $('#wl-http-host').value.trim();
    body.https = $('#wl-http-https').checked;
    if (!body.host) {
      erroEl.textContent = 'Informe o host.';
      erroEl.classList.remove('hidden');
      return;
    }
    const portaHttp = $('#wl-http-porta').value.trim();
    if (portaHttp) body.porta = portaHttp;
    const caminho = $('#wl-http-caminho').value.trim();
    if (caminho) body.caminho = caminho;
  }

  const r = await api('/api/network/watchlist', { method: 'POST', body });
  if (r?.success) {
    $('#watchlist-modal').classList.add('hidden');
    toast(`"${nome}" adicionado ao monitoramento`, 'ok');
    await carregarRede(true);
  } else {
    erroEl.textContent = r?.erro ?? 'Erro ao adicionar alvo.';
    erroEl.classList.remove('hidden');
  }
});

async function excluirWatchlist(id) {
  const r = await api(`/api/network/watchlist/${id}`, { method: 'DELETE' });
  if (r?.success) {
    toast('Removido do monitoramento', 'ok');
    await carregarRede(true);
  } else {
    toast(r?.erro ?? 'Erro ao remover', 'erro');
  }
}
window.excluirWatchlist = excluirWatchlist;

$('#btn-refresh-rede')?.addEventListener('click', () => carregarRede());
