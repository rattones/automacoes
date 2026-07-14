# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### 🐛 Correções

#### Monitor Web — Ações de Serviço/Container (`monitor/scripts/service_action.sh`, `container_action.sh`)
- **Correção crítica**: checagem de existência de serviço/container usava `systemctl list-unit-files | grep -qF` (e `docker ps | grep -qF`) sob `set -o pipefail`. Quando o `grep -q` encontrava o padrão, fechava o pipe cedo e matava o processo anterior com `SIGPIPE` (exit 141); com `pipefail`, esse 141 virava o status do pipeline e o serviço/container era erroneamente reportado como "não encontrado" — bloqueando parar/reiniciar/recarregar de serviços individuais
- **Correção**: código de saída da ação (`start`/`stop`/`restart`/`reload`) era sempre capturado como `0` por causa de `|| true` dentro da substituição de comando, mascarando falhas reais do `systemctl`/`docker` como sucesso
- **Correção**: saída de comandos era interpolada diretamente em string Python delimitada por `'''`; aspas/barras invertidas na saída do `systemctl`/`docker` (comuns em mensagens de erro) podiam quebrar a geração do JSON. Passou a usar variáveis de ambiente lidas via `os.environ`

### ✨ Novas Funcionalidades

#### Monitor Web — Lista de Serviços (`monitor/scripts/get_services.sh`, `monitor/static/app.js`)
- **Serviços parados agora aparecem na lista**: antes só eram listados serviços `active`/`failed` (via `systemctl list-units --state=active,failed`); serviços instalados mas nunca carregados nesta sessão do systemd (ex.: desabilitados desde o boot) ficavam invisíveis. Agora a coleta une `list-units --all` com `list-unit-files` (catálogo completo, unidades `enabled`/`disabled`, excluindo templates `foo@.service`)
- **Novo botão "Iniciar"**: serviços parados agora exibem um botão de start (ação já suportada pelo backend) no lugar de Reiniciar/Parar/Recarregar, que só fazem sentido para serviços ativos
- **Ordenação**: `failed` → `active` → demais estados, por nome

#### Monitor Web — Watchlist de Rede (`monitor/server.py`, `monitor/static/app.js`, `monitor/templates/index.html`)
- **Novo botão "+ Adicionar"** na seção "Serviços em Escuta" (aba Rede), abrindo um modal para cadastrar alvos personalizados a monitorar: TCP (host + porta) ou HTTP(S) (URL)
- **Novos endpoints**: `GET/POST /api/network/watchlist` e `DELETE /api/network/watchlist/<id>`. Checagem de TCP via `socket.create_connection` e de HTTP(S) via `urllib` (stdlib, sem nova dependência), rodando em paralelo com `ThreadPoolExecutor`
- **Persistência**: lista salva em `monitor/data/watchlist.json` (adicionado ao `.gitignore` por ser dado de runtime específico de cada instalação)
- **Validação de entrada**: host/porta e URL validados no backend (regex de host, porta 1–65535, esquema `http`/`https` obrigatório) antes de qualquer conexão de saída
- **Tabela unificada**: alvos monitorados aparecem na mesma tabela dos serviços em escuta auto-detectados, com colunas de Status (online/offline) e um botão de remover (só nas entradas personalizadas)
- **Atualização em segundo plano**: enquanto houver ao menos um alvo cadastrado, o status é rechecado a cada 15s independente da aba ativa, sem recarregar a página

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
