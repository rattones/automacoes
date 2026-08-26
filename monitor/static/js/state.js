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
  _servicosPorta: [], // Cache da watchlist (serviços monitorados manualmente) para o filtro
  _portasAuto: [],    // Cache das portas detectadas automaticamente (não monitoradas) para o filtro
};
