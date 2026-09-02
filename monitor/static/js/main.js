/**
 * Monitor do Servidor — Ponto de entrada: login, header, tabs e auto-refresh.
 */

'use strict';

import { $ } from './utils.js';
import { api, toast } from './api.js';
import { estado } from './state.js';
import { mostrarLogin, mostrarApp, pedirSudo, inicializarTabs, pararTodosTimers } from './ui.js';
import { carregarStatus } from './tabs/metricas.js';
import { carregarRede, atualizarWatchlistSilencioso } from './tabs/rede.js';
import { carregarServicos } from './tabs/servicos.js';
import { carregarContainers } from './tabs/containers.js';
import { carregarLogs } from './tabs/logs.js';

const REFRESH_INTERVALO_MS = 5000; // 5 segundos

// ── Login ─────────────────────────────────────────────────────────────────────

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
    mostrarApp(usuario, iniciarMonitoramento);
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

// ── Tabs ──────────────────────────────────────────────────────────────────────

inicializarTabs({
  rede: carregarRede,
  servicos: carregarServicos,
  containers: carregarContainers,
  logs: carregarLogs,
});

// ── Refresh manual ────────────────────────────────────────────────────────────

$('#btn-refresh')?.addEventListener('click', () => {
  pararTodosTimers();
  iniciarMonitoramento();
  toast('Dados atualizados', 'ok', 1500);
});

// ── Auto-refresh loop ─────────────────────────────────────────────────────────

function iniciarMonitoramento() {
  // Carregamento inicial imediato
  carregarStatus();
  if (estado.tabAtiva === 'rede')       carregarRede();
  if (estado.tabAtiva === 'servicos')   carregarServicos();
  if (estado.tabAtiva === 'containers') carregarContainers();
  if (estado.tabAtiva === 'logs')       carregarLogs();

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

// ── Inicialização ──────────────────────────────────────────────────────────────

if (estado.autenticado) {
  mostrarApp(window._MONITOR?.usuario ?? '', iniciarMonitoramento);
} else {
  mostrarLogin();
}
