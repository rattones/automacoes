#!/usr/bin/env bats

# Testes para lib/converter_log_md.sh

setup() {
    export SCRIPT_DIR="$(dirname "$BATS_TEST_DIRNAME")"
    export TEST_LOGS_DIR="$BATS_TMPDIR/test_logs"
    export TEST_MD_DIR="$BATS_TMPDIR/test_md"
    mkdir -p "$TEST_LOGS_DIR" "$TEST_MD_DIR"

    # Mock das variáveis do script
    export LOGS_DIR="$TEST_LOGS_DIR"
    export LOGS_MD_DIR="$TEST_MD_DIR"
}

teardown() {
    rm -rf "$TEST_LOGS_DIR" "$TEST_MD_DIR"
}

@test "converter_log_md.sh existe e é executável" {
    [ -x "$SCRIPT_DIR/lib/converter_log_md.sh" ]
}

@test "converte log simples para Markdown" {
    # Criar log de teste
    cat > "$TEST_LOGS_DIR/test.log" << 'EOF'
[2026-01-28 10:00:00] INICIANDO PROCESSO
[2026-01-28 10:00:01] Mensagem normal
[SUCESSO][2026-01-28 10:00:02] Operação concluída
EOF

    # Executar conversão
    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/test.log"

    # Verificar saída
    [ -f "$TEST_MD_DIR/test.md" ]
    [ -s "$TEST_MD_DIR/test.md" ]  # Arquivo não vazio
    grep -F -q "INICIANDO PROCESSO" "$TEST_MD_DIR/test.md"
    grep -F -q "Mensagem normal" "$TEST_MD_DIR/test.md"
    grep -F -q "SUCESSO" "$TEST_MD_DIR/test.md"
}

@test "remove códigos ANSI" {
    # Criar log com ANSI
    cat > "$TEST_LOGS_DIR/ansi.log" << 'EOF'
[2026-01-28 10:00:00] Mensagem com [0;32mverde[0m
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/ansi.log"

    [ -f "$TEST_MD_DIR/ansi.md" ]
    ! grep -q "\[0;32m" "$TEST_MD_DIR/ansi.md"
    grep -q "Mensagem com verde" "$TEST_MD_DIR/ansi.md"
}

@test "converte tabela de containers" {
    # Criar log com tabela
    cat > "$TEST_LOGS_DIR/containers.log" << 'EOF'
[2026-01-28 10:00:00] Status dos containers de Teste:
NAME      IMAGE     COMMAND    SERVICE    CREATED    STATUS    PORTS
test_app  nginx     "nginx"    web        1 hour ago Up         80/tcp
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/containers.log"

    [ -f "$TEST_MD_DIR/containers.md" ]
    grep -F -q "| NAME |" "$TEST_MD_DIR/containers.md"
    grep -F -q "| test_app |" "$TEST_MD_DIR/containers.md"
}

@test "usa último log quando nenhum argumento" {
    # Criar múltiplos logs
    touch "$TEST_LOGS_DIR/old.log"
    sleep 1
    touch "$TEST_LOGS_DIR/atualizacao_20260128_120000.log"

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh

    [ -f "$TEST_MD_DIR/atualizacao_20260128_120000.md" ]
}

@test "cria diretório MD se não existir" {
    rm -rf "$TEST_MD_DIR"
    cat > "$TEST_LOGS_DIR/dir_test.log" << 'EOF'
[2026-01-28 10:00:00] Teste
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/dir_test.log"

    [ -d "$TEST_MD_DIR" ]
    [ -f "$TEST_MD_DIR/dir_test.md" ]
}

@test "formata mensagens de erro" {
    cat > "$TEST_LOGS_DIR/error.log" << 'EOF'
[ERRO][2026-01-28 10:00:00] Falha crítica
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/error.log"

    [ -f "$TEST_MD_DIR/error.md" ]
    grep -F -q "ERRO" "$TEST_MD_DIR/error.md"
}

@test "formata mensagens de aviso" {
    cat > "$TEST_LOGS_DIR/warning.log" << 'EOF'
[AVISO][2026-01-28 10:00:00] Atenção necessária
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/warning.log"

    [ -f "$TEST_MD_DIR/warning.md" ]
    grep -F -q "AVISO" "$TEST_MD_DIR/warning.md"
}

@test "formata mensagens de info" {
    cat > "$TEST_LOGS_DIR/info.log" << 'EOF'
[INFO][2026-01-28 10:00:00] Informação útil
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/info.log"

    [ -f "$TEST_MD_DIR/info.md" ]
    grep -F -q "INFO" "$TEST_MD_DIR/info.md"
}

@test "trata linhas vazias e separadores" {
    cat > "$TEST_LOGS_DIR/separators.log" << 'EOF'
[2026-01-28 10:00:00] ==========================================
[2026-01-28 10:00:01] Seção 1
[2026-01-28 10:00:02] ------------------------------------------  
[2026-01-28 10:00:03] Subseção
EOF

    cd "$SCRIPT_DIR" && bash lib/converter_log_md.sh "$TEST_LOGS_DIR/separators.log"

    [ -f "$TEST_MD_DIR/separators.md" ]
    grep -F -q "Seção 1" "$TEST_MD_DIR/separators.md"
    grep -F -q "Subseção" "$TEST_MD_DIR/separators.md"
}

@test "falha graciosamente com log inexistente" {
    run bash "$SCRIPT_DIR/lib/converter_log_md.sh" "$TEST_LOGS_DIR/inexistente.log"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Arquivo de log não encontrado" ]]
}