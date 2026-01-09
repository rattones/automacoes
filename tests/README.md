# Testes Unitários

Sistema de testes automatizados para o projeto de automação de servidor.

## 📋 Sobre

Os testes utilizam **BATS** (Bash Automated Testing System), um framework de testes para scripts Bash que fornece uma sintaxe simples e familiar para escrever testes unitários.

## 🚀 Executando os Testes

### Executar todos os testes

```bash
cd tests
./run_tests.sh
```

O script `run_tests.sh` irá:
1. Verificar se BATS está instalado
2. Instalar BATS automaticamente se necessário
3. Executar todos os arquivos `.bats` no diretório
4. Exibir resumo dos resultados

### Executar teste específico

```bash
# Executar apenas testes de estrutura
bats test_structure.bats

# Executar apenas testes de logging
bats test_logging.bats

# Executar apenas testes dos módulos de post-install
bats test_post_install_modules.bats
```

### Executar teste com output verbose

```bash
bats --tap test_structure.bats
```

## 📁 Estrutura de Testes

```
tests/
├── run_tests.sh                    # Script para executar todos os testes
├── test_structure.bats             # Testes de estrutura do projeto
├── test_logging.bats               # Testes da biblioteca de logging
├── test_post_install_bootstrap.bats # Testes do script bootstrap
├── test_post_install_modules.bats  # Testes dos módulos de instalação
├── test_update_system.bats         # Testes de atualização do sistema
├── test_update_containers.bats     # Testes de atualização de containers
└── README.md                       # Esta documentação
```

## 🧪 Tipos de Testes

### 1. Testes de Estrutura (`test_structure.bats`)
- Verifica existência de diretórios e arquivos
- Verifica permissões de execução
- Valida estrutura do projeto

### 2. Testes de Logging (`test_logging.bats`)
- Testa funções de logging
- Verifica criação de arquivos de log
- Valida formatação de mensagens

### 3. Testes de Bootstrap (`test_post_install_bootstrap.bats`)
- Valida script de bootstrap
- Verifica verificação de permissões
- Testa definição de variáveis

### 4. Testes de Módulos (`test_post_install_modules.bats`)
- Verifica existência de todos os módulos
- Valida permissões de execução
- Testa carregamento de dependências
- Verifica funcionalidades específicas de cada módulo

### 5. Testes de Atualização (`test_update_*.bats`)
- Valida scripts de atualização
- Verifica definição de funções
- Testa comandos principais

## 📝 Escrevendo Novos Testes

### Estrutura Básica

```bash
#!/usr/bin/env bats

# Descrição do arquivo de teste

setup() {
    # Configuração executada antes de cada teste
    export TEST_VAR="valor"
}

teardown() {
    # Limpeza executada após cada teste
    rm -rf "$TEST_DIR"
}

@test "descrição do teste" {
    # Comando a ser testado
    run comando_a_testar
    
    # Asserções
    [ "$status" -eq 0 ]
    [[ "$output" == *"esperado"* ]]
}
```

### Comandos Úteis

```bash
# Verificar status de saída
[ "$status" -eq 0 ]          # Sucesso
[ "$status" -ne 0 ]          # Falha

# Verificar output
[[ "$output" == "texto" ]]   # Output exato
[[ "$output" == *"parte"* ]] # Output contém texto

# Verificar arquivos
[ -f "arquivo" ]             # Arquivo existe
[ -d "diretorio" ]           # Diretório existe
[ -x "script" ]              # Arquivo executável

# Verificar strings com grep
grep -q "texto" arquivo      # Arquivo contém texto
```

## 🔍 Exemplos de Testes

### Teste de Função

```bash
@test "função retorna valor esperado" {
    source ../lib/logging.sh
    
    run log "mensagem"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"mensagem"* ]]
}
```

### Teste de Arquivo

```bash
@test "script existe e é executável" {
    [ -f "../post-install.sh" ]
    [ -x "../post-install.sh" ]
}
```

### Teste de Conteúdo

```bash
@test "script contém função necessária" {
    grep -q "funcao_importante()" "../script.sh"
}
```

## 📊 Interpretando Resultados

### Saída de Sucesso
```
✓ descrição do teste 1
✓ descrição do teste 2
✓ descrição do teste 3

3 tests, 0 failures
```

### Saída de Falha
```
✓ descrição do teste 1
✗ descrição do teste 2
  (in test file test.bats, line 10)
  `[ "$status" -eq 0 ]' failed
✓ descrição do teste 3

3 tests, 1 failure
```

## 🛠️ Instalação Manual do BATS

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install bats
```

### macOS (Homebrew)
```bash
brew install bats-core
```

### Manual (qualquer sistema)
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## 📚 Recursos

- [BATS GitHub](https://github.com/bats-core/bats-core)
- [BATS Wiki](https://github.com/bats-core/bats-core/wiki)
- [Tutorial BATS](https://opensource.com/article/19/2/testing-bash-bats)

## ✅ Boas Práticas

1. **Teste uma coisa por vez**: Cada `@test` deve verificar um comportamento específico
2. **Nomes descritivos**: Use nomes claros que descrevam o que está sendo testado
3. **Setup/Teardown**: Use para preparar ambiente e limpar após testes
4. **Independência**: Testes não devem depender da ordem de execução
5. **Cobertura**: Teste casos normais, edge cases e cenários de erro
6. **Manutenção**: Atualize testes quando alterar funcionalidades

## 🎯 Objetivo dos Testes

- ✅ Garantir que a estrutura do projeto está correta
- ✅ Validar que scripts têm permissões adequadas
- ✅ Verificar existência de funções críticas
- ✅ Detectar regressões durante desenvolvimento
- ✅ Documentar comportamento esperado
- ✅ Facilitar refatoração segura
