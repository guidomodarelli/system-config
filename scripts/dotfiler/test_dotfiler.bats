#!/usr/bin/env bats

load "test/test_helper.bash"

setup() {
  setup_test_environment
}

teardown() {
  teardown_test_environment
}

simulate_wsl_environment() {
  cat > "$FAKE_BIN_DIR/grep" <<'BASH'
#!/usr/bin/env bash
if [ "$#" -ge 3 ] && [ "$1" = "-qi" ] && { [ "$2" = "microsoft" ] || [ "$2" = "wsl" ]; } && [ "$3" = "/proc/version" ]; then
  exit 0
fi
exec /bin/grep "$@"
BASH
  chmod +x "$FAKE_BIN_DIR/grep"
}

@test "DEBUG=true still executes the symlink flow" {
  install_fixture "debug_flow"

  run_dotfiler "true"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/debug-source" \
    "$REPO_DIR/configs/debug-source"
}

@test "darwin excludes entries even when excludeFor has multiple items" {
  install_fixture "darwin_exclude"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_path_missing "$HOME_DIR/linked-files/excluded-file"
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/included-file" \
    "$REPO_DIR/configs/included-file"
}

@test "output does not print literal backslash-n sequences" {
  install_fixture "debug_flow"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  [[ "$output" != *"\\n"* ]]
}

@test "--dry-run does not create symlinks and reports dry-run summary" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--dry-run"

  [ "$status" -eq 0 ]
  assert_path_missing "$HOME_DIR/linked-files/debug-source"
  [[ "$output" == *"Modo simulación activo"* ]]
  [[ "$output" == *"Omitidos"* ]]
  [[ "$output" == *"║ 1"* ]]
}

@test "--quiet hides per-item logs but prints summary" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--quiet"

  [ "$status" -eq 0 ]
  [[ "$output" == *"RESUMEN"* ]]
  [[ "$output" != *"GRUPO"* ]]
  [[ "$output" != *"INFO"* ]]
}

@test "--help prints available options" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--help"

  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--plain"* ]]
  [[ "$output" == *"--quiet"* ]]
}

@test "--no-color disables ANSI escape codes" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" != *$'\e['* ]]
}

@test "group header and separator are printed for different target groups" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: first-file
    target: target-a
  - path: second-file
    target: target-b
YAML
  printf "first" > "$REPO_DIR/configs/first-file"
  printf "second" > "$REPO_DIR/configs/second-file"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  [[ "$output" == *"GRUPO"* ]]
  [[ "$output" == *"────────────────────────────────────────────────────────"* ]]
}

@test "display path is normalized to avoid double slash in output" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: debug-source
    target: .codex/
YAML
  printf "debug" > "$REPO_DIR/configs/debug-source"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  [[ "$output" != *".codex//debug-source"* ]]
  [[ "$output" == *".codex/debug-source"* ]]
}

@test "output does not print duplicated separators consecutively" {
  install_fixture "debug_flow"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_no_double_separator "$output"
}

@test "summary table snapshot remains stable in spanish without color" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--dry-run --quiet --no-color"

  [ "$status" -eq 0 ]
  assert_output_contains_line "$output" "RESUMEN"
  assert_output_contains_line "$output" "║ Métrica"
  assert_output_contains_line "$output" "║ Valor"
  assert_output_contains_line "$output" "Tiempo total (s)"
  assert_output_contains_line "$output" "Creados"
  assert_output_contains_line "$output" "Reemplazados"
  assert_output_contains_line "$output" "Respaldos"
  assert_output_contains_line "$output" "Omitidos"
  assert_output_contains_line "$output" "Ops. Windows en cola (PS)"
  assert_output_contains_line "$output" "Errores"
  assert_output_contains_line "$output" "Estado"
  assert_output_contains_line "$output" "[OK] Sin errores"
  assert_output_contains_line "$output" "Modo simulación activo, no se escribieron cambios en el sistema de archivos."
  assert_output_contains_line "$output" "Configuración de symlinks finalizada."
}

@test "runtime errors return exit code 1 and print diagnostics section" {
  install_fixture "debug_flow"
  cat > "$FAKE_BIN_DIR/ln" <<'BASH'
#!/usr/bin/env bash
exit 1
BASH
  chmod +x "$FAKE_BIN_DIR/ln"

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 1 ]
  assert_output_contains_line "$output" "DIAGNÓSTICO"
  assert_output_contains_line "$output" "Fallo al crear symlink"
}

@test "existing backup is preserved and next backup uses incremental suffix" {
  install_fixture "debug_flow"
  mkdir -p "$HOME_DIR/linked-files"
  printf "current-content" > "$HOME_DIR/linked-files/debug-source"
  printf "older-backup" > "$HOME_DIR/linked-files/debug-source.bak"

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 0 ]
  [ -f "$HOME_DIR/linked-files/debug-source.bak" ]
  [ -f "$HOME_DIR/linked-files/debug-source.bak.1" ]
  [ "$(cat "$HOME_DIR/linked-files/debug-source.bak")" = "older-backup" ]
  [ "$(cat "$HOME_DIR/linked-files/debug-source.bak.1")" = "current-content" ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/debug-source" \
    "$REPO_DIR/configs/debug-source"
}

@test "invalid config returns exit code 2" {
  printf "paths: [\n" > "$REPO_DIR/symlinks.yml"

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"Configuración inválida"* ]]
}

@test "fails with clear error when executed outside a git repository" {
  run_dotfiler_outside_repo "false" "--quiet --no-color"

  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"repositorio Git válido"* ]]
}

@test "expands home prefix for source and target paths" {
  printf "home-source" > "$HOME_DIR/home-source"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: '~/home-source'
    target: '~/linked-home'
YAML

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-home/home-source" \
    "$HOME_DIR/home-source"
}

@test "handles source names with spaces and quotes" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: 'file with "quotes" and spaces.txt'
    target: linked-files
YAML
  printf "debug" > "$REPO_DIR/configs/file with \"quotes\" and spaces.txt"

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/file with \"quotes\" and spaces.txt" \
    "$REPO_DIR/configs/file with \"quotes\" and spaces.txt"
}

@test "wildcard expansion is deterministic and sorted" {
  mkdir -p "$REPO_DIR/configs/wild"
  printf "b" > "$REPO_DIR/configs/wild/b-file"
  printf "a" > "$REPO_DIR/configs/wild/a-file"
  printf "c" > "$REPO_DIR/configs/wild/c-file"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: wild/*
    target: ordered
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  local line_a
  local line_b
  local line_c
  line_a=$(echo "$output" | grep -n "ordered/a-file" | head -n1 | cut -d: -f1)
  line_b=$(echo "$output" | grep -n "ordered/b-file" | head -n1 | cut -d: -f1)
  line_c=$(echo "$output" | grep -n "ordered/c-file" | head -n1 | cut -d: -f1)
  [ -n "$line_a" ]
  [ -n "$line_b" ]
  [ -n "$line_c" ]
  [ "$line_a" -lt "$line_b" ]
  [ "$line_b" -lt "$line_c" ]
}

@test "missing wildcard directory does not fail execution" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: missing/*
    target: linked-files
YAML

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 0 ]
  [[ "$output$stderr" == *"Directorio no encontrado"* ]]
}

@test "expands user variable only on valid path segments" {
  printf "debug" > "$REPO_DIR/configs/debug-source"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: debug-source
    target: '$HOME/targets/$USER/safe-$USER-suffix'
YAML

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/targets/test-user/safe-\$USER-suffix/debug-source" \
    "$REPO_DIR/configs/debug-source"
}

@test "wsl distro name fallback works when WSL_DISTRO_NAME is unset" {
  simulate_wsl_environment
  cat > "$FAKE_BIN_DIR/wslpath" <<'BASH'
#!/usr/bin/env bash
if [ "$1" = "-w" ] && [ "$2" = "/" ]; then
  printf '%s\n' '\\wsl.localhost\Ubuntu\'
  exit 0
fi
printf '%s\n' 'C:\tmp\fake'
BASH
  chmod +x "$FAKE_BIN_DIR/wslpath"
  cat > "$FAKE_BIN_DIR/powershell.exe" <<'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x "$FAKE_BIN_DIR/powershell.exe"

  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: debug-source
    target: WSL://Desktop
YAML

  run_dotfiler "false" "--dry-run --quiet --no-color"

  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"unbound variable"* ]]
}

@test "wsl without windows operations does not require powershell or wslpath" {
  install_fixture "debug_flow"
  simulate_wsl_environment
  cat > "$REPO_DIR/configs/zsh/.zsh/functions/check_command.zsh" <<'BASH'
check_command() {
  local cmd="$1"
  if [ "$cmd" = "wslpath" ] || [ "$cmd" = "powershell.exe" ]; then
    logError "Command '$cmd' not found"
    exit 1
  fi
  if ! command -v "$cmd" &>/dev/null; then
    logError "Command '$cmd' not found"
    exit 1
  fi
}

check_commands() {
  for cmd in "$@"; do
    check_command "$cmd"
  done
}
BASH

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"Command 'powershell.exe' not found"* ]]
  [[ "$output$stderr" != *"Command 'wslpath' not found"* ]]
}

@test "wsl target records diagnostic when wslpath conversion fails" {
  simulate_wsl_environment
  cat > "$FAKE_BIN_DIR/sudo" <<'BASH'
#!/usr/bin/env bash
"$@"
BASH
  chmod +x "$FAKE_BIN_DIR/sudo"
  cat > "$FAKE_BIN_DIR/mkdir" <<'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x "$FAKE_BIN_DIR/mkdir"
  cat > "$FAKE_BIN_DIR/wslpath" <<'BASH'
#!/usr/bin/env bash
if [ "$1" = "-w" ] && [ "$2" = "/" ]; then
  printf '%s\n' '\\wsl.localhost\Ubuntu\'
  exit 0
fi
exit 1
BASH
  chmod +x "$FAKE_BIN_DIR/wslpath"

  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: debug-source
    target: WSL://Desktop
YAML
  printf "debug" > "$REPO_DIR/configs/debug-source"

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 1 ]
  assert_output_contains_line "$output" "DIAGNÓSTICO"
  assert_output_contains_line "$output" "Fallo al convertir destino con wslpath"
}
