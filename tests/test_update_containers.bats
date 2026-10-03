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

@test "atualizar_container.sh registra o status dos containers uma única vez" {
    [ "$(grep -c 'docker compose ps' "$SCRIPT_DIR/lib/atualizar_container.sh")" -eq 1 ]
}

@test "limpar_imagens_antigas remove imagens e build cache não utilizados (-a)" {
    grep -q "docker image prune -a -f" "$SCRIPT_DIR/lib/atualizar_container.sh"
    grep -q "docker builder prune -a -f" "$SCRIPT_DIR/lib/atualizar_container.sh"
}

@test "limpar_imagens_antigas não remove volumes nomeados" {
    grep -q "docker volume prune -f" "$SCRIPT_DIR/lib/atualizar_container.sh"
    ! grep -q "docker volume prune -a" "$SCRIPT_DIR/lib/atualizar_container.sh"
}
