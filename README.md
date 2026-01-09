# Sistema de Automação de Atualização do Servidor

Sistema modular de atualização automática do servidor, dividido em componentes reutilizáveis com testes unitários automatizados.

## 🚀 Guia de Instalação Inicial

### Passo 1: Preparar o Ubuntu Server

#### 1.1. Download do Ubuntu Server
Baixe a ISO mais recente do Ubuntu Server:
- 🔗 **[Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server)** (Recomendado)
- 🔗 [Ubuntu Server 22.04 LTS](https://ubuntu.com/download/server) (Alternativa estável)

#### 1.2. Criar Pendrive Bootável

**No Windows:**
1. Baixe o [Rufus](https://rufus.ie/)
2. Insira o pendrive (mínimo 4GB)
3. Abra o Rufus
4. Selecione o pendrive em "Device"
5. Clique em "SELECT" e escolha a ISO do Ubuntu Server
6. Mantenha as configurações padrão
7. Clique em "START"

**No Linux:**
```bash
# Identifique o pendrive (geralmente /dev/sdb)
lsblk

# Copie a ISO para o pendrive (CUIDADO: substitua /dev/sdX pelo seu dispositivo)
sudo dd if=ubuntu-server-24.04.iso of=/dev/sdX bs=4M status=progress && sync
```

**No macOS:**
```bash
# Identifique o pendrive
diskutil list

# Desmonte o disco (substitua diskX pelo seu dispositivo)
diskutil unmountDisk /dev/diskX

# Copie a ISO
sudo dd if=ubuntu-server-24.04.iso of=/dev/rdiskX bs=1m
```

#### 1.3. Instalar Ubuntu Server

1. **Boot pelo pendrive:**
   - Insira o pendrive no servidor
   - Acesse o BIOS/UEFI (geralmente F2, F12, DEL ou ESC)
   - Configure para dar boot pelo USB

2. **Instalação:**
   - Selecione o idioma (Português ou English)
   - Escolha "Install Ubuntu Server"
   - Configure rede (DHCP ou IP fixo recomendado)
   - Configure proxy se necessário (geralmente deixar em branco)
   - Configure particionamento (padrão é adequado)
   - **IMPORTANTE:** Crie um usuário (ex: rattones)
   - Marque a opção **"Install OpenSSH server"**
   - Não selecione pacotes adicionais (faremos via post-install)
   - Aguarde a instalação e reinicie

3. **Primeiro acesso:**
   ```bash
   # Login com usuário criado
   # Atualize o sistema
   sudo apt update && sudo apt upgrade -y
   ```

### Passo 2: Instalar Git e Clonar o Repositório

```bash
# Instalar Git
sudo apt install -y git

# Criar pasta de projetos
mkdir -p ~/projetos

# Clonar este repositório
cd ~/projetos
git clone https://github.com/rattones/automacoes.git
cd automacoes
```

### Passo 3: Executar Post-Instalação

Este script configurará todo o ambiente automaticamente:

**Opção 1: Se você já clonou o repositório**
```bash
# Baixar o script bootstrap
wget https://raw.githubusercontent.com/rattones/automacoes/main/post-install.sh

# Dar permissão de execução
chmod +x post-install.sh

# Executar post-instalação
./post-install.sh
```

**Link direto:** [📥 Baixar post-install.sh](https://raw.githubusercontent.com/rattones/automacoes/main/post-install.sh)

**Como funciona:**

O script de post-instalação é modular e funciona em duas etapas:

1. **Bootstrap (`post-install.sh`)**: Script inicial que pode ser baixado diretamente
   - Atualiza o sistema
   - Instala git e curl
   - Clona o repositório de automações
   - Executa a instalação completa

2. **Instalação Modular** (`lib/post-install/*.sh`): Módulos especializados executados em sequência
   - `setup-ssh.sh` - SSH Server para acesso remoto
   - `setup-zsh.sh` - Zsh + Powerlevel10k
   - `setup-github-tools.sh` - GitHub CLI e Copilot CLI (opcional)
   - `setup-cockpit.sh` - Cockpit Web Console
   - `setup-docker.sh` - Docker + Docker Compose
   - `setup-nodejs.sh` - Node.js via NVM
   - `setup-containers.sh` - Deploy containers (Crafty, HAOS)
   - `setup-projects.sh` - Restauração de backups

**O que será instalado:**
- ✅ Atualização completa do sistema
- ✅ Pacotes essenciais (curl, git, sqlite3, zsh, openssh-server)
- ✅ SSH Server para acesso remoto
- ✅ Zsh com Oh My Zsh e tema Powerlevel10k
- 🔹 GitHub CLI (gh) - Opcional
- 🔹 GitHub Copilot CLI - Opcional (requer gh)
- ✅ Cockpit Web Console (acesso web: https://[IP]:9090)
- ✅ Docker + Docker Compose (sem necessidade de sudo)
- ✅ Node.js LTS (via NVM)
- ✅ Estrutura de diretórios para containers
- ✅ Containers: Home Assistant e Crafty Controller
- ✅ Restauração automática de backups de projetos
- ✅ Restauração de configurações do Zsh (.zshrc e .p10k.zsh)

**Tempo estimado:** 10-20 minutos (depende da velocidade da internet)

### Passo 4: Finalizar Configuração

Após a execução do post-install:

```bash
# Fazer logout e login novamente para usar docker sem sudo
exit

# Ou aplicar as permissões temporariamente
newgrp docker

# Verificar containers em execução
docker ps

# Acessar serviços:
# - SSH: ssh usuario@[IP-do-servidor] (porta 22)
# - Cockpit: https://[IP-do-servidor]:9090
# - Crafty: http://[IP-do-servidor]:8000
# - Home Assistant: http://[IP-do-servidor]:8123
```

---

## 📋 Estrutura do Projeto

```
automacoes/
├── atualizar_servidor.sh          # Script orquestrador - atualização automática
├── post-install.sh                # Script bootstrap - instalação inicial
├── lib/                           # Bibliotecas de funções
│   ├── logging.sh                 # Sistema de logs (usado por todos os scripts)
│   ├── atualizar_sistema.sh       # Atualização de pacotes do SO
│   ├── atualizar_container.sh     # Atualização de containers Docker
│   ├── atualizar_nodejs.sh        # Atualização de Node.js, NVM e npm
│   ├── verificar_sistema.sh       # Verificações e estatísticas
│   └── post-install/              # Módulos de instalação inicial
│       ├── main-install.sh        # Orquestrador da instalação
│       ├── setup-ssh.sh           # SSH Server
│       ├── setup-zsh.sh           # Zsh + Powerlevel10k
│       ├── setup-github-tools.sh  # GitHub CLI + Copilot CLI
│       ├── setup-cockpit.sh       # Cockpit Web Console
│       ├── setup-docker.sh        # Docker + Docker Compose
│       ├── setup-nodejs.sh        # Node.js via NVM
│       ├── setup-containers.sh    # Deploy containers
│       └── setup-projects.sh      # Restauração de backups
├── backups/                       # Backups de configurações
│   ├── crafty/compose.yml         # Backup Crafty Controller
│   ├── haos/compose.yml           # Backup Home Assistant
│   ├── zsh/.zshrc                 # Backup configuração Zsh
│   ├── zsh/.p10k.zsh              # Backup configuração Powerlevel10k
│   ├── projetos/                  # Backups de projetos (.zip)
│   └── README.md                  # Documentação de backups
└── logs/                          # Logs de execução (não versionado)
```

## Componentes

### 1. Sistema de Instalação Inicial

#### post-install.sh (Bootstrap)
- Script standalone que pode ser baixado diretamente
- Instala dependências mínimas (git, curl)
- Clona o repositório de automações
- Delega para `main-install.sh`

#### lib/post-install/main-install.sh (Orquestrador)
- Executa todos os módulos de instalação em sequência
- Exibe resumo final e próximos passos
- Gerencia falhas sem interromper toda a instalação

#### Módulos de Instalação
- **setup-ssh.sh**: Instala e configura OpenSSH Server
- **setup-zsh.sh**: Instala Zsh, Oh My Zsh e Powerlevel10k
- **setup-github-tools.sh**: GitHub CLI e Copilot CLI (opcionais)
- **setup-cockpit.sh**: Cockpit Web Console
- **setup-docker.sh**: Docker, Docker Compose e configuração de grupos
- **setup-nodejs.sh**: Node.js LTS via NVM
- **setup-containers.sh**: Deploy de containers (Crafty, HAOS)
- **setup-projects.sh**: Restauração de backups de projetos

### 2. Sistema de Atualização Automática

#### atualizar_servidor.sh (Orquestrador)
- Coordena a execução de todos os módulos de atualização
- Gerencia a configuração centralizada
- Define containers a serem atualizados
- Controla fluxo de execução

### 3. Biblioteca de Logging (lib/logging.sh)
**Funções:**
- `log()` - Log padrão com timestamp
- `log_erro()` - Log de erros (vermelho)
- `log_sucesso()` - Log de sucesso (verde)
- `log_aviso()` - Log de avisos (amarelo)
- `log_info()` - Log informativo (azul)
- `log_separador()` - Separador visual
- `inicializar_log()` - Inicializa sistema de logs

### 4. Atualização de Sistema (lib/atualizar_sistema.sh)
**Funções:**
- `atualizar_lista_pacotes()` - apt update
- `verificar_pacotes_disponiveis()` - Conta pacotes atualizáveis
- `upgrade_pacotes()` - apt upgrade
- `dist_upgrade_sistema()` - apt dist-upgrade
- `remover_pacotes_desnecessarios()` - apt autoremove
- `limpar_cache_apt()` - apt autoclean
- `atualizar_sistema_completo()` - Executa todo o fluxo

### 5. Atualização de Containers (lib/atualizar_container.sh)
**Funções:**
- `atualizar_container(nome, diretório)` - Atualiza um container específico
- `limpar_imagens_antigas()` - Remove imagens Docker não utilizadas
- `atualizar_containers(...)` - Atualiza múltiplos containers

### 6. Atualização de Node.js (lib/atualizar_nodejs.sh)
**Funções:**
- `atualizar_nvm()` - Atualiza NVM via git
- `atualizar_nodejs()` - Atualiza para versão LTS
- `atualizar_npm()` - Atualiza NPM para última versão
- `limpar_versoes_antigas_nodejs()` - Remove versões antigas do Node.js
- `atualizar_nodejs_completo()` - Executa todo o fluxo

### 7. Verificação de Sistema (lib/verificar_sistema.sh)
**Funções:**
- `registrar_info_sistema()` - Registra informações do sistema
- `verificar_necessidade_reinicializacao()` - Verifica se requer reboot
- `mostrar_estatisticas()` - Exibe uso de disco, memória, etc
- `enviar_notificacao_email()` - Envia notificação por email

### 6. Atualização de Node.js (lib/atualizar_nodejs.sh)
**Funções:**
- `verificar_nvm_instalado()` - Verifica se NVM está instalado
- `atualizar_nvm()` - Atualiza NVM para versão mais recente
- `atualizar_nodejs()` - Atualiza Node.js para versão LTS
- `atualizar_npm()` - Atualiza npm para versão mais recente
- `limpar_versoes_antigas_nodejs()` - Remove versões antigas do Node.js
- `atualizar_nodejs_completo()` - Executa todo o fluxo de atualização

---

## 🔧 Uso Diário

### Atualização Manual do Servidor
```bash
sudo ./atualizar_servidor.sh
```

### Adicionar Novo Container
Edite o array `CONTAINERS` no script principal:
```bash
declare -a CONTAINERS=(
    "Crafty" "/home/rattones/crafty"
    "Home Assistant" "/home/rattones/haos"
    "Novo Container" "/caminho/do/container"
)
```

### Automatizar com Cron
```bash
sudo crontab -e
# Executar todo domingo às 3h
0 3 * * 0 /home/rattones/projetos/automacoes/atualizar_servidor.sh
```

## Logs
Logs são salvos em: `/home/rattones/projetos/automacoes/logs/atualizacao_YYYYMMDD_HHMMSS.log`

## Notificações por Email
Configure a variável `EMAIL_DESTINO` no script principal para receber notificações.

## Personalização
Cada módulo pode ser usado independentemente importando as funções necessárias:
```bash
source /home/rattones/projetos/automacoes/lib/logging.sh
source /home/rattones/projetos/automacoes/lib/atualizar_container.sh

inicializar_log "/home/rattones/projetos/automacoes/logs" "/home/rattones/projetos/automacoes/logs/meu_script.log"
atualizar_container "MeuApp" "/home/user/meuapp"
```

## Benefícios da Modularização
- ✅ Código reutilizável
- ✅ Fácil manutenção
- ✅ Testes independentes
- ✅ Adição simples de novas funcionalidades
- ✅ Logs centralizados e consistentes

---

## 🧪 Testes Unitários

O projeto inclui uma suíte completa de testes automatizados usando **BATS** (Bash Automated Testing System).

### Executar Testes

```bash
cd tests
./run_tests.sh
```

**Cobertura dos testes:**
- ✅ Estrutura do projeto (18 testes)
- ✅ Bootstrap de instalação (6 testes)  
- ✅ Módulos de post-install (16 testes)
- ✅ Biblioteca de logging (10 testes)
- ✅ Sistema de atualização (7 testes)
- ✅ Atualização de containers (7 testes)

**Total: 64 testes automatizados**

Para mais detalhes, consulte: [tests/README.md](tests/README.md)
