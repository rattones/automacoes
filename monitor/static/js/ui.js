/**
 * Monitor do Servidor — Componentes de UI compartilhados: modal sudo,
 * gauges, telas de login/app, output box e troca de abas.
 */

'use strict';

import { $, $$ } from './utils.js';
import { estado } from './state.js';
import { setMostrarLogin } from './api.js';

const GAUGE_CIRCUM = 314.159; // 2π × 50

// ── Login / App ───────────────────────────────────────────────────────────────

export function mostrarLogin(mensagem = '') {
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
setMostrarLogin(mostrarLogin);

export function mostrarApp(usuario, iniciarMonitoramento) {
  $('#login-overlay').classList.add('hidden');
  $('#app').classList.remove('hidden');
  $('#header-usuario').textContent = usuario;
  iniciarMonitoramento();
}

export function pararTodosTimers() {
  Object.values(estado.timers).forEach(t => clearInterval(t));
  estado.timers = {};
}

// ── Modal Sudo ────────────────────────────────────────────────────────────────

export function pedirSudo(descricao, onConfirmar) {
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

// Registra os handlers de troca de aba. `carregadores` é um objeto
// { rede, servicos, containers } com as funções carregarX de cada módulo.
export function inicializarTabs(carregadores) {
  $$('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      $$('.tab').forEach(t => t.classList.remove('active'));
      $$('.tab-content').forEach(c => c.classList.add('hidden'));
      tab.classList.add('active');
      const id = `tab-${tab.dataset.tab}`;
      $(`#${id}`)?.classList.remove('hidden');
      estado.tabAtiva = tab.dataset.tab;

      // Carregar dados ao mudar de tab
      if (tab.dataset.tab === 'rede')       carregadores.rede();
      if (tab.dataset.tab === 'servicos')   carregadores.servicos();
      if (tab.dataset.tab === 'containers') carregadores.containers();
      if (tab.dataset.tab === 'logs')       carregadores.logs();
    });
  });
}

// ── Gauges ────────────────────────────────────────────────────────────────────

export function setGauge(fillId, pct) {
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

// ── Output Box ────────────────────────────────────────────────────────────────

export function mostrarOutput(texto) {
  if (!texto) return;
  const box = $('#output-container');
  $('#output-texto').textContent = texto;
  box.classList.remove('hidden');
  box.scrollIntoView({ behavior: 'smooth' });
}

$('#btn-fechar-output')?.addEventListener('click', () => {
  $('#output-container').classList.add('hidden');
});
