/**
 * Monitor do Servidor — Cliente HTTP e notificações toast.
 */

'use strict';

import { $ } from './utils.js';
import { estado } from './state.js';

// mostrarLogin é injetado por ui.js via setMostrarLogin() para evitar
// dependência circular (ui.js também precisa de api.js).
let _mostrarLogin = () => {};
export function setMostrarLogin(fn) { _mostrarLogin = fn; }

export function toast(msg, tipo = 'ok', duracao = 3500) {
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

export async function api(endpoint, { method = 'GET', body = null } = {}) {
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
      _mostrarLogin('Sessão expirada. Faça login novamente.');
      return null;
    }

    const data = await resp.json().catch(() => null);
    return data;
  } catch (err) {
    console.error('Erro na requisição:', endpoint, err);
    return null;
  }
}
