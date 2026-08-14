/**
 * Monitor do Servidor — Aba Serviços systemd.
 */

'use strict';

import { $, esc } from '../utils.js';
import { api, toast } from '../api.js';
import { pedirSudo, mostrarOutput } from '../ui.js';

export async function carregarServicos(silencioso = false) {
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
window.acaoServico = acaoServico;

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
window.atualizarServico = atualizarServico;

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

$('#btn-refresh-servicos')?.addEventListener('click', () => carregarServicos());
