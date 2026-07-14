/**
 * Monitor do Servidor — JavaScript do Frontend
 * Vanilla JS, sem dependências externas.
 */

'use strict';

// ── Constantes ────────────────────────────────────────────────────────────────

const REFRESH_INTERVALO_MS = 5000; // 5 segundos
const GAUGE_CIRCUM = 314.159;      // 2π × 50

// ── Estado ────────────────────────────────────────────────────────────────────

const estado = {
  autenticado: window._MONITOR?.autenticado ?? false,
  tabAtiva: 'metricas',
  timers: {},
  pendente: null,   // Ação pendente que aguarda sudo { fn, descricao }
  dadosRede: null,  // Cache para evitar recalcular rx/tx
  _servicosPorta: [], // Cache da lista combinada (portas em escuta + watchlist) para o filtro
};

// ── Utilitários gerais ────────────────────────────────────────────────────────

function $(sel, ctx = document) { return ctx.querySelector(sel); }
function $$(sel, ctx = document) { return [...ctx.querySelectorAll(sel)]; }

function formatBytes(bytes) {
  if (bytes == null || isNaN(bytes)) return '—';
  if (bytes === 0) return '0 B';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(Math.abs(bytes)) / Math.log(1024));
  return (bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1) + ' ' + u[i];
}

function formatUptime(seg) {
  if (!seg) return '';
  const d = Math.floor(seg / 86400);
  const h = Math.floor((seg % 86400) / 3600);
  const m = Math.floor((seg % 3600) / 60);
  const parts = [];
  if (d) parts.push(`${d}d`);
  if (h) parts.push(`${h}h`);
  parts.push(`${m}m`);
  return parts.join(' ');
}

function esc(str) {
  // Escapa HTML para evitar XSS ao inserir conteúdo dinâmico
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// ── Toast ──────────────────────────────────────────────────────────────────────

function toast(msg, tipo = 'ok', duracao = 3500) {
  const container = $('#toast-container');
  const el = document.createElement('div');
  el.className = `toast toast-${tipo}`;
  el.textContent = msg;
  container.appendChild(el);

  setTimeout(() => {
    el.classList.add('toast-saindo');
    el.addEventListener('animationend', () => el.remove(), { once: true });
  }, duracao);
}

// ── API ───────────────────────────────────────────────────────────────────────

async function api(endpoint, { method = 'GET', body = null } = {}) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
  };
  if (body) opts.body = JSON.stringify(body);

  try {
    const resp = await fetch(endpoint, opts);

    if (resp.status === 401) {
      // Sessão expirada
      estado.autenticado = false;
      mostrarLogin('Sessão expirada. Faça login novamente.');
      return null;
    }

    const data = await resp.json().catch(() => null);
    return data;
  } catch (err) {
    console.error('Erro na requisição:', endpoint, err);
    return null;
  }
}

// ── Login ─────────────────────────────────────────────────────────────────────

function mostrarLogin(mensagem = '') {
  pararTodosTimers();
  $('#app').classList.add('hidden');
  $('#login-overlay').classList.remove('hidden');
  if (mensagem) {
    const erroEl = $('#login-erro');
    erroEl.textContent = mensagem;
    erroEl.classList.remove('hidden');
  }
  $('#l-usuario').focus();
}

function mostrarApp(usuario) {
  $('#login-overlay').classList.add('hidden');
  $('#app').classList.remove('hidden');
  $('#header-usuario').textContent = usuario;
  iniciarMonitoramento();
}

$('#login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const erroEl = $('#login-erro');
  erroEl.classList.add('hidden');

  const usuario = $('#l-usuario').value.trim();
  const senha   = $('#l-senha').value;

  if (!usuario || !senha) {
    erroEl.textContent = 'Preencha usuário e senha.';
    erroEl.classList.remove('hidden');
    return;
  }

  const btn = $('#btn-login');
  btn.disabled = true;
  $('.btn-label', btn).classList.add('hidden');
  $('.btn-spinner', btn).classList.remove('hidden');

  const resp = await api('/login', { method: 'POST', body: { usuario, senha } });

  btn.disabled = false;
  $('.btn-label', btn).classList.remove('hidden');
  $('.btn-spinner', btn).classList.add('hidden');

  if (resp?.success) {
    $('#l-senha').value = '';
    estado.autenticado = true;
    mostrarApp(usuario);
  } else {
    erroEl.textContent = resp?.erro ?? 'Erro ao autenticar.';
    erroEl.classList.remove('hidden');
    $('#l-senha').value = '';
    $('#l-senha').focus();
  }
});

$('#btn-logout').addEventListener('click', async () => {
  await api('/logout', { method: 'POST' });
  estado.autenticado = false;
  mostrarLogin();
});

$('#btn-restart-monitor').addEventListener('click', () => {
  pedirSudo('Reiniciar o serviço de monitoramento (monitor-servidor.service)', async (senha) => {
    const r = await api('/api/system/restart-monitor', {
      method: 'POST', body: { sudo_pass: senha },
    });
    if (r?.success) {
      toast('Serviço reiniciando… recarregando em 5s', 'ok', 6000);
      setTimeout(() => location.reload(), 5000);
    } else {
      toast(r?.erro ?? 'Erro ao reiniciar o serviço', 'erro');
    }
  });
});

$('#btn-reboot').addEventListener('click', () => {
  pedirSudo('⚠️ Reiniciar o servidor inteiro. Isso encerrará todas as conexões.', async (senha) => {
    const r = await api('/api/system/reboot', {
      method: 'POST', body: { sudo_pass: senha },
    });
    if (r?.success) {
      toast('Servidor reiniciando. A página ficará indisponível em breve.', 'ok', 15000);
    } else {
      toast(r?.erro ?? 'Erro ao reiniciar o servidor', 'erro');
    }
  });
});

// ── Modal Sudo ────────────────────────────────────────────────────────────────

function pedirSudo(descricao, onConfirmar) {
  estado.pendente = onConfirmar;
  $('#sudo-descricao').textContent = descricao;
  $('#sudo-senha').value = '';
  $('#sudo-erro').classList.add('hidden');
  $('#sudo-modal').classList.remove('hidden');
  setTimeout(() => $('#sudo-senha').focus(), 50);
}

$('#sudo-confirmar').addEventListener('click', async () => {
  const senha = $('#sudo-senha').value;
  if (!senha) {
    const erroEl = $('#sudo-erro');
    erroEl.textContent = 'Digite a senha sudo.';
    erroEl.classList.remove('hidden');
    return;
  }

  $('#sudo-modal').classList.add('hidden');
  const fn = estado.pendente;
  estado.pendente = null;

  if (fn) await fn(senha);
  $('#sudo-senha').value = '';
});

$('#sudo-cancelar').addEventListener('click', () => {
  $('#sudo-modal').classList.add('hidden');
  $('#sudo-senha').value = '';
  estado.pendente = null;
});

// ── Tabs ──────────────────────────────────────────────────────────────────────

$$('.tab').forEach(tab => {
  tab.addEventListener('click', () => {
    $$('.tab').forEach(t => t.classList.remove('active'));
    $$('.tab-content').forEach(c => c.classList.add('hidden'));
    tab.classList.add('active');
    const id = `tab-${tab.dataset.tab}`;
    $(`#${id}`)?.classList.remove('hidden');
    estado.tabAtiva = tab.dataset.tab;

    // Carregar dados ao mudar de tab
    if (tab.dataset.tab === 'rede')       carregarRede();
    if (tab.dataset.tab === 'servicos')   carregarServicos();
    if (tab.dataset.tab === 'containers') carregarContainers();
  });
});

// ── Gauges ────────────────────────────────────────────────────────────────────

function setGauge(fillId, pct) {
  const fill = $(`#${fillId}`);
  if (!fill) return;
  const clamped = Math.min(100, Math.max(0, pct || 0));
  const dash    = (clamped / 100) * GAUGE_CIRCUM;
  fill.setAttribute('stroke-dasharray', `${dash} ${GAUGE_CIRCUM}`);

  fill.classList.remove('nivel-ok', 'nivel-aviso', 'nivel-critico');
  if (clamped >= 90)     fill.classList.add('nivel-critico');
  else if (clamped >= 70) fill.classList.add('nivel-aviso');
  else                   fill.classList.add('nivel-ok');
}

// ── Métricas (Status) ─────────────────────────────────────────────────────────

async function carregarStatus() {
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
      const tempStr    = c.temp != null ? `${c.temp}\u00b0C` : '';
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

// ── Rede ──────────────────────────────────────────────────────────────────────

async function carregarRede(silencioso = false) {
  if (!silencioso) {
    $('#tbody-interfaces').innerHTML = '<tr><td colspan="6" class="loading-row">Carregando...</td></tr>';
    $('#tbody-portas').innerHTML     = '<tr><td colspan="6" class="loading-row">Carregando...</td></tr>';
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

  // Serviços por porta — deduplicar por número de porta, apenas com processo identificado
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
  const autoDetectados = [...porMap.values()]
    .sort((a, b) => a.porta - b.porta)
    .map(s => ({ origem: 'auto', ...s }));

  const watchlist = (dadosWatch?.watchlist ?? [])
    .map(w => ({ origem: 'watch', ...w }));

  estado._servicosPorta = [...autoDetectados, ...watchlist];
  aplicarFiltroPortas();
}

function renderizarPortas(lista) {
  if (lista.length === 0) {
    $('#tbody-portas').innerHTML = '<tr><td colspan="6" class="loading-row">Nenhum serviço em escuta detectado</td></tr>';
    return;
  }
  $('#tbody-portas').innerHTML = lista.map(s => {
    if (s.origem === 'watch') {
      const alvo = s.tipo === 'tcp' ? `${s.host}:${s.porta}` : s.url;
      const badgeStatus = s.online ? 'badge-active' : 'badge-failed';
      return `<tr>
        <td><code style="font-size:11px">${esc(alvo)}</code></td>
        <td><strong>${esc(s.nome)}</strong></td>
        <td><span class="versao-chip">${s.tipo === 'tcp' ? 'TCP' : 'HTTP(S)'}</span></td>
        <td>${esc(s.detalhe ?? '—')}</td>
        <td><span class="badge ${badgeStatus}">${s.online ? 'online' : 'offline'}</span></td>
        <td><button class="btn btn-ghost-danger btn-xs" onclick="excluirWatchlist('${esc(s.id)}')" title="Remover monitoramento">✕</button></td>
      </tr>`;
    }

    const ipsUnicos = [...new Set(s.ips)].slice(0, 6);
    const ipsHtml = ipsUnicos.map(ip => `<code style="font-size:11px;margin-right:4px">${esc(ip)}</code>`).join('');
    return `<tr>
      <td><strong>${esc(s.porta)}</strong></td>
      <td>${esc(s.processo)}</td>
      <td>${s.servico ? `<span class="versao-chip">${esc(s.servico)}</span>` : '—'}</td>
      <td>${ipsHtml}</td>
      <td><span class="badge badge-unknown">local</span></td>
      <td></td>
    </tr>`;
  }).join('');
}

function aplicarFiltroPortas() {
  const termo = ($('#filtro-portas')?.value ?? '').toLowerCase().trim();
  const lista = estado._servicosPorta ?? [];
  if (!termo) { renderizarPortas(lista); return; }
  renderizarPortas(lista.filter(s => {
    if (s.origem === 'watch') {
      const alvo = s.tipo === 'tcp' ? `${s.host}:${s.porta}` : s.url;
      return s.nome.toLowerCase().includes(termo) || alvo.toLowerCase().includes(termo);
    }
    return String(s.porta).includes(termo) ||
      s.processo.toLowerCase().includes(termo) ||
      (s.servico ?? '').toLowerCase().includes(termo) ||
      s.ips.some(ip => ip.includes(termo));
  }));
}

$('#filtro-portas')?.addEventListener('input', aplicarFiltroPortas);

// Atualização silenciosa da watchlist, independente da aba ativa: enquanto
// houver ao menos um alvo monitorado, a sessão recheca o status a cada 15s
// sem depender do usuário estar na aba Rede nem recarregar a página.
async function atualizarWatchlistSilencioso() {
  const dadosWatch = await api('/api/network/watchlist');
  const watchlist = (dadosWatch?.watchlist ?? []).map(w => ({ origem: 'watch', ...w }));
  if (watchlist.length === 0) return;

  const autoDetectados = (estado._servicosPorta ?? []).filter(s => s.origem === 'auto');
  estado._servicosPorta = [...autoDetectados, ...watchlist];

  if (estado.tabAtiva === 'rede') aplicarFiltroPortas();
}

// ── Watchlist (alvos TCP/HTTP monitorados manualmente) ────────────────────────

function abrirModalWatchlist() {
  $('#wl-nome').value = '';
  $('#wl-tipo').value = 'tcp';
  $('#wl-host').value = '';
  $('#wl-porta').value = '';
  $('#wl-url').value = '';
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
    body.url = $('#wl-url').value.trim();
    if (!body.url) {
      erroEl.textContent = 'Informe a URL.';
      erroEl.classList.remove('hidden');
      return;
    }
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


// ── Serviços systemd ──────────────────────────────────────────────────────────

async function carregarServicos(silencioso = false) {
  if (!silencioso) {
    $('#tbody-servicos').innerHTML = '<tr><td colspan="5" class="loading-row">Carregando...</td></tr>';
  }

  const dados = await api('/api/services');
  if (!dados) return;

  const servicos = dados.servicos ?? [];

  if (servicos.length === 0) {
    $('#tbody-servicos').innerHTML = '<tr><td colspan="5" class="loading-row">Nenhum serviço encontrado</td></tr>';
    return;
  }

  $('#tbody-servicos').innerHTML = servicos.map(s => {
    const badgeClass = {
      active:  'badge-active',
      failed:  'badge-failed',
      inactive:'badge-stopped',
    }[s.estado] ?? 'badge-unknown';

    const versaoHtml = s.versao
      ? `<span class="versao-chip">${esc(s.versao)}</span>`
      : '<span style="color:var(--text-dim)">—</span>';

    const atualizavelHtml = s.atualizavel
      ? `<span class="badge badge-update">Atualizar → ${esc(s.versao_nova ?? '')}</span>
         <button class="btn btn-warning btn-xs" onclick="atualizarServico(${JSON.stringify(esc(s.pkg))})">Atualizar</button>`
      : '<span class="badge badge-ok">Atualizado</span>';

    const botoesAcao = s.estado === 'active'
      ? `<button class="btn btn-ghost btn-sm" onclick="acaoServico('restart', '${esc(s.nome)}')">Reiniciar</button>
         <button class="btn btn-ghost btn-sm" onclick="acaoServico('stop',    '${esc(s.nome)}')">Parar</button>
         <button class="btn btn-ghost btn-sm" onclick="acaoServico('reload',  '${esc(s.nome)}')">Recarregar</button>`
      : `<button class="btn btn-ghost btn-sm" onclick="acaoServico('start',   '${esc(s.nome)}')">Iniciar</button>`;

    return `<tr>
      <td>
        <div><strong>${esc(s.nome)}</strong></div>
        <div style="font-size:11px;color:var(--text-dim)">${esc(s.descricao)}</div>
      </td>
      <td>
        <span class="badge ${badgeClass}">${esc(s.sub_estado || s.estado)}</span>
      </td>
      <td>${versaoHtml}</td>
      <td>${atualizavelHtml}</td>
      <td>
        <div class="acoes">
          ${botoesAcao}
        </div>
      </td>
    </tr>`;
  }).join('');
}

async function acaoServico(acao, servico) {
  pedirSudo(
    `Ação "${acao}" no serviço "${servico}" requer sudo.`,
    async (sudoPass) => {
      const r = await api('/api/service/action', {
        method: 'POST',
        body: { action: acao, service: servico, sudo_pass: sudoPass }
      });
      if (r?.success) {
        toast(`${acao} em ${servico}: OK`, 'ok');
        await carregarServicos(true);
      } else {
        toast(`Erro: ${r?.error ?? r?.erro ?? 'Falha desconhecida'}`, 'erro', 5000);
      }
    }
  );
}

async function atualizarServico(pkg) {
  pedirSudo(
    `Atualizar pacote "${pkg}" via apt requer sudo.`,
    async (sudoPass) => {
      toast('Atualizando sistema, aguarde...', 'aviso', 8000);
      const r = await api('/api/update/system', { method: 'POST', body: { sudo_pass: sudoPass } });
      if (r?.success) {
        toast('Sistema atualizado com sucesso!', 'ok');
        await carregarServicos(true);
      } else {
        toast(`Erro na atualização: ${r?.erro ?? 'Falha'}`, 'erro', 6000);
      }
    }
  );
}

$('#btn-atualizar-sistema')?.addEventListener('click', () => {
  pedirSudo(
    'Atualizar todos os pacotes do sistema requer sudo.',
    async (sudoPass) => {
      toast('Executando atualização do sistema, aguarde...', 'aviso', 10000);
      const r = await api('/api/update/system', { method: 'POST', body: { sudo_pass: sudoPass } });
      if (r?.success) {
        toast('Sistema atualizado com sucesso!', 'ok');
        mostrarOutput(r.output);
        await carregarServicos(true);
      } else {
        toast(`Erro na atualização: ${r?.erro ?? 'Falha'}`, 'erro', 6000);
      }
    }
  );
});

$('#btn-refresh-servicos')?.addEventListener('click', carregarServicos);

// ── Containers ────────────────────────────────────────────────────────────────

async function carregarContainers(silencioso = false) {
  if (!silencioso) {
    $('#tbody-containers').innerHTML = '<tr><td colspan="5" class="loading-row">Carregando...</td></tr>';
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
    $('#tbody-containers').innerHTML = '<tr><td colspan="5" class="loading-row">Nenhum container encontrado (ou Docker não está rodando)</td></tr>';
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

    return `<tr>
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
    </tr>`;
  }).join('');
}

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

$('#btn-refresh-containers')?.addEventListener('click', carregarContainers);

// ── Output Box ────────────────────────────────────────────────────────────────

function mostrarOutput(texto) {
  if (!texto) return;
  const box = $('#output-container');
  $('#output-texto').textContent = texto;
  box.classList.remove('hidden');
  box.scrollIntoView({ behavior: 'smooth' });
}

$('#btn-fechar-output')?.addEventListener('click', () => {
  $('#output-container').classList.add('hidden');
});

// ── Refresh manual ────────────────────────────────────────────────────────────

$('#btn-refresh')?.addEventListener('click', () => {
  pararTodosTimers();
  iniciarMonitoramento();
  toast('Dados atualizados', 'ok', 1500);
});

$('#btn-refresh-rede')?.addEventListener('click', carregarRede);

// ── Auto-refresh loop ─────────────────────────────────────────────────────────

function iniciarMonitoramento() {
  // Carregamento inicial imediato
  carregarStatus();
  if (estado.tabAtiva === 'rede')       carregarRede();
  if (estado.tabAtiva === 'servicos')   carregarServicos();
  if (estado.tabAtiva === 'containers') carregarContainers();

  // Métricas: refresh a cada 5s
  estado.timers.status = setInterval(() => {
    if (estado.tabAtiva === 'metricas') carregarStatus();
  }, REFRESH_INTERVALO_MS);

  // Demais tabs: refresh silencioso a cada 15s (sem limpar a tabela)
  estado.timers.tabs = setInterval(() => {
    if (estado.tabAtiva === 'rede')       carregarRede(true);
    if (estado.tabAtiva === 'servicos')   carregarServicos(true);
    if (estado.tabAtiva === 'containers') carregarContainers(true);
  }, 15000);

  // Watchlist de rede: enquanto houver algum alvo monitorado, recheca a cada 15s
  // independente da aba ativa (sem recarregar a página)
  atualizarWatchlistSilencioso();
  estado.timers.watchlist = setInterval(atualizarWatchlistSilencioso, 15000);
}

function pararTodosTimers() {
  Object.values(estado.timers).forEach(t => clearInterval(t));
  estado.timers = {};
}

// ── Inicialização ──────────────────────────────────────────────────────────────

if (estado.autenticado) {
  mostrarApp(window._MONITOR?.usuario ?? '');
} else {
  mostrarLogin();
}
