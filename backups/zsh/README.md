# Backups de Configuração do Zsh

Este diretório contém backups dos arquivos de configuração do Zsh e Powerlevel10k.

## Arquivos

- `.zshrc` - Configuração principal do Zsh (aliases, plugins, tema, etc)
- `.p10k.zsh` - Configuração do tema Powerlevel10k

## Restauração

Durante a execução do `post-install.sh`, estes arquivos são automaticamente copiados para `$HOME/`:

```bash
cp backups/zsh/.zshrc ~/.zshrc
cp backups/zsh/.p10k.zsh ~/.p10k.zsh
```

## Atualizar Backup

Para atualizar os backups com suas configurações atuais:

```bash
# Copiar configurações atuais
cp ~/.zshrc ~/projetos/automacoes/backups/zsh/.zshrc
cp ~/.p10k.zsh ~/projetos/automacoes/backups/zsh/.p10k.zsh

# Commitar no git
cd ~/projetos/automacoes
git add backups/zsh/
git commit -m "Atualizar configurações do Zsh"
git push
```

## Requisitos

- Zsh instalado (`apt install zsh`)
- Oh My Zsh (instalado automaticamente pelo post-install.sh)
- Powerlevel10k (instalado automaticamente pelo post-install.sh)
- Fontes recomendadas: [MesloLGS NF](https://github.com/romkatv/powerlevel10k#fonts)
