# Backups de Configuração dos Containers

Este diretório contém backups dos arquivos de configuração dos containers Docker gerenciados pelo sistema de automação.

## Estrutura

```
backups/
├── crafty/
│   └── compose.yml      # Configuração do Crafty Controller
└── haos/
    └── compose.yml      # Configuração do Home Assistant
```

## Uso

### Restaurar Configuração
Para restaurar uma configuração de backup:

```bash
# Crafty
cp backups/crafty/compose.yml /home/rattones/crafty/compose.yml

# Home Assistant
cp backups/haos/compose.yml /home/rattones/haos/compose.yml
```

### Atualizar Backup
Após modificar as configurações dos containers:

```bash
# Atualizar backup do Crafty
cp /home/rattones/crafty/compose.yml backups/crafty/compose.yml

# Atualizar backup do Home Assistant
cp /home/rattones/haos/compose.yml backups/haos/compose.yml
```

## Nota
Estes backups são versionados no Git para manter um histórico das alterações de configuração.
