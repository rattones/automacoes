#!/usr/bin/env bats

# Testes para módulos de post-install

setup() {
    export MODULES_DIR="$(dirname "$BATS_TEST_DIRNAME")/lib/post-install"
}

@test "main-install.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/main-install.sh" ]
    [ -x "$MODULES_DIR/main-install.sh" ]
}

@test "setup-ssh.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-ssh.sh" ]
    [ -x "$MODULES_DIR/setup-ssh.sh" ]
}

@test "setup-zsh.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-zsh.sh" ]
    [ -x "$MODULES_DIR/setup-zsh.sh" ]
}

@test "setup-github-tools.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-github-tools.sh" ]
    [ -x "$MODULES_DIR/setup-github-tools.sh" ]
}

@test "setup-cockpit.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-cockpit.sh" ]
    [ -x "$MODULES_DIR/setup-cockpit.sh" ]
}

@test "setup-docker.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-docker.sh" ]
    [ -x "$MODULES_DIR/setup-docker.sh" ]
}

@test "setup-nodejs.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-nodejs.sh" ]
    [ -x "$MODULES_DIR/setup-nodejs.sh" ]
}

@test "setup-containers.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-containers.sh" ]
    [ -x "$MODULES_DIR/setup-containers.sh" ]
}

@test "setup-projects.sh existe e tem permissão de execução" {
    [ -f "$MODULES_DIR/setup-projects.sh" ]
    [ -x "$MODULES_DIR/setup-projects.sh" ]
}

@test "todos os módulos têm shebang correto" {
    for module in "$MODULES_DIR"/*.sh; do
        run head -n 1 "$module"
        [[ "$output" == "#!/bin/bash" ]]
    done
}

@test "todos os módulos carregam biblioteca de logging" {
    for module in "$MODULES_DIR"/*.sh; do
        # main-install.sh carrega logging
        if [[ "$(basename "$module")" == "main-install.sh" ]]; then
            grep -q "logging.sh" "$module"
        else
            # outros módulos também devem carregar
            grep -q "logging.sh" "$module"
        fi
    done
}

@test "main-install.sh define array de módulos" {
    grep -q "MODULOS=" "$MODULES_DIR/main-install.sh"
}

@test "setup-ssh.sh instala openssh-server" {
    grep -q "openssh-server" "$MODULES_DIR/setup-ssh.sh"
}

@test "setup-zsh.sh instala Oh My Zsh" {
    grep -q "oh-my-zsh" "$MODULES_DIR/setup-zsh.sh"
}

@test "setup-docker.sh adiciona usuário ao grupo docker" {
    grep -q "usermod.*docker" "$MODULES_DIR/setup-docker.sh"
}

@test "setup-nodejs.sh instala NVM" {
    grep -q "nvm" "$MODULES_DIR/setup-nodejs.sh"
}
