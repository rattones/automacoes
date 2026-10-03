#!/usr/bin/env bats

# Testes para lib/atualizar_nodejs.sh

setup() {
    export SCRIPT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
    export HOME="$BATS_TEST_TMPDIR"
    export LOG_FILE="$BATS_TEST_TMPDIR/test.log"
    source "$SCRIPT_DIR/lib/atualizar_nodejs.sh"
    log() { echo "LOG: $1"; }
    log_sucesso() { echo "SUCESSO: $1"; }
    log_aviso() { echo "AVISO: $1"; }
    log_erro() { echo "ERRO: $1"; }
}

# Saída real do `nvm ls` inclui aliases; com --no-alias sobram só as versões
nvm_ls_mock() {
    if [[ "$*" == *"--no-alias"* ]]; then
        printf '       v24.2.0\n->     v24.21.0\n         system\n'
    else
        printf '       v24.2.0\n->     v24.21.0\ndefault -> lts/* (-> v24.21.0)\nlts/argon -> v4.9.1 (-> N/A)\nlts/jod -> v22.20.0 (-> N/A)\n'
    fi
}

@test "atualizar_nodejs.sh existe e é executável" {
    [ -x "$SCRIPT_DIR/lib/atualizar_nodejs.sh" ]
}

@test "limpar_versoes_antigas_nodejs remove só versões instaladas diferentes da atual" {
    nvm() {
        case "$1" in
            current) echo "v24.21.0" ;;
            ls) shift; nvm_ls_mock "$@" ;;
            uninstall) echo "$2" >> "$BATS_TEST_TMPDIR/uninstalled" ;;
        esac
    }
    run limpar_versoes_antigas_nodejs
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/uninstalled")" = "v24.2.0" ]
    [[ "$output" == *"1 versão(ões) antiga(s) removida(s)"* ]]
    [[ "$output" != *"lts/"* ]]
    [[ "$output" != *"system"* ]]
}

@test "limpar_versoes_antigas_nodejs não remove nada quando só há a versão atual" {
    nvm() {
        case "$1" in
            current) echo "v24.21.0" ;;
            ls) printf -- '->     v24.21.0\n' ;;
            uninstall) echo "$2" >> "$BATS_TEST_TMPDIR/uninstalled" ;;
        esac
    }
    run limpar_versoes_antigas_nodejs
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nenhuma versão antiga encontrada"* ]]
    [ ! -f "$BATS_TEST_TMPDIR/uninstalled" ]
}

@test "atualizar_npm não reinstala quando já está na versão mais recente" {
    npm() {
        case "$1" in
            --version) echo "12.1.0" ;;
            view) echo "12.1.0" ;;
            install) echo "install" >> "$BATS_TEST_TMPDIR/npm_calls" ;;
        esac
    }
    run atualizar_npm
    [ "$status" -eq 0 ]
    [[ "$output" == *"npm já está na versão mais recente: 12.1.0"* ]]
    [ ! -f "$BATS_TEST_TMPDIR/npm_calls" ]
}

@test "atualizar_npm reinstala quando a consulta de versão falha" {
    npm() {
        case "$1" in
            --version) echo "12.1.0" ;;
            view) return 1 ;;
            install) echo "install" >> "$BATS_TEST_TMPDIR/npm_calls" ;;
        esac
    }
    run atualizar_npm
    [ "$status" -eq 0 ]
    [ -f "$BATS_TEST_TMPDIR/npm_calls" ]
}
