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
   - `setup-monitor.sh` - Monitor web do servidor (HTTPS, porta 8180)

**O que será instalado:**
- ✅ Atualização completa do sistema
- ✅ Pacotes essenciais (curl, git, sqlite3, zsh, openssh-server)
- ✅ SSH Server para acesso remoto
- ✅ Zsh com Oh My Zsh e tema Powerlevel10k
- ✅ GitHub CLI (gh) - Opcional
- ✅ GitHub Copilot CLI - Opcional (requer gh)
- ✅ Cockpit Web Console (acesso web: https://[IP]:9090)
- ✅ Docker + Docker Compose (sem necessidade de sudo)
- ✅ Node.js LTS (via NVM)
- ✅ Estrutura de diretórios para containers
- ✅ Containers: Home Assistant e Crafty Controller
- ✅ Restauração automática de backups de projetos
- ✅ Restauração de configurações do Zsh (.zshrc e .p10k.zsh)
- ✅ Monitor web do servidor (porta 8180)

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
# - Monitor do servidor: https://[IP-do-servidor]:8180
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
│   ├── converter_log_md.sh        # Conversor de logs para Markdown
│   ├── backup_configs.sh          # Backup de configurações dos containers
│   └── post-install/              # Módulos de instalação inicial
│       ├── main-install.sh        # Orquestrador da instalação
│       ├── setup-ssh.sh           # SSH Server
│       ├── setup-zsh.sh           # Zsh + Powerlevel10k
│       ├── setup-github-tools.sh  # GitHub CLI + Copilot CLI
│       ├── setup-cockpit.sh       # Cockpit Web Console
│       ├── setup-docker.sh        # Docker + Docker Compose
│       ├── setup-nodejs.sh        # Node.js via NVM
│       ├── setup-containers.sh    # Deploy containers
│       ├── setup-projects.sh      # Restauração de backups
│       └── setup-monitor.sh       # Monitor web do servidor
├── monitor/                       # Painel web de monitoramento
│   ├── server.py                  # Backend Flask (porta 8180)
│   ├── setup.sh                   # Instalação do monitor
│   ├── requirements.txt           # Dependências Python
│   ├── templates/index.html       # Interface web (SPA)
│   ├── static/                    # CSS, JS (módulos ES por aba), favicons
│   ├── scripts/                   # Scripts de coleta de métricas
│   └── data/                      # CA local, certificados e watchlist (não versionado)
├── backups/                       # Backups de configurações
│   ├── crafty/compose.yml         # Backup Crafty Controller
│   ├── haos/compose.yml           # Backup Home Assistant
│   ├── zsh/.zshrc                 # Backup configuração Zsh
│   ├── zsh/.p10k.zsh              # Backup configuração Powerlevel10k
│   ├── projetos/                  # Backups de projetos (.zip)
│   └── README.md                  # Documentação de backups
├── logs/                          # Logs de execução (não versionado)
└── logs_md/                       # Logs convertidos para Markdown (não versionado)
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
- **setup-monitor.sh**: Monitor web (dependências Python, serviço systemd, CA local e certificado HTTPS, sudoers do `dmidecode`)

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
- `log_progresso()` - Log de progresso (azul)
- `log_separador()` / `log_subseparador()` - Separadores visuais
- `log_indent()` - Log indentado (subetapas)
- `inicializar_log()` - Inicializa sistema de logs

### 4. Atualização de Sistema (lib/atualizar_sistema.sh)
**Funções:**
- `atualizar_lista_pacotes()` - apt update
- `verificar_pacotes_disponiveis()` - Conta pacotes atualizáveis
- `upgrade_pacotes()` - apt upgrade
- `dist_upgrade_sistema()` - apt dist-upgrade
- `remover_pacotes_desnecessarios()` - apt autoremove; simula antes (`apt-get -s`) e registra quantos pacotes foram removidos
- `limpar_cache_apt()` - apt autoclean
- `atualizar_sistema_completo()` - Executa todo o fluxo

### 5. Atualização de Containers (lib/atualizar_container.sh)
**Funções:**
- `atualizar_container(nome, diretório)` - `docker compose pull` + `up -d` e registra o status dos containers
- `limpar_imagens_antigas()` - Remove imagens sem nenhum container associado e todo o build cache não utilizado (`prune -a`), além de volumes anônimos. Volumes nomeados são preservados
- `atualizar_containers(...)` - Atualiza múltiplos containers

### 6. Atualização de Node.js (lib/atualizar_nodejs.sh)
**Funções:**
- `verificar_nvm_instalado()` - Verifica se NVM está instalado
- `atualizar_nvm()` - Atualiza NVM para a tag mais recente via git
- `atualizar_nodejs()` - Atualiza Node.js para a versão LTS
- `atualizar_npm()` - Atualiza npm; só reinstala quando há versão nova publicada
- `limpar_versoes_antigas_nodejs()` - Remove versões instaladas diferentes da atual (ignora aliases do NVM)
- `atualizar_nodejs_completo()` - Executa todo o fluxo

O log distingue "já está na versão mais recente" de "atualizado: X → Y" para NVM, Node.js e npm.

### 7. Verificação de Sistema (lib/verificar_sistema.sh)
**Funções:**
- `registrar_info_sistema()` - Registra informações do sistema
- `verificar_necessidade_reinicializacao()` - Verifica se requer reboot (e agenda reinicialização automática em 5 minutos)
- `mostrar_estatisticas()` - Exibe uso de disco, memória, etc
- `enviar_notificacao_email()` - Envia notificação por email

### 8. Backup de Configurações (lib/backup_configs.sh)
**Funções:**
- `backup_crafty()` / `backup_home_assistant()` - Backup específico de cada container
- `backup_container_config(nome, diretório)` - Backup de um container
- `backup_todas_configs()` - Backup de todos os containers do array `CONTAINERS`
- `listar_backups()` - Lista backups existentes
- `restaurar_backup()` - Restaura um backup

### 9. Conversor de Logs (lib/converter_log_md.sh)
Converte logs de execução para Markdown — ver [Ferramentas Adicionais](#️-ferramentas-adicionais).

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

### Visualização de Logs
Para visualizar logs em formato Markdown (mais legível):
```bash
./lib/converter_log_md.sh logs/atualizacao_20240128_030000.log
```
Os arquivos convertidos ficam em: `/home/rattones/projetos/automacoes/logs_md/`

## 🛠️ Diagnóstico e Manutenção

### Script de Diagnóstico APT

Se você encontrar problemas com atualizações, use o script de diagnóstico:

```bash
sudo ./diagnostico_apt.sh
```

**O que ele faz:**
- ✅ Testa funcionamento do APT
- ✅ Detecta conflitos de repositórios
- ✅ Identifica chaves GPG duplicadas
- ✅ Cria backups automáticos
- ✅ Oferece correção automática
- ✅ Valida após correção

**Problemas detectados automaticamente:**
- 🔍 Conflitos de chaves GPG (Signed-By)
- 🔍 Configurações duplicadas de repositórios
- 🔍 Problemas de conectividade
- 🔍 Chaves GPG ausentes
- 🔍 Dependências quebradas

### Validação APT Automática

O script `atualizar_servidor.sh` valida automaticamente o sistema APT antes de iniciar as atualizações:

1. **Verifica integridade do sistema de pacotes**
   ```bash
   apt-get check
   ```

2. **Testa atualização de lista de pacotes**
   ```bash
   apt update
   ```

3. **Diagnostica erros específicos:**
   - Conflitos de Signed-By
   - Problemas de rede
   - Chaves GPG ausentes

4. **Referencia diagnóstico completo**
   - Em caso de falha, sugere executar `diagnostico_apt.sh`

### Histórico de Problemas Conhecidos

Para detalhes sobre problemas já resolvidos e soluções aplicadas, consulte:
- [ANALISE_FALHAS.md](ANALISE_FALHAS.md) - Análise detalhada de falhas críticas

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

## 🛠️ Ferramentas Adicionais

### Conversor de Logs para Markdown

O script `converter_log_md.sh` converte arquivos de log em formato Markdown para melhor visualização e compartilhamento.

#### Uso Básico
```bash
# Converter log específico
./lib/converter_log_md.sh logs/atualizacao_20240128_030000.log

# Converter último log (padrão)
./lib/converter_log_md.sh
```

#### Funcionalidades
- ✅ **Remoção de códigos ANSI** - Remove cores e formatação do terminal
- ✅ **Detecção de tabelas** - Converte tabelas Docker (ps, stats) para Markdown
- ✅ **Formatação de mensagens** - Destaque para [SUCESSO], [ERRO], [AVISO], [INFO]
- ✅ **Estrutura organizada** - Headers, separadores e formatação limpa
- ✅ **Diretório automático** - Cria pasta `logs_md/` para arquivos convertidos

#### Exemplo de Saída
```markdown
# Log de Atualização - 2024-01-28 03:00:00

## ✅ SUCESSO
Lista de pacotes atualizada com sucesso

## 📊 Containers Docker
| CONTAINER ID | IMAGE | STATUS | PORTS | NAMES |
|--------------|-------|--------|-------|-------|
| abc123def456 | crafty:latest | Up 2 hours | 0.0.0.0:8000->8000/tcp | crafty |
| def456ghi789 | homeassistant:latest | Up 2 hours | 0.0.0.0:8123->8123/tcp | haos |

## ✅ SUCESSO
Atualização do sistema concluída
```

#### Configuração
As variáveis podem ser personalizadas:
```bash
export LOGS_DIR="/caminho/dos/logs"          # Diretório de logs fonte
export LOGS_MD_DIR="/caminho/dos/logs_md"    # Diretório de saída
```

---

## 💾 Backup de Configurações

O sistema inclui funcionalidade automática de backup das configurações dos containers gerenciados.

### Funcionalidades de Backup
- ✅ **Backup sob demanda** - Funções para salvar configurações de um ou de todos os containers
- ✅ **Múltiplos formatos** - Arquivos individuais e pacotes tar.gz
- ✅ **Estrutura organizada** - Backups separados por container
- ✅ **Histórico preservado** - Múltiplas versões mantidas
- ✅ **Containers suportados** - Crafty Controller e Home Assistant

### Estrutura de Backups
```
backups/
├── crafty/
│   ├── compose.yml                 # Backup do docker-compose
│   ├── test.cfg                    # Arquivos de configuração
│   └── ...                         # Outros arquivos de config
└── haos/
    ├── compose.yml                 # Backup do docker-compose
    ├── homeassistant_config_20240128_030000.tar.gz  # Config completo
    └── ...                         # Outros backups
```

### Como Usar
```bash
# Carregar bibliotecas necessárias
source lib/logging.sh
source lib/backup_configs.sh

# Fazer backup de um container específico
backup_container_config "Crafty" "/home/rattones/crafty"
backup_container_config "Home Assistant" "/home/rattones/haos"

# Fazer backup de todos os containers
declare -a CONTAINERS=(
    "Crafty" "/home/rattones/crafty"
    "Home Assistant" "/home/rattones/haos"
)
backup_todas_configs

# Listar backups existentes
listar_backups
```

### Pastas de Configuração
- **Crafty Controller**: `docker/config/` (mapeado para `/crafty/app/config`)
- **Home Assistant**: `config/` ou `/home/rattones/.homeassistant` ou `/config`

### Integração com Atualização
O `atualizar_servidor.sh` **não** chama o backup hoje — execute-o manualmente (ou via cron) antes de atualizações que mudem configurações dos containers.

---

## 🖥️ Monitor Web do Servidor

Painel web de monitoramento em tempo real, acessível pelo browser, com autenticação PAM e atualização automática.

### Acesso
```
https://[IP-do-servidor]:8180
```
Login com usuário e senha do sistema operacional.

### Instalação
```bash
bash monitor/setup.sh
```
O `monitor/setup.sh` é um atalho para `lib/post-install/setup-monitor.sh`: instala dependências Python, gera a CA local e o certificado HTTPS, cria o serviço systemd e o inicia automaticamente.

A interface atualiza as métricas a cada 5 s e as abas/watchlist a cada 15 s.

### HTTPS
O monitor roda em HTTPS por padrão, usando uma **CA (autoridade certificadora) local
própria** em vez de um certificado self-signed solto:

1. Na primeira instalação, `setup.sh` gera uma CA local em `monitor/data/ca/` (válida por
   10 anos) e usa-a para emitir o certificado do servidor em `monitor/data/certs/` (válido
   por 825 dias, com SAN cobrindo hostname, `hostname.local` e IP da máquina)
2. `CERT_PATH`/`KEY_PATH` são configurados automaticamente no `.env`
3. Reinstalações reemitem o certificado do servidor automaticamente se o hostname/IP mudar,
   sem gerar uma nova CA

**Para o navegador parar de exibir aviso de segurança**, instale o certificado da CA
(`monitor/data/ca/ca.pem` — nunca a chave `ca-key.pem`) como "Autoridade Certificadora Raiz
confiável" em cada dispositivo que acessa o painel (uma vez por dispositivo):
- **Windows**: duplo-clique no `.pem` → Instalar Certificado → Máquina Local → Autoridades
  de Certificação Raiz Confiáveis
- **macOS**: abra no Keychain Access → adicione ao chaveiro "Sistema" → defina como
  "Sempre Confiar"
- **Linux (navegadores baseados em NSS/Chrome)**: `certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Monitor CA" -i ca.pem`
- **Android**: Configurações → Segurança → Credenciais → Instalar certificado → CA
- **iOS**: envie o arquivo por e-mail/AirDrop, instale o perfil e depois ative confiança
  total em Ajustes → Geral → Sobre → Confiança de Certificado

Na inicialização, `server.py` valida que o par certificado/chave existe e pode ser
carregado; se `CERT_PATH`/`KEY_PATH` estiverem configurados mas inválidos ou ausentes, o
servidor **não sobe** em modo inseguro — o processo é encerrado com erro no log. Para usar
um certificado de terceiros (ex: Let's Encrypt) em vez da CA local, basta sobrescrever
`CERT_PATH`/`KEY_PATH` no `.env` e reiniciar o serviço. Deixar ambas as variáveis em branco
faz o servidor subir em HTTP puro.

### Funcionalidades

#### Aba Métricas
- **CPU**: gauge de uso global + grade de tiles por núcleo (uso % e temperatura via coretemp)
- **GPU**: tiles por GPU detectada via `lshw -C video` — barra de uso, temperatura, memória usada/total, versão do driver. Suporte a NVIDIA (nvidia-smi), AMD (amdgpu sysfs) e Nouveau
- **RAM**: gauge global + listagem de DIMMs via `dmidecode` (slot, tamanho, tipo DDR, fabricante, velocidade)
- **Disco**: barra de uso por ponto de montagem
- **Sistema**: hostname, kernel, uptime, load average

#### Aba Rede
- Tabela de interfaces (estado, MAC, IPs, velocidade rx/tx em Mbps)
- **Serviços em Escuta (watchlist)**: alvos TCP ou HTTP/HTTPS adicionados manualmente, com checagem periódica de status online/offline e latência
  - Modal de adicionar com campos separados de Host, Porta (opcional), Caminho (opcional) e checkbox "Usar HTTPS (TLS)"; colar uma URL completa no Host também funciona
  - Ao adicionar, o servidor sonda `host:porta` nos dois tipos (HTTP/S e TCP) e, se só o outro tipo responder, sugere a troca antes de salvar (ex.: HTTPS numa porta SSH → TCP)
  - Alvos HTTPS aceitam certificado autoassinado (painéis internos, roteadores, NAS)
  - Colunas com formato uniforme: Alvo `host:porta`, Tipo `HTTPS`/`HTTP`/`TCP`, Detalhe `HTTP 200 · 45 ms` ou `TCP · 12 ms`; erros offline traduzidos ("Conexão recusada", "Host não encontrado (DNS)", "A porta não responde HTTPS"…)
  - Aviso quando um alvo recém-adicionado já está offline
- **Portas Detectadas Automaticamente**: portas em escuta locais (via `ss`), em bloco recolhido por padrão, com filtro por porta/processo/serviço e contador
- Mini-gráfico (sparkline) com o histórico das últimas 20 leituras de latência de cada alvo da watchlist; leituras offline aparecem como marcador na base do gráfico
- Histórico de latência persistido em `monitor/data/watchlist_historico.json`, removido automaticamente quando o alvo é excluído da watchlist

#### Aba Serviços
- Lista de serviços systemd monitorados com estado, versão e ações (reiniciar, parar, recarregar)
- Detecção de atualizações disponíveis via apt

#### Aba Containers
- Lista de containers Docker com estado e ações (start, stop, restart)
- Uso de recursos por container (CPU, memória, swap, rede, disco) ao expandir a linha, via `docker stats --no-stream`
- Atualização de imagem via `docker pull` + `compose up`

#### Aba Logs
- Lista dos arquivos `.log` de execução em `logs/` (atualizações do servidor, atualizações de container, setup do monitor), do mais recente para o mais antigo, com tipo, tamanho e data
- Paginação de 10 em 10 no backend (`GET /api/logs?page=N`)
- Selecionar um log abre um painel com o conteúdo (`GET /api/logs/<nome>`), com códigos ANSI removidos e destaque de cor por nível (ERRO, SUCESSO, AVISO, INFO, PROGRESSO)
- Leitura limitada a 5000 linhas / 2 MB por log; nome do arquivo validado contra path traversal

#### Header
| Botão | Cor | Ação |
|-------|-----|------|
| ↻ | cinza | Refresh manual imediato |
| ↻ Monitor | amarelo | Reinicia `monitor-servidor.service` (pede sudo) |
| ⏻ Servidor | vermelho | Reinicia o servidor inteiro (pede sudo) |
| Sair | cinza | Encerra a sessão |

### Estrutura
```
monitor/
├── server.py                # Backend Flask (porta 8180, auth PAM)
├── setup.sh                 # Atalho para lib/post-install/setup-monitor.sh
├── requirements.txt         # Dependências Python
├── .env.example             # Exemplo de configuração
├── templates/
│   └── index.html           # SPA Jinja2
├── static/
│   ├── js/                  # Frontend Vanilla JS (módulos ES)
│   │   ├── main.js          # Inicialização, timers e header
│   │   ├── api.js, state.js, ui.js, utils.js
│   │   └── tabs/            # metricas, rede, servicos, containers, logs
│   ├── style.css            # Dark theme CSS
│   ├── favicon.svg          # Ícone SVG
│   └── favicon.ico          # Ícone ICO
├── data/                    # Gerado na instalação (não versionado)
│   ├── ca/                  # CA local (ca.pem, ca-key.pem)
│   ├── certs/               # Certificado do servidor
│   ├── watchlist.json       # Alvos da watchlist
│   └── watchlist_historico.json  # Histórico de latência
└── scripts/
    ├── get_status.sh        # CPU, GPU, RAM, disco, sistema
    ├── get_network.sh       # Interfaces e portas
    ├── get_services.sh      # Serviços systemd
    ├── get_containers.sh    # Containers Docker
    ├── service_action.sh    # Ações em serviços
    └── container_action.sh  # Ações em containers
```

### Segurança
- Autenticação PAM (usuário real do SO)
- Rate limiting de login: 5 tentativas / 5 minutos
- Validação de entradas com regex whitelist
- Ações destrutivas exigem confirmação com senha sudo (nunca armazenada)
- `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SAMESITE=Lax`
- Scripts executados via `subprocess.run` com lista de argumentos (sem shell injection)

### Serviço systemd
```bash
# Ver status
systemctl status monitor-servidor.service

# Reiniciar após mudanças no código
sudo systemctl restart monitor-servidor.service

# Ver logs em tempo real
journalctl -u monitor-servidor.service -f
```

### Dependências adicionais
```bash
# Para leitura de DIMMs
sudo apt install -y dmidecode

# Regra sudoers (criada pelo setup.sh)
# /etc/sudoers.d/monitor-dmidecode
# rattones ALL=(ALL) NOPASSWD: /usr/sbin/dmidecode
```

---

## 🧪 Testes Unitários

O projeto inclui uma suíte completa de testes automatizados usando **BATS** (Bash Automated Testing System).

### Executar Testes

```bash
cd tests
./run_tests.sh
```

**Cobertura dos testes:**
- ✅ Estrutura do projeto (19 testes)
- ✅ Bootstrap de instalação (6 testes)
- ✅ Módulos de post-install (16 testes)
- ✅ Biblioteca de logging (10 testes)
- ✅ Sistema de atualização (9 testes)
- ✅ Atualização de containers (10 testes)
- ✅ Atualização de Node.js (5 testes)
- ✅ Conversor de logs para Markdown (11 testes)
- ✅ Backup de configurações (16 testes)
- ✅ Detecção de duplicatas APT (16 testes)

**Total: 118 testes automatizados**

Para mais detalhes, consulte: [tests/README.md](tests/README.md)

---

## 🤖 Sobre o Projeto

Este projeto foi **inteiramente gerado por IA** utilizando **GitHub Copilot** (Claude Sonnet 4.5) e supervisionado pelo analista de sistemas **[Marcelo Ratton](https://github.com/rattones)**.

A abordagem de desenvolvimento assistido por IA permitiu:
- Código modular e bem estruturado
- Cobertura completa de testes automatizados
- Documentação detalhada e atualizada
- Análise proativa de falhas e implementação de soluções preventivas

**Desenvolvido por:** GitHub Copilot  
**Supervisionado por:** [@rattones](https://github.com/rattones) - Analista de Sistemas
