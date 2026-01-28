#!/usr/bin/env bats

# Testes para lib/atualizar_sistema.sh

setup() {
    export SCRIPT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
}

teardown() {
    # Nada a limpar
    :
}

@test "atualizar_sistema.sh existe" {
    [ -f "$SCRIPT_DIR/lib/atualizar_sistema.sh" ]
}

@test "atualizar_sistema.sh tem permissão de execução" {
    [ -x "$SCRIPT_DIR/lib/atualizar_sistema.sh" ]
}

@test "atualizar_sistema.sh define função atualizar_lista_pacotes" {
    grep -q "atualizar_lista_pacotes()" "$SCRIPT_DIR/lib/atualizar_sistema.sh"
}

@test "atualizar_sistema.sh define função upgrade_pacotes" {
    grep -q "upgrade_pacotes()" "$SCRIPT_DIR/lib/atualizar_sistema.sh"
}

@test "atualizar_sistema.sh define função atualizar_sistema_completo" {
    grep -q "atualizar_sistema_completo()" "$SCRIPT_DIR/lib/atualizar_sistema.sh"
}

@test "atualizar_sistema.sh tem tratamento de erros apt" {
    grep -q "apt.*-qq" "$SCRIPT_DIR/lib/atualizar_sistema.sh"
}

@test "atualizar_sistema.sh verifica pacotes disponíveis" {
    grep -q "verificar_pacotes_disponiveis" "$SCRIPT_DIR/lib/atualizar_sistema.sh"
}
