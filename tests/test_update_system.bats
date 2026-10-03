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

# Comportamento de remover_pacotes_desnecessarios com apt simulado
carregar_sistema_mockado() {
    source "$SCRIPT_DIR/lib/atualizar_sistema.sh"
    log() { echo "LOG: $1"; }
    log_sucesso() { echo "SUCESSO: $1"; }
    log_aviso() { echo "AVISO: $1"; }
    apt() { echo "apt $*" >> "$BATS_TEST_TMPDIR/apt_calls"; }
}

@test "remover_pacotes_desnecessarios não roda autoremove quando não há nada a remover" {
    carregar_sistema_mockado
    apt-get() { echo "Reading package lists..."; echo "0 upgraded, 0 newly installed, 0 to remove"; }
    run remover_pacotes_desnecessarios
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nenhum pacote desnecessário encontrado"* ]]
    [ ! -f "$BATS_TEST_TMPDIR/apt_calls" ]
}

@test "remover_pacotes_desnecessarios informa quantos pacotes removeu" {
    carregar_sistema_mockado
    apt-get() { echo "Remv linux-tools-6.8.0-137 [6.8.0-137.137]"; echo "Remv linux-headers-6.8.0-137 [6.8.0-137.137]"; }
    run remover_pacotes_desnecessarios
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 pacote(s) desnecessário(s) removido(s)"* ]]
    [[ "$output" != *"Nenhum pacote"* ]]
    grep -q "autoremove" "$BATS_TEST_TMPDIR/apt_calls"
}
