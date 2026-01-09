#!/usr/bin/env bats

# Testes para post-install.sh (bootstrap)

setup() {
    # Carregar funções do script
    export SCRIPT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
}

@test "post-install.sh existe e tem permissão de execução" {
    [ -f "$SCRIPT_DIR/post-install.sh" ]
    [ -x "$SCRIPT_DIR/post-install.sh" ]
}

@test "post-install.sh contém shebang correto" {
    run head -n 1 "$SCRIPT_DIR/post-install.sh"
    
    [[ "$output" == "#!/bin/bash" ]]
}

@test "post-install.sh verifica se está rodando como root" {
    grep -q "EUID" "$SCRIPT_DIR/post-install.sh"
}

@test "post-install.sh define variável REPO_DIR" {
    grep -q 'REPO_DIR=' "$SCRIPT_DIR/post-install.sh"
}

@test "post-install.sh referencia main-install.sh" {
    grep -q "main-install.sh" "$SCRIPT_DIR/post-install.sh"
}

@test "post-install.sh tem todas as funções de logging" {
    local script="$SCRIPT_DIR/post-install.sh"
    
    grep -q "log()" "$script"
    grep -q "log_erro()" "$script"
    grep -q "log_sucesso()" "$script"
    grep -q "log_aviso()" "$script"
}
