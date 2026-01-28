#!/bin/bash

#########################################
# Script para Converter Logs em Markdown
# Converte logs de atualização para formato Markdown
#########################################

# Diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="$SCRIPT_DIR/../logs"
LOGS_MD_DIR="$SCRIPT_DIR/../logs_md"

# Verificar se o diretório de logs existe
if [ ! -d "$LOGS_DIR" ]; then
    echo "ERRO: Diretório de logs não encontrado: $LOGS_DIR"
    exit 1
fi

# Criar diretório de logs MD se não existir
if [ ! -d "$LOGS_MD_DIR" ]; then
    mkdir -p "$LOGS_MD_DIR"
    echo "Diretório criado: $LOGS_MD_DIR"
fi

# Função para obter o último log
get_latest_log() {
    local latest_log=$(ls -t "$LOGS_DIR"/atualizacao_*.log | head -1)
    echo "$latest_log"
}

# Função para converter log para Markdown
convert_log_to_md() {
    local log_file="$1"
    local md_file="$2"

    # Verificar se o arquivo de log existe
    if [ ! -f "$log_file" ]; then
        echo "ERRO: Arquivo de log não encontrado: $log_file"
        return 1
    fi

    echo "Convertendo $log_file para $md_file..."

    # Iniciar o arquivo MD
    {
        echo "# Log de Atualização do Servidor"
        echo ""
        echo "**Arquivo original:** $log_file"
        echo "**Data de conversão:** $(date)"
        echo ""
    } > "$md_file"

    # Processar o log linha por linha
    while IFS= read -r line; do
        # Remover códigos ANSI
        clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
        # Remover timestamp se presente
        clean_line=$(echo "$clean_line" | sed 's/^\[.*\] //')

        if [[ "$clean_line" == ========================================== ]]; then
            # Separador principal - ignorar ou usar para quebra
            echo "" >> "$md_file"
        elif [[ "$clean_line" == ------------------------------------------ ]]; then
            # Separador sub - ignorar
            :
        elif [[ "$clean_line" =~ ^\[SUCESSO\]\[.*\] ]]; then
            # Sucesso
            message=$(echo "$clean_line" | sed 's/\[SUCESSO\]\[.*\] //')
            echo "- ✅ **Sucesso:** $message" >> "$md_file"
        elif [[ "$clean_line" =~ ^\[ERRO\]\[.*\] ]]; then
            # Erro
            message=$(echo "$clean_line" | sed 's/\[ERRO\]\[.*\] //')
            echo "- ❌ **Erro:** $message" >> "$md_file"
        elif [[ "$clean_line" =~ ^\[AVISO\]\[.*\] ]]; then
            # Aviso
            message=$(echo "$clean_line" | sed 's/\[AVISO\]\[.*\] //')
            echo "- ⚠️ **Aviso:** $message" >> "$md_file"
        elif [[ "$clean_line" =~ ^\[INFO\]\[.*\] ]]; then
            # Info
            message=$(echo "$clean_line" | sed 's/\[INFO\]\[.*\] //')
            echo "- ℹ️ **Info:** $message" >> "$md_file"
        elif [[ "$clean_line" =~ ^   ]]; then
            # Mensagem indentada
            message=$(echo "$clean_line" | sed 's/^   //')
            echo "  - $message" >> "$md_file"
        else
            # Outras mensagens
            if [ -n "$clean_line" ]; then
                echo "- $clean_line" >> "$md_file"
            fi
        fi
    done < "$log_file"

    echo "" >> "$md_file"
    echo "---" >> "$md_file"
    echo "*Gerado automaticamente por converter_log_md.sh*" >> "$md_file"

    echo "Conversão concluída: $md_file"
}

# Função principal
main() {
    local log_file=""

    # Verificar argumentos
    if [ $# -eq 0 ]; then
        # Usar o último log
        log_file=$(get_latest_log)
        if [ -z "$log_file" ]; then
            echo "ERRO: Nenhum arquivo de log encontrado em $LOGS_DIR"
            exit 1
        fi
        echo "Usando o último log: $log_file"
    elif [ $# -eq 1 ]; then
        log_file="$1"
        if [[ "$log_file" != /* ]]; then
            log_file="$LOGS_DIR/$log_file"
        fi
    else
        echo "Uso: $0 [arquivo_log]"
        echo "Se nenhum arquivo for especificado, usa o último log disponível."
        exit 1
    fi

    # Nome do arquivo MD
    local log_basename=$(basename "$log_file" .log)
    local md_file="$LOGS_MD_DIR/${log_basename}.md"

    # Converter
    convert_log_to_md "$log_file" "$md_file"
}

# Executar função principal
main "$@"