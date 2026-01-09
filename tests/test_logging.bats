#!/usr/bin/env bats

# Testes para lib/logging.sh

setup() {
    export SCRIPT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
}

@test "logging.sh existe" {
    [ -f "$SCRIPT_DIR/lib/logging.sh" ]
}

@test "logging.sh define função log" {
    grep -q "^log()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define função log_erro" {
    grep -q "^log_erro()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define função log_sucesso" {
    grep -q "^log_sucesso()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define função log_aviso" {
    grep -q "^log_aviso()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define função log_info" {
    grep -q "^log_info()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define função log_separador" {
    grep -q "^log_separador()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define função inicializar_log" {
    grep -q "^inicializar_log()" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh define cores para output" {
    grep -q "VERDE=" "$SCRIPT_DIR/lib/logging.sh"
    grep -q "VERMELHO=" "$SCRIPT_DIR/lib/logging.sh"
    grep -q "AMARELO=" "$SCRIPT_DIR/lib/logging.sh"
    grep -q "AZUL=" "$SCRIPT_DIR/lib/logging.sh"
}

@test "logging.sh usa timestamps em logs" {
    grep -q "date.*%Y-%m-%d" "$SCRIPT_DIR/lib/logging.sh"
}
