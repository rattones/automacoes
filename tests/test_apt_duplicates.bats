#!/usr/bin/env bats

# Testes para detectar configurações duplicadas do APT

setup() {
    # Diretório temporário para testes
    export TEST_DIR="$(mktemp -d)"
    export MOCK_APT_DIR="${TEST_DIR}/etc/apt"
    export MOCK_SOURCES_DIR="${MOCK_APT_DIR}/sources.list.d"
    export MOCK_KEYRINGS_DIR="${TEST_DIR}/etc/apt/keyrings"
    
    mkdir -p "${MOCK_SOURCES_DIR}"
    mkdir -p "${MOCK_KEYRINGS_DIR}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# Função auxiliar para detectar duplicatas Docker
detect_docker_duplicates() {
    local sources_dir="${1:-/etc/apt/sources.list.d}"
    local duplicates=0
    
    # Verifica se ambos os arquivos existem
    if [[ -f "${sources_dir}/docker.list" ]] && [[ -f "${sources_dir}/docker.sources" ]]; then
        duplicates=$((duplicates + 1))
    fi
    
    return $duplicates
}

@test "detecta docker.list e docker.sources duplicados" {
    # Criar arquivos duplicados
    touch "${MOCK_SOURCES_DIR}/docker.list"
    touch "${MOCK_SOURCES_DIR}/docker.sources"
    
    run detect_docker_duplicates "${MOCK_SOURCES_DIR}"
    [ "$status" -eq 1 ]
}

@test "não detecta duplicata quando só docker.list existe" {
    touch "${MOCK_SOURCES_DIR}/docker.list"
    
    run detect_docker_duplicates "${MOCK_SOURCES_DIR}"
    [ "$status" -eq 0 ]
}

@test "não detecta duplicata quando só docker.sources existe" {
    touch "${MOCK_SOURCES_DIR}/docker.sources"
    
    run detect_docker_duplicates "${MOCK_SOURCES_DIR}"
    [ "$status" -eq 0 ]
}

@test "não detecta duplicata quando nenhum arquivo existe" {
    run detect_docker_duplicates "${MOCK_SOURCES_DIR}"
    [ "$status" -eq 0 ]
}

# Função para detectar conflitos de GPG
detect_gpg_conflicts() {
    local keyrings_dir="${1:-/etc/apt/keyrings}"
    local conflicts=0
    
    # Verifica se ambos os arquivos de GPG existem
    if [[ -f "${keyrings_dir}/docker.gpg" ]] && [[ -f "${keyrings_dir}/docker.asc" ]]; then
        conflicts=$((conflicts + 1))
    fi
    
    return $conflicts
}

@test "detecta docker.gpg e docker.asc duplicados" {
    touch "${MOCK_KEYRINGS_DIR}/docker.gpg"
    touch "${MOCK_KEYRINGS_DIR}/docker.asc"
    
    run detect_gpg_conflicts "${MOCK_KEYRINGS_DIR}"
    [ "$status" -eq 1 ]
}

@test "não detecta conflito quando só docker.gpg existe" {
    touch "${MOCK_KEYRINGS_DIR}/docker.gpg"
    
    run detect_gpg_conflicts "${MOCK_KEYRINGS_DIR}"
    [ "$status" -eq 0 ]
}

@test "não detecta conflito quando só docker.asc existe" {
    touch "${MOCK_KEYRINGS_DIR}/docker.asc"
    
    run detect_gpg_conflicts "${MOCK_KEYRINGS_DIR}"
    [ "$status" -eq 0 ]
}

# Função completa de verificação (simula a do setup-docker.sh)
check_docker_repo_duplicates() {
    local sources_dir="${1:-/etc/apt/sources.list.d}"
    local keyrings_dir="${2:-/etc/apt/keyrings}"
    local has_duplicates=false
    
    # Verifica arquivos de repositório
    if [[ -f "${sources_dir}/docker.list" ]] && [[ -f "${sources_dir}/docker.sources" ]]; then
        has_duplicates=true
    fi
    
    # Verifica arquivos de chave GPG
    if [[ -f "${keyrings_dir}/docker.gpg" ]] && [[ -f "${keyrings_dir}/docker.asc" ]]; then
        has_duplicates=true
    fi
    
    if [ "$has_duplicates" = true ]; then
        return 1
    else
        return 0
    fi
}

@test "verificação completa detecta múltiplas duplicatas" {
    # Criar todos os arquivos duplicados
    touch "${MOCK_SOURCES_DIR}/docker.list"
    touch "${MOCK_SOURCES_DIR}/docker.sources"
    touch "${MOCK_KEYRINGS_DIR}/docker.gpg"
    touch "${MOCK_KEYRINGS_DIR}/docker.asc"
    
    run check_docker_repo_duplicates "${MOCK_SOURCES_DIR}" "${MOCK_KEYRINGS_DIR}"
    [ "$status" -eq 1 ]
}

@test "verificação completa passa com configuração limpa" {
    # Apenas arquivos corretos
    touch "${MOCK_SOURCES_DIR}/docker.list"
    touch "${MOCK_KEYRINGS_DIR}/docker.gpg"
    
    run check_docker_repo_duplicates "${MOCK_SOURCES_DIR}" "${MOCK_KEYRINGS_DIR}"
    [ "$status" -eq 0 ]
}

@test "verifica se setup-docker.sh contém função de detecção" {
    if [[ -f "lib/post-install/setup-docker.sh" ]]; then
        run grep -q "configuração duplicada" lib/post-install/setup-docker.sh
        [ "$status" -eq 0 ]
    else
        skip "setup-docker.sh não encontrado"
    fi
}

@test "verifica se setup-docker.sh remove docker.sources" {
    if [[ -f "lib/post-install/setup-docker.sh" ]]; then
        run grep -q "rm.*docker.sources" lib/post-install/setup-docker.sh
        [ "$status" -eq 0 ]
    else
        skip "setup-docker.sh não encontrado"
    fi
}

@test "verifica se setup-docker.sh remove docker.asc" {
    if [[ -f "lib/post-install/setup-docker.sh" ]]; then
        run grep -q "rm.*docker.asc" lib/post-install/setup-docker.sh
        [ "$status" -eq 0 ]
    else
        skip "setup-docker.sh não encontrado"
    fi
}

@test "verifica se diagnostico_apt.sh existe" {
    [ -f "diagnostico_apt.sh" ]
}

@test "verifica se diagnostico_apt.sh é executável" {
    if [[ -f "diagnostico_apt.sh" ]]; then
        [ -x "diagnostico_apt.sh" ]
    else
        skip "diagnostico_apt.sh não encontrado"
    fi
}

@test "verifica se atualizar_servidor.sh contém validação APT" {
    if [[ -f "atualizar_servidor.sh" ]]; then
        run grep -q "Validando configuração do sistema APT" atualizar_servidor.sh
        [ "$status" -eq 0 ]
    else
        skip "atualizar_servidor.sh não encontrado"
    fi
}

@test "verifica se atualizar_servidor.sh executa apt-get check" {
    if [[ -f "atualizar_servidor.sh" ]]; then
        run grep -q "apt-get check" atualizar_servidor.sh
        [ "$status" -eq 0 ]
    else
        skip "atualizar_servidor.sh não encontrado"
    fi
}
