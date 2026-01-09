# Sistema de Automação de Atualização do Servidor

Sistema modular de atualização automática do servidor, dividido em componentes reutilizáveis.

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
# Dar permissão de execução
chmod +x post-install.sh

# Executar post-instalação
./post-install.sh
```

**Opção 2: Download direto do script (sem clonar o repositório)**
```bash
# Baixar o script
wget https://raw.githubusercontent.com/rattones/automacoes/main/post-install.sh

# Dar permissão de execução
chmod +x post-install.sh

# Executar
./post-install.sh
```

**Link direto:** [📥 Baixar post-install.sh](https://raw.githubusercontent.com/rattones/automacoes/main/post-install.sh)

**O que será instalado:**
- ✅ Atualização completa do sistema
- ✅ Pacotes essenciais (curl, git, sqlite3)
- ✅ Cockpit Web Console (acesso web: https://[IP]:9090)
- ✅ Docker + Docker Compose (sem necessidade de sudo)
- ✅ Node.js LTS (via NVM)
- ✅ Estrutura de diretórios para containers
- ✅ Containers: Home Assistant e Crafty Controller
- ✅ Restauração automática de backups de projetos

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
# - Cockpit: https://[IP-do-servidor]:9090
# - Crafty: http://[IP-do-servidor]:8000
# - Home Assistant: http://[IP-do-servidor]:8123
```

---

## 📋 Estrutura do Projeto

```
automacoes/
├── atualizar_servidor.sh          # Script orquestrador principal
├── post-install.sh                # Script de post-instalação (executar uma vez)
├── lib/                           # Bibliotecas de funções
│   ├── logging.sh                 # Sistema de logs
│   ├── atualizar_sistema.sh       # Atualização de pacotes do SO
│   ├── atualizar_container.sh     # Atualização de containers Docker
│   └── verificar_sistema.sh       # Verificações e estatísticas
├── backups/                       # Backups de configurações
│   ├── crafty/compose.yml         # Backup Crafty Controller
│   ├── haos/compose.yml           # Backup Home Assistant
│   ├── projetos/                  # Backups de projetos (.zip)
│   └── README.md                  # Documentação de backups
└── logs/                          # Logs de execução (não versionado)
```

## Componentes

### 1. Script Orquestrador (atualizar_servidor.sh)
- Coordena a execução de todos os módulos
- Gerencia a configuração centralizada
- Define containers a serem atualizados
- Controla fluxo de execução

### 2. Biblioteca de Logging (lib/logging.sh)
**Funções:**
- `log()` - Log padrão com timestamp
- `log_erro()` - Log de erros (vermelho)
- `log_sucesso()` - Log de sucesso (verde)
- `log_aviso()` - Log de avisos (amarelo)
- `log_info()` - Log informativo (azul)
- `log_separador()` - Separador visual
- `inicializar_log()` - Inicializa sistema de logs

### 3. Atualização de Sistema (lib/atualizar_sistema.sh)
**Funções:**
- `atualizar_lista_pacotes()` - apt update
- `verificar_pacotes_disponiveis()` - Conta pacotes atualizáveis
- `upgrade_pacotes()` - apt upgrade
- `dist_upgrade_sistema()` - apt dist-upgrade
- `remover_pacotes_desnecessarios()` - apt autoremove
- `limpar_cache_apt()` - apt autoclean
- `atualizar_sistema_completo()` - Executa todo o fluxo

### 4. Atualização de Containers (lib/atualizar_container.sh)
**Funções:**
- `atualizar_container(nome, diretório)` - Atualiza um container específico
- `limpar_imagens_antigas()` - Remove imagens Docker não utilizadas
- `atualizar_containers(...)` - Atualiza múltiplos containers

### 5. Verificação de Sistema (lib/verificar_sistema.sh)
**Funções:**
- `registrar_info_sistema()` - Registra informações do sistema
- `verificar_necessidade_reinicializacao()` - Verifica se requer reboot
- `mostrar_estatisticas()` - Exibe uso de disco, memória, etc
- `enviar_notificacao_email()` - Envia notificação por email

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
