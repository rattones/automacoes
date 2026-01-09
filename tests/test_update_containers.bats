#!/usr/bin/env bats

# Testes para lib/atualizar_container.sh

setup() {
    export SCRIPT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
}

@test "atualizar_container.sh existe" {
    [ -f "$SCRIPT_DIR/lib/atualizar_container.sh" ]
}

@test "atualizar_container.sh tem permissão de execução" {
    [ -x "$SCRIPT_DIR/lib/atualizar_container.sh" ]
}

@test "atualizar_container.sh define função atualizar_container" {
    grep -q "atualizar_container()" "$SCRIPT_DIR/lib/atualizar_container.sh"
}

@test "atualizar_container.sh define função limpar_imagens_antigas" {
    grep -q "limpar_imagens_antigas()" "$SCRIPT_DIR/lib/atualizar_container.sh"
}

@test "atualizar_container.sh usa docker compose" {
    grep -q "docker compose" "$SCRIPT_DIR/lib/atualizar_container.sh"
}

@test "atualizar_container.sh faz pull de imagens" {
    grep -q "docker compose pull" "$SCRIPT_DIR/lib/atualizar_container.sh"
}

@test "atualizar_container.sh reinicia containers" {
    grep -q "docker compose up -d" "$SCRIPT_DIR/lib/atualizar_container.sh"
}
