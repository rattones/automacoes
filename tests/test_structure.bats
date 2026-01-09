#!/usr/bin/env bats

# Testes de estrutura do projeto

setup() {
    export PROJECT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
}

@test "diretório lib/ existe" {
    [ -d "$PROJECT_DIR/lib" ]
}

@test "diretório lib/post-install/ existe" {
    [ -d "$PROJECT_DIR/lib/post-install" ]
}

@test "diretório backups/ existe" {
    [ -d "$PROJECT_DIR/backups" ]
}

@test "diretório backups/crafty/ existe" {
    [ -d "$PROJECT_DIR/backups/crafty" ]
}

@test "diretório backups/haos/ existe" {
    [ -d "$PROJECT_DIR/backups/haos" ]
}

@test "diretório backups/zsh/ existe" {
    [ -d "$PROJECT_DIR/backups/zsh" ]
}

@test "arquivo README.md existe" {
    [ -f "$PROJECT_DIR/README.md" ]
}

@test "arquivo atualizar_servidor.sh existe" {
    [ -f "$PROJECT_DIR/atualizar_servidor.sh" ]
    [ -x "$PROJECT_DIR/atualizar_servidor.sh" ]
}

@test "arquivo post-install.sh existe" {
    [ -f "$PROJECT_DIR/post-install.sh" ]
    [ -x "$PROJECT_DIR/post-install.sh" ]
}

@test "biblioteca logging.sh existe" {
    [ -f "$PROJECT_DIR/lib/logging.sh" ]
}

@test "biblioteca atualizar_sistema.sh existe" {
    [ -f "$PROJECT_DIR/lib/atualizar_sistema.sh" ]
}

@test "biblioteca atualizar_container.sh existe" {
    [ -f "$PROJECT_DIR/lib/atualizar_container.sh" ]
}

@test "biblioteca atualizar_nodejs.sh existe" {
    [ -f "$PROJECT_DIR/lib/atualizar_nodejs.sh" ]
}

@test "biblioteca verificar_sistema.sh existe" {
    [ -f "$PROJECT_DIR/lib/verificar_sistema.sh" ]
}

@test "backups/crafty/compose.yml existe" {
    [ -f "$PROJECT_DIR/backups/crafty/compose.yml" ]
}

@test "backups/haos/compose.yml existe" {
    [ -f "$PROJECT_DIR/backups/haos/compose.yml" ]
}

@test "backups/zsh/.zshrc existe" {
    [ -f "$PROJECT_DIR/backups/zsh/.zshrc" ]
}

@test "backups/zsh/.p10k.zsh existe" {
    [ -f "$PROJECT_DIR/backups/zsh/.p10k.zsh" ]
}
