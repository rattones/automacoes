#!/usr/bin/env bats

setup() {
    # Criar diretório temporário para testes
    TEST_DIR="$(mktemp -d)"
    SCRIPT_DIR="$TEST_DIR/automacoes"
    mkdir -p "$SCRIPT_DIR/lib"
    mkdir -p "$SCRIPT_DIR/backups/crafty"
    mkdir -p "$SCRIPT_DIR/backups/haos"
    mkdir -p "$SCRIPT_DIR/logs"

    # Copiar scripts necessários para teste
    cp "$BATS_TEST_DIRNAME/../lib/backup_configs.sh" "$SCRIPT_DIR/lib/"
    cp "$BATS_TEST_DIRNAME/../lib/logging.sh" "$SCRIPT_DIR/lib/"

    # Criar mock dos containers
    mkdir -p "$TEST_DIR/crafty/docker/config"
    mkdir -p "$TEST_DIR/haos/config"
    echo "mock crafty config" > "$TEST_DIR/crafty/docker/config/test.cfg"
    echo "mock ha config" > "$TEST_DIR/haos/config/configuration.yaml"
    echo "mock compose" > "$TEST_DIR/crafty/compose.yml"
    echo "mock compose" > "$TEST_DIR/haos/compose.yml"

    # Configurar variáveis de ambiente
    export SCRIPT_DIR
    export LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_MD_DIR="$SCRIPT_DIR/logs-md"

    # Carregar bibliotecas necessárias
    source "$SCRIPT_DIR/lib/logging.sh"
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    # Definir containers para teste
    declare -a CONTAINERS=(
        "Crafty" "$TEST_DIR/crafty"
        "Home Assistant" "$TEST_DIR/haos"
    )
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "backup_configs.sh existe e é executável" {
    [ -f "$SCRIPT_DIR/lib/backup_configs.sh" ]
    [ -x "$SCRIPT_DIR/lib/backup_configs.sh" ]
}

@test "backup_configs.sh define função backup_crafty" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"
    type backup_crafty >/dev/null 2>&1
}

@test "backup_configs.sh define função backup_home_assistant" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"
    type backup_home_assistant >/dev/null 2>&1
}

@test "backup_configs.sh define função backup_container_config" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"
    type backup_container_config >/dev/null 2>&1
}

@test "backup_configs.sh define função backup_todas_configs" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"
    type backup_todas_configs >/dev/null 2>&1
}

@test "backup_crafty copia arquivos de configuração" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_crafty "$TEST_DIR/crafty"

    [ "$status" -eq 0 ]
    [ -f "$SCRIPT_DIR/backups/crafty/test.cfg" ]
    [[ "$output" == *"Configurações do Crafty backupadas"* ]]
}

@test "backup_crafty copia compose.yml" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_crafty "$TEST_DIR/crafty"

    [ "$status" -eq 0 ]
    [ -f "$SCRIPT_DIR/backups/crafty/compose.yml" ]
    [[ "$output" == *"Compose.yml do Crafty backupado"* ]]
}

@test "backup_home_assistant cria arquivo tar.gz" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_home_assistant "$TEST_DIR/haos"

    [ "$status" -eq 0 ]
    # Deve ter criado pelo menos um arquivo .tar.gz
    ls "$SCRIPT_DIR/backups/haos/"*.tar.gz >/dev/null 2>&1
    [[ "$output" == *"Configuração do Home Assistant backupada"* ]]
}

@test "backup_home_assistant copia compose.yml" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_home_assistant "$TEST_DIR/haos"

    [ "$status" -eq 0 ]
    [ -f "$SCRIPT_DIR/backups/haos/compose.yml" ]
    [[ "$output" == *"Compose.yml do Home Assistant backupado"* ]]
}

@test "backup_container_config chama função correta para Crafty" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_container_config "Crafty" "$TEST_DIR/crafty"

    [ "$status" -eq 0 ]
    [[ "$output" == *"backup das configurações do Crafty"* ]]
}

@test "backup_container_config chama função correta para Home Assistant" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_container_config "Home Assistant" "$TEST_DIR/haos"

    [ "$status" -eq 0 ]
    [[ "$output" == *"backup das configurações do Home Assistant"* ]]
}

@test "backup_container_config ignora container desconhecido" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_container_config "Unknown Container" "/tmp/test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"não possui backup de configuração definido"* ]]
}

@test "backup_crafty trata diretório inexistente" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_crafty "/diretorio/inexistente"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Diretório do Crafty não encontrado"* ]]
}

@test "backup_home_assistant trata diretório inexistente" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    run backup_home_assistant "/diretorio/inexistente"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Diretório do Home Assistant não encontrado"* ]]
}

@test "backup_todas_configs processa múltiplos containers" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    # Definir CONTAINERS no escopo da função
    declare -a CONTAINERS=(
        "Crafty" "$TEST_DIR/crafty"
        "Home Assistant" "$TEST_DIR/haos"
    )

    run backup_todas_configs

    [ "$status" -eq 0 ]
    [[ "$output" == *"2/2 containers processados com sucesso"* ]]
    [[ "$output" == *"BACKUP CONCLUÍDO"* ]]
}

@test "listar_backups mostra estrutura de backups" {
    source "$SCRIPT_DIR/lib/backup_configs.sh"

    # Criar alguns arquivos de backup mock
    echo "backup file" > "$SCRIPT_DIR/backups/crafty/old_backup.cfg"
    echo "backup file" > "$SCRIPT_DIR/backups/haos/old_backup.yaml"

    run listar_backups

    [ "$status" -eq 0 ]
    [[ "$output" == *"crafty:"* ]]
    [[ "$output" == *"haos:"* ]]
}