# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Não lançado]

### 🐛 Correções

#### 🖥️ Monitor Web do Servidor — Aba Rede
- **Alvos HTTP(S) da watchlist não sobre TLS**: o check de alcançabilidade agora aceita qualquer certificado (`ssl.CERT_NONE`) — painéis internos (Crafty, roteadores, NAS) quase sempre usam certificado autoassinado, o que marcava como "offline" um serviço que estava no ar (`CERTIFICATE_VERIFY_FAILED`)

### 🔧 Melhorias

#### 🖥️ Monitor Web do Servidor — Aba Rede
- **Alvo HTTP(S) informa só o host**: o modal de adicionar não pede mais `http://`/`https://` — agora tem campos separados de Host, Porta (opcional), Caminho (opcional) e um checkbox "Usar HTTPS (TLS)". Colar uma URL completa no campo Host também funciona (host, esquema e porta são extraídos automaticamente)
- Itens da watchlist são guardados com `host`/`https`/`porta`/`caminho` separados; itens no formato antigo (`url` completa) continuam funcionando e são normalizados na resposta da API
- **Coluna "Alvo" com formato uniforme**: alvos HTTP(S) agora aparecem como `host:porta` (ex: `casa-ratton.local:8443`), igual aos alvos TCP, em vez da URL completa com sufixo `(:porta)`
- **Coluna "Detalhe" com formato uniforme**: online mostra `HTTP 200 · 45 ms` (HTTP/S) ou `TCP · 12 ms` (TCP), com o mesmo separador `·`; offline traduz as mensagens de erro mais comuns de socket/DNS para português ("Conexão recusada", "Host não encontrado (DNS)", "Tempo esgotado", etc.)
- Coluna "Tipo" passa a exibir `HTTPS` ou `HTTP` (antes era sempre `HTTP(S)`)

### ✨ Novas Funcionalidades

#### 🖥️ Monitor Web do Servidor — Aba Logs
- **Nova aba "Logs"**: lista os arquivos `.log` de execução em `logs/` (atualizações do servidor, atualizações de container e setup do monitor), ordenados do mais recente para o mais antigo
- Paginação de 10 em 10 no backend (`GET /api/logs?page=N`), com botões Anterior/Próxima
- Selecionar um log abre um painel abaixo da tabela (`GET /api/logs/<nome>`) com o conteúdo, códigos ANSI removidos e destaque de cor por nível (ERRO/SUCESSO/AVISO/INFO/PROGRESSO), reaproveitando a classificação por prefixo de `lib/converter_log_md.sh`
- Leitura limitada a 5000 linhas / 2 MB por log (indicado como "truncado"); nome do arquivo validado contra path traversal

## [1.3.0] - 2026-08-26

### ✨ Novas Funcionalidades

#### 🖥️ Monitor Web do Servidor — Aba Rede
- **Histórico de latência na watchlist**: nova coluna "Histórico" na tabela de Serviços em Escuta, entre Detalhe e Status, com um mini-gráfico (sparkline) das últimas 20 leituras de latência de cada alvo monitorado (TCP ou HTTP/S)
- Leituras offline aparecem como marcador na base do gráfico, sem interpolar a linha através da falha
- Histórico persistido em `monitor/data/watchlist_historico.json` (até 20 pontos por alvo), atualizado a cada checagem e removido automaticamente quando o alvo é excluído da watchlist
- Suporte a porta customizada para alvos HTTP(S) da watchlist (campo opcional no modal de adicionar)

#### 🔒 Monitor Web do Servidor — HTTPS
- **Monitor agora roda em HTTPS por padrão**: `server.py` aceita `CERT_PATH`/`KEY_PATH` via `.env` e sobe com `ssl_context` do Flask
- Validação do par certificado/chave na inicialização — se configurados mas inválidos ou ausentes, o servidor encerra o processo em vez de subir sem TLS
- **CA local própria**: `setup-monitor.sh` gera uma CA (autoridade certificadora) local em `monitor/data/ca/` (RSA 4096, válida por 10 anos) e emite o certificado do servidor assinado por ela em `monitor/data/certs/` (RSA 2048, válido por 825 dias), com SAN cobrindo hostname, `hostname.local` (mDNS) e IP da máquina — instalar `ca.pem` como confiável no dispositivo elimina o aviso de segurança do navegador, diferente de um self-signed solto
- Reinstalações reemitem automaticamente o certificado do servidor se hostname/IP mudarem, sem gerar uma nova CA; instalações anteriores (self-signed sem CA) são migradas automaticamente
- Deixar `CERT_PATH`/`KEY_PATH` em branco mantém o comportamento anterior (HTTP puro)

## [1.2.0] - 2026-05-08

### ✨ Novas Funcionalidades

#### 🖥️ Monitor Web do Servidor
- **Novo módulo**: `monitor/` — painel web completo acessível em `http://[IP]:8180`
- **Backend**: Flask com autenticação PAM (usuário real do sistema)
- **Frontend**: Vanilla JS, dark mode, atualização automática (5s métricas / 15s abas)
- **Serviço systemd**: `monitor-servidor.service` (habilitado e persistente)

**Aba Métricas:**
- CPU: gauge global + grade de tiles por núcleo com uso % e temperatura (coretemp)
- GPU: tiles individuais por GPU via `sudo lshw -C video`; barra de uso, temperatura, memória e versão do driver. Suporte a NVIDIA (nvidia-smi), AMD (amdgpu sysfs) e Nouveau
- RAM: gauge global + DIMMs via `sudo dmidecode --type 17` (slot, tipo DDR, tamanho, fabricante, velocidade)
- Disco: barras de uso por ponto de montagem
- Sistema: hostname, kernel, uptime, load average

**Aba Rede:**
- Tabela de interfaces com estado, MAC, IPs, velocidade rx/tx em Mbps
- Tabela de portas em escuta com filtro por porta/processo/serviço

**Aba Serviços:**
- Lista de serviços systemd com estado, versão e ações (reiniciar, parar, recarregar)
- Detecção de atualizações disponíveis via apt

**Aba Containers:**
- Lista de containers Docker com estado e ações (start, stop, restart)
- Atualização de imagem via `docker pull` + `compose up`

**Header:**
- Botão de refresh manual
- Botão **Reiniciar Monitor** (amarelo): reinicia `monitor-servidor.service` via sudo e recarrega a página
- Botão **Reiniciar Servidor** (vermelho): executa `reboot` via sudo
- Botão Sair

#### 🔧 Módulo de Instalação do Monitor
- **Novo script**: `lib/post-install/setup-monitor.sh`
- Instala dependências Python (`flask`, `python-pam`)
- Cria e habilita serviço systemd `monitor-servidor.service`
- Configura sudoers para `dmidecode` sem senha

### 🔒 Segurança
- Rate limiting de login: 5 tentativas / 5 minutos por IP
- Validação de entradas com regex whitelist (nomes de serviços, containers, ações)
- Ações destrutivas exigem senha sudo (verificada via `sudo -S -v`, nunca armazenada)
- `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SAMESITE=Lax`
- Scripts executados via `subprocess.run` com lista de argumentos (sem shell injection)
- Proteção contra path traversal em caminhos de containers

### 📊 Estatísticas Atualizadas

- **Scripts principais**: 3
- **Módulos post-install**: 9 (incluindo setup-monitor)
- **Bibliotecas**: 7
- **Scripts de coleta de métricas**: 6 (monitor/scripts/)
- **Testes**: 107 automatizados
- **Linhas de código**: ~6.300+
- **Commits**: 34 até esta release

### 🔗 Links

- [Repositório GitHub](https://github.com/rattones/automacoes)
- [PR #1 — Monitor Web](https://github.com/rattones/automacoes/pull/1)
- [Documentação Completa](README.md)

---

## [1.1.0] - 2026-01-28

### ✨ Novas Funcionalidades

#### 📝 Conversor de Logs para Markdown
- **Novo script**: `lib/converter_log_md.sh`
- **Funcionalidades**:
  - Conversão automática de logs para formato Markdown
  - Remoção de códigos ANSI (cores do terminal)
  - Detecção e formatação de tabelas Docker
  - Destaque de mensagens especiais ([SUCESSO], [ERRO], [AVISO])
  - Criação automática de diretório `logs-md/`
- **Uso**: `./lib/converter_log_md.sh logs/atualizacao_20240128.log`

#### 💾 Sistema de Backup de Configurações
- **Novo script**: `lib/backup_configs.sh`
- **Funcionalidades**:
  - Backup automático de configurações dos containers
  - Suporte a Crafty Controller (`docker/config/`)
  - Suporte a Home Assistant (`config/` com tar.gz)
  - Backup de arquivos `compose.yml`
  - Histórico com timestamps
  - Integração com processo de atualização
- **Containers suportados**: Crafty e Home Assistant

#### 🧪 Expansão da Suíte de Testes
- **Novos testes**: `test_backup_configs.bats` (16 testes)
- **Cobertura expandida**: Conversor de logs (11 testes)
- **Total atual**: 107 testes automatizados
- **Melhorias**: Testes mais robustos com mocks isolados

### 🔧 Melhorias

#### Sistema de Logs
- **Correção**: Tratamento de erros APT com `apt -qq`
- **Melhoria**: Remoção de variáveis temporárias desnecessárias
- **Validação**: Testes atualizados para refletir mudanças

#### Documentação
- **README.md**: Seção completa sobre conversor de logs
- **README.md**: Seção sobre backup de configurações
- **Estrutura**: Atualização da árvore de arquivos
- **Contagem**: Estatísticas atualizadas (107 testes)

### 🐛 Correções

#### Testes
- **Correção**: Teste de tratamento de erros APT atualizado
- **Validação**: Todos os 107 testes passando
- **Estrutura**: Novo teste incluído na validação de estrutura

### 📊 Estatísticas Atualizadas

- **Scripts principais**: 3 (post-install, atualizar_servidor, diagnostico_apt)
- **Módulos**: 9 (1 orquestrador + 8 especializados)
- **Bibliotecas**: 7 (logging, sistema, container, nodejs, verificar, converter, backup)
- **Ferramentas**: 2 (diagnostico_apt, converter_log_md)
- **Testes**: 107 automatizados
- **Linhas de código**: ~3.000+
- **Commits**: 25 até esta release

### 🔗 Links

- [Repositório GitHub](https://github.com/rattones/automacoes)
- [Documentação Completa](README.md)
- [Análise de Falhas](ANALISE_FALHAS.md)
- [Testes](tests/README.md)

---

## [1.0.0] - 2026-01-09

### 🎉 Primeira Release Oficial

Esta é a primeira versão estável do projeto de automação de servidores Ubuntu, desenvolvida inteiramente por IA (GitHub Copilot) e supervisionada por [@rattones](https://github.com/rattones).

### ✨ Funcionalidades Principais

#### 📦 Post-Install Modular
- **Bootstrap automático**: Script inicial que instala Git e clona o repositório
- **8 módulos especializados**:
  - SSH Server com configuração de chaves
  - Zsh + Oh My Zsh + Powerlevel10k
  - GitHub CLI + Copilot CLI
  - Cockpit (administração web)
  - Docker + Docker Compose
  - Node.js via NVM
  - Containers (Crafty + Home Assistant)
  - Projetos personalizados

#### 🔄 Sistema de Atualização Completo
- Atualização automática do sistema operacional
- Atualização de containers Docker
- Atualização do Node.js via NVM
- Validação APT antes de atualizar
- Notificações por email
- Logs detalhados com timestamps

#### 🛠️ Ferramentas de Diagnóstico
- **diagnostico_apt.sh**: Ferramenta de troubleshooting APT
  - Detecção automática de conflitos de repositórios Docker
  - Backup automático antes de correções
  - Validação após correções
- Detecção de configurações duplicadas
- Classificação de erros (GPG, rede, chaves ausentes)

#### 🧪 Testes Automatizados
- **80 testes unitários** usando BATS
- Cobertura completa:
  - Estrutura do projeto (18 testes)
  - Bootstrap de instalação (6 testes)
  - Módulos de post-install (16 testes)
  - Biblioteca de logging (10 testes)
  - Sistema de atualização (7 testes)
  - Atualização de containers (7 testes)
  - Detecção de duplicatas APT (16 testes)
- Instalação automática de dependências de teste

#### 📚 Bibliotecas Reutilizáveis
- **logging.sh**: Sistema de logs coloridos com níveis
- **atualizar_sistema.sh**: Gerenciamento de pacotes APT
- **atualizar_container.sh**: Atualização de containers Docker
- **atualizar_nodejs.sh**: Gerenciamento de versões Node.js
- **verificar_sistema.sh**: Verificações de saúde do sistema

### 🐛 Correções Críticas

#### Conflito de Repositório Docker
- **Problema**: Configurações duplicadas causando falha no `apt update`
- **Solução**: Detecção e remoção automática de duplicatas
- **Prevenção**: Validação APT antes de atualizar sistema
- Documentado em [ANALISE_FALHAS.md](ANALISE_FALHAS.md)

### 📖 Documentação

- README completo com guias de uso
- Seção de diagnóstico e manutenção
- Documentação de testes em tests/README.md
- Análise detalhada de falhas e soluções
- Comentários inline em todos os scripts

### 🔒 Segurança

- Verificação de permissões root onde necessário
- Backups automáticos antes de modificações críticas
- Validação de configurações antes de aplicar
- Logs de auditoria de todas as operações

### 🎯 Benefícios da Arquitetura

- ✅ Código modular e reutilizável
- ✅ Fácil manutenção e extensibilidade
- ✅ Testes independentes por componente
- ✅ Logs centralizados e consistentes
- ✅ Detecção proativa de problemas
- ✅ Recuperação automática de falhas

### 📊 Estatísticas

- **Scripts principais**: 3 (post-install, atualizar_servidor, diagnostico_apt)
- **Módulos**: 9 (1 orquestrador + 8 especializados)
- **Bibliotecas**: 5 (logging, sistema, container, nodejs, verificar)
- **Testes**: 80 automatizados
- **Linhas de código**: ~2.500+
- **Commits**: 15 até esta release

### 🤖 Desenvolvimento

- **Desenvolvido por**: GitHub Copilot (Claude Sonnet 4.5)
- **Supervisionado por**: [@rattones](https://github.com/rattones) - Analista de Sistemas
- **Metodologia**: Desenvolvimento assistido por IA com revisão humana

### 📦 Instalação

```bash
# Baixar e executar script de instalação
curl -fsSL https://raw.githubusercontent.com/rattones/automacoes/main/post-install.sh -o post-install.sh
chmod +x post-install.sh
sudo ./post-install.sh
```

### 🔗 Links

- [Repositório GitHub](https://github.com/rattones/automacoes)
- [Documentação Completa](README.md)
- [Análise de Falhas](ANALISE_FALHAS.md)
- [Testes](tests/README.md)

---

**Data da Release**: 2026-01-09  
**Commit**: 63aaddd  
**Tag**: v1.0.0
