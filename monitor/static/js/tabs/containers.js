/**
 * Monitor do Servidor — Aba Containers Docker.
 */

'use strict';

import { $, esc } from '../utils.js';
import { api, toast } from '../api.js';
import { pedirSudo, mostrarOutput } from '../ui.js';

export async function carregarContainers(silencioso = false) {
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

$('#btn-refresh-containers')?.addEventListener('click', carregarContainers);
