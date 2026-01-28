# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

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
