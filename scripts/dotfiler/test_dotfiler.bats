#!/usr/bin/env bats

load "test/test_helper.bash"

setup() {
  setup_test_environment
}

teardown() {
  teardown_test_environment
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
  assert_symlink_points_to \
    "$HOME_DIR/.agents/skills/commands" \
    "$REPO_DIR/configs/.agents/skills/commands"
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

@test "source path supports HOME variable expansion" {
  mkdir -p "$HOME_DIR/.codex/skills"
  printf "skill-data" > "$HOME_DIR/.codex/skills/system.txt"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: $HOME/.codex/skills/system.txt
    target: linked-files
YAML

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/system.txt" \
    "$HOME_DIR/.codex/skills/system.txt"
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

@test "invalid config returns exit code 2" {
  printf "paths: [\n" > "$REPO_DIR/symlinks.yml"

  run_dotfiler "false" "--quiet --no-color"

  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"Configuración inválida"* ]]
}
