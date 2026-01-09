# Sistema de Automação de Atualização do Servidor

Sistema modular de atualização automática do servidor, dividido em componentes reutilizáveis.

## Estrutura do Projeto

```
automacoes/
├── atualizar_servidor.sh          # Script orquestrador principal
├── lib/                           # Bibliotecas de funções
│   ├── logging.sh                 # Sistema de logs
│   ├── atualizar_sistema.sh       # Atualização de pacotes do SO
│   ├── atualizar_container.sh     # Atualização de containers Docker
│   └── verificar_sistema.sh       # Verificações e estatísticas
├── backups/                       # Backups de configurações
│   ├── crafty/compose.yml         # Backup Crafty Controller
│   ├── haos/compose.yml           # Backup Home Assistant
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

## Uso

### Execução Manual
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
