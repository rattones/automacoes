# Backups de Projetos

Este diretório é usado para armazenar backups compactados (.zip) de projetos que serão restaurados automaticamente durante a post-instalação.

## Como usar

### Criar backup de projeto
```bash
# Comprimir um projeto
cd ~/projetos
zip -r backup_meu_projeto_$(date +%Y%m%d).zip meu_projeto/

# Mover para pasta de backups
mv backup_meu_projeto_*.zip ~/projetos/automacoes/backups/projetos/
```

### Restauração automática
Durante a execução do `post-install.sh`, todos os arquivos `.zip` nesta pasta serão automaticamente extraídos para `~/projetos/`.

## Estrutura
```
backups/projetos/
├── backup_projeto1_20260109.zip
├── backup_projeto2_20260109.zip
└── README.md
```

## Notas
- Os backups devem estar no formato `.zip`
- Arquivos serão extraídos preservando a estrutura de diretórios
- Em caso de conflito, arquivos existentes serão sobrescritos
