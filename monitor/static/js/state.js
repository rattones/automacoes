/**
 * Monitor do Servidor — Estado compartilhado entre módulos.
 */

'use strict';

export const estado = {
  autenticado: window._MONITOR?.autenticado ?? false,
  tabAtiva: 'metricas',
  timers: {},
  pendente: null,   // Ação pendente que aguarda sudo { fn, descricao }
  dadosRede: null,  // Cache para evitar recalcular rx/tx
  _servicosPorta: [], // Cache da lista combinada (portas em escuta + watchlist) para o filtro
};
