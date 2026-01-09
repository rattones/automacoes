#!/bin/bash

#########################################
# Script para Executar Testes Unitários
# Executa todos os testes usando BATS
#########################################

# Cores para output
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

echo -e "${AZUL}========================================${NC}"
echo -e "${AZUL}Sistema de Testes Unitários${NC}"
echo -e "${AZUL}========================================${NC}"
echo ""

# Verificar se BATS está instalado
if ! command -v bats &> /dev/null; then
    echo -e "${AMARELO}BATS (Bash Automated Testing System) não está instalado${NC}"
    echo ""
    echo "Instalando BATS..."
    echo ""
    
    # Tentar instalar via apt (Ubuntu/Debian)
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y bats
    # Tentar instalar via brew (macOS)
    elif command -v brew &> /dev/null; then
        brew install bats-core
    # Instalação manual via git
    else
        echo -e "${AMARELO}Instalando BATS manualmente...${NC}"
        git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
        cd /tmp/bats-core
        sudo ./install.sh /usr/local
        cd -
        rm -rf /tmp/bats-core
    fi
    
    # Verificar se a instalação funcionou
    if ! command -v bats &> /dev/null; then
        echo -e "${VERMELHO}Falha ao instalar BATS${NC}"
        echo "Instale manualmente: https://github.com/bats-core/bats-core"
        exit 1
    fi
    
    echo -e "${VERDE}BATS instalado com sucesso!${NC}"
    echo ""
fi

# Diretório de testes
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Executar todos os testes
echo -e "${AZUL}Executando testes...${NC}"
echo ""

# Contador de resultados
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Executar cada arquivo de teste
for test_file in "$TEST_DIR"/*.bats; do
    if [ -f "$test_file" ]; then
        echo -e "${AZUL}Executando: $(basename "$test_file")${NC}"
        
        if bats "$test_file"; then
            ((PASSED_TESTS++))
        else
            ((FAILED_TESTS++))
        fi
        
        echo ""
    fi
done

# Resumo
echo -e "${AZUL}========================================${NC}"
echo -e "${AZUL}Resumo dos Testes${NC}"
echo -e "${AZUL}========================================${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${VERDE}✓ Todos os testes passaram!${NC}"
    exit 0
else
    echo -e "${VERMELHO}✗ Alguns testes falharam${NC}"
    echo -e "Arquivos com falhas: ${FAILED_TESTS}"
    exit 1
fi
