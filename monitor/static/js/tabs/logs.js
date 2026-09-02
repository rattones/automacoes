/**
 * Monitor do Servidor — Aba Logs (arquivos .log de execução, paginados).
 */

'use strict';

import { $, $$, esc, formatBytes } from '../utils.js';
import { api } from '../api.js';
import { estado } from '../state.js';

export async function carregarLogs(silencioso = false) {
  if (!silencioso) {
    $('#tbody-logs').innerHTML = '<tr><td colspan="4" class="loading-row">Carregando...</td></tr>';
  }

  const pagina = estado._logPagina ?? 1;
  const dados = await api(`/api/logs?page=${pagina}`);
  if (!dados) return;

  renderizarLista(dados);
}

function formatarData(epoch) {
  return new Date(epoch * 1000).toLocaleString('pt-BR');
}

function renderizarLista(dados) {
  const logs = dados.logs ?? [];
  estado._logPagina = dados.pagina;
  estado._logTotalPaginas = dados.total_paginas;

  if (logs.length === 0) {
    $('#tbody-logs').innerHTML = '<tr><td colspan="4" class="loading-row">Nenhum log encontrado</td></tr>';
  } else {
    $('#tbody-logs').innerHTML = logs.map(l => `<tr class="log-linha" data-log="${esc(l.nome)}">
      <td><code style="font-size:11px">${esc(l.nome)}</code></td>
      <td>${esc(l.tipo)}</td>
      <td>${formatBytes(l.tamanho)}</td>
      <td>${esc(formatarData(l.modificado))}</td>
    </tr>`).join('');
  }

  $('#log-pag-info').textContent = `Página ${dados.pagina} de ${dados.total_paginas}`;
  $('#log-pag-anterior').disabled = dados.pagina <= 1;
  $('#log-pag-proxima').disabled  = dados.pagina >= dados.total_paginas;
}

async function abrirDetalhe(nome) {
  $$('#tbody-logs .log-linha').forEach(tr => tr.classList.remove('ativa'));
  $(`#tbody-logs .log-linha[data-log="${CSS.escape(nome)}"]`)?.classList.add('ativa');

  $('#log-detalhe-titulo').textContent = nome;
  $('#log-detalhe-conteudo').textContent = 'Carregando...';
  $('#log-detalhe').classList.remove('hidden');
  $('#log-detalhe').scrollIntoView({ behavior: 'smooth' });

  const d = await api('/api/logs/' + encodeURIComponent(nome));
  if (!d) return;

  if (d.erro) {
    $('#log-detalhe-conteudo').textContent = d.erro;
    return;
  }

  $('#log-detalhe-titulo').textContent = d.truncado ? `${d.nome} (truncado)` : d.nome;
  $('#log-detalhe-conteudo').innerHTML = (d.linhas ?? [])
    .map(l => `<span class="log-nivel-${l.nivel}">${esc(l.texto)}</span>`)
    .join('\n');
}

// Delegação de evento: clique em qualquer linha da tabela abre o detalhe.
$('#tbody-logs')?.addEventListener('click', (e) => {
  const tr = e.target.closest('.log-linha');
  if (tr?.dataset.log) abrirDetalhe(tr.dataset.log);
});

$('#log-pag-anterior')?.addEventListener('click', () => {
  if ((estado._logPagina ?? 1) > 1) {
    estado._logPagina -= 1;
    carregarLogs();
  }
});

$('#log-pag-proxima')?.addEventListener('click', () => {
  if ((estado._logPagina ?? 1) < (estado._logTotalPaginas ?? 1)) {
    estado._logPagina += 1;
    carregarLogs();
  }
});

$('#btn-refresh-logs')?.addEventListener('click', () => carregarLogs());

$('#btn-fechar-log-detalhe')?.addEventListener('click', () => {
  $('#log-detalhe').classList.add('hidden');
  $$('#tbody-logs .log-linha').forEach(tr => tr.classList.remove('ativa'));
});
