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

@test "directorios anidados dentro de HOME no requieren sudo" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: nested-source
    target: .agents/skills
YAML
  printf "nested" > "$REPO_DIR/configs/nested-source"
  cat > "$FAKE_BIN_DIR/sudo" <<'BASH'
#!/usr/bin/env bash
exit 99
BASH
  chmod +x "$FAKE_BIN_DIR/sudo"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/.agents/skills/nested-source" \
    "$REPO_DIR/configs/nested-source"
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

@test "exactTarget se usa como ruta final del symlink" {
  mkdir -p "$REPO_DIR/configs/.codex"
  printf "agents" > "$REPO_DIR/configs/.codex/AGENTS.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: .codex/AGENTS.md
    exactTarget: .claude/CLAUDE.md
YAML

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/.claude/CLAUDE.md" \
    "$REPO_DIR/configs/.codex/AGENTS.md"
  assert_path_missing "$HOME_DIR/AGENTS.md"
}

@test "output does not print duplicated separators consecutively" {
  install_fixture "debug_flow"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_no_double_separator "$output"
}

@test "summary table snapshot remains stable in spanish without color" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--dry-run" "--quiet" "--no-color"

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

  run_dotfiler "false" "--quiet" "--no-color"

  [ "$status" -eq 1 ]
  assert_output_contains_line "$output" "DIAGNÓSTICO"
  assert_output_contains_line "$output" "Fallo al crear symlink"
}

@test "invalid config returns exit code 2" {
  printf "paths: [\n" > "$REPO_DIR/symlinks.yml"

  run_dotfiler "false" "--quiet" "--no-color"

  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"Configuración inválida"* ]]
}

@test "missing source path is counted as a runtime error" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: nonexistent-source
    target: linked-files
YAML

  run_dotfiler "false" "--quiet" "--no-color"

  [ "$status" -eq 1 ]
  assert_output_contains_line "$output" "DIAGNÓSTICO"
  assert_output_contains_line "$output" "Ruta de origen inexistente"
  assert_path_missing "$HOME_DIR/linked-files/nonexistent-source"
}

@test "existing regular file is backed up before linking" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: backup-source
    target: linked-files
YAML
  printf "source-content" > "$REPO_DIR/configs/backup-source"
  mkdir -p "$HOME_DIR/linked-files"
  printf "previous-content" > "$HOME_DIR/linked-files/backup-source"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/backup-source" \
    "$REPO_DIR/configs/backup-source"
  [ -f "$HOME_DIR/linked-files/backup-source.bak" ]
  [ "$(cat "$HOME_DIR/linked-files/backup-source.bak")" = "previous-content" ]
  assert_output_contains_line "$output" "Respaldos"
}

@test "source path supports USER variable expansion" {
  mkdir -p "$REPO_DIR/configs/users/test-user"
  printf "owned-by-user" > "$REPO_DIR/configs/users/test-user/profile.txt"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: users/$USER/profile.txt
    target: linked-files
YAML

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/profile.txt" \
    "$REPO_DIR/configs/users/test-user/profile.txt"
}

@test "existing symlink is replaced and counted as reemplazado" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: replace-source
    target: linked-files
YAML
  printf "new" > "$REPO_DIR/configs/replace-source"
  mkdir -p "$HOME_DIR/linked-files" "$HOME_DIR/old-target"
  printf "old" > "$HOME_DIR/old-target/replace-source"
  ln -s "$HOME_DIR/old-target/replace-source" "$HOME_DIR/linked-files/replace-source"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/replace-source" \
    "$REPO_DIR/configs/replace-source"
  assert_output_contains_line "$output" "Symlink anterior eliminado"
  assert_output_contains_line "$output" "Reemplazados"
}

@test "stale .bak symlink is removed before recreating link" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: bak-source
    target: linked-files
YAML
  printf "current" > "$REPO_DIR/configs/bak-source"
  mkdir -p "$HOME_DIR/linked-files" "$HOME_DIR/dangling"
  printf "stale" > "$HOME_DIR/dangling/bak-source"
  ln -s "$HOME_DIR/dangling/bak-source" "$HOME_DIR/linked-files/bak-source.bak"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [ ! -L "$HOME_DIR/linked-files/bak-source.bak" ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/bak-source" \
    "$REPO_DIR/configs/bak-source"
}

@test "glob source expands every entry of its parent directory" {
  mkdir -p "$REPO_DIR/configs/glob-dir"
  printf "alpha" > "$REPO_DIR/configs/glob-dir/alpha"
  printf "beta" > "$REPO_DIR/configs/glob-dir/beta"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: glob-dir/*
    target: linked-files
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/alpha" \
    "$REPO_DIR/configs/glob-dir/alpha"
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/beta" \
    "$REPO_DIR/configs/glob-dir/beta"
}

@test "elevated permissions branch invokes the configured prefix" {
  local non_home_dir="$TEST_DIR/non-home"
  mkdir -p "$non_home_dir"
  printf "elevated" > "$REPO_DIR/configs/elevated-source"
  cat > "$REPO_DIR/symlinks.yml" <<YAML
paths:
  - path: elevated-source
    exactTarget: ${non_home_dir}/elevated-link
YAML
  cat > "$FAKE_BIN_DIR/sudo" <<BASH
#!/usr/bin/env bash
printf "sudo %s\\n" "\$*" >> "$TEST_DIR/sudo.log"
exec "\$@"
BASH
  chmod +x "$FAKE_BIN_DIR/sudo"

  run_dotfiler "false" "--quiet" "--no-color"

  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/sudo.log" ]
  grep -q "^sudo mkdir -p ${non_home_dir}\$" "$TEST_DIR/sudo.log"
  grep -q "^sudo ln -s " "$TEST_DIR/sudo.log"
  assert_symlink_points_to \
    "${non_home_dir}/elevated-link" \
    "$REPO_DIR/configs/elevated-source"
}

@test "verbose mode prints elapsed seconds for each operation" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--verbose" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" == *"TIEMPO"* ]]
  [[ "$output" == *"transcurrido="* ]]
}

@test "abbreviate_home_path no abrevia prefijos parciales del HOME" {
  local home_twin="${HOME_DIR}-twin"
  mkdir -p "$home_twin"
  printf "home-prefix" > "$REPO_DIR/configs/home-prefix-source"
  cat > "$REPO_DIR/symlinks.yml" <<YAML
paths:
  - path: home-prefix-source
    exactTarget: ${home_twin}/home-prefix-source
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" != *"~-twin"* ]]
  [[ "$output" == *"$home_twin"* ]]
}

@test "existing .bak file is preserved when creating a new backup" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: backup-source
    target: linked-files
YAML
  printf "source-content" > "$REPO_DIR/configs/backup-source"
  mkdir -p "$HOME_DIR/linked-files"
  printf "previous-content" > "$HOME_DIR/linked-files/backup-source"
  printf "older-backup" > "$HOME_DIR/linked-files/backup-source.bak"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/backup-source" \
    "$REPO_DIR/configs/backup-source"
  [ -f "$HOME_DIR/linked-files/backup-source.bak" ]
  [ "$(cat "$HOME_DIR/linked-files/backup-source.bak")" = "older-backup" ]
  [ -f "$HOME_DIR/linked-files/backup-source.bak.1" ]
  [ "$(cat "$HOME_DIR/linked-files/backup-source.bak.1")" = "previous-content" ]
}

@test "leading tilde in source is expanded but tilde inside path is preserved" {
  mkdir -p "$REPO_DIR/configs"
  printf "tilde-literal" > "$REPO_DIR/configs/has~tilde"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: has~tilde
    target: linked-files
YAML

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/has~tilde" \
    "$REPO_DIR/configs/has~tilde"
}

# Helper for filter-related tests: builds the standard skills-like tree.
seed_filter_tree() {
  mkdir -p "$REPO_DIR/configs/skills-tree/leaf-a"
  mkdir -p "$REPO_DIR/configs/skills-tree/leaf-b"
  mkdir -p "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  mkdir -p "$REPO_DIR/configs/skills-tree/(group1)/(deep)/very-deep"
  mkdir -p "$REPO_DIR/configs/skills-tree/no-marker"
  mkdir -p "$REPO_DIR/configs/skills-tree/dist/anything"
  printf "a" > "$REPO_DIR/configs/skills-tree/leaf-a/SKILL.md"
  printf "b" > "$REPO_DIR/configs/skills-tree/leaf-b/SKILL.md"
  printf "x" > "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf/SKILL.md"
  printf "y" > "$REPO_DIR/configs/skills-tree/(group1)/(deep)/very-deep/SKILL.md"
  printf "z" > "$REPO_DIR/configs/skills-tree/dist/anything/SKILL.md"
  printf "top" > "$REPO_DIR/configs/skills-tree/file.txt"
  printf "tmp" > "$REPO_DIR/configs/skills-tree/excluded.tmp"
}

@test "exclude descarta basenames top-level matcheados" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    exclude: /^(dist|excluded\.tmp)$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/file.txt" "$REPO_DIR/configs/skills-tree/file.txt"
  assert_path_missing "$HOME_DIR/linked-files/dist"
  assert_path_missing "$HOME_DIR/linked-files/excluded.tmp"
}

@test "markerFile filtra top-level folders sin el archivo" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    markerFile: SKILL.md
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-b" "$REPO_DIR/configs/skills-tree/leaf-b"
  assert_path_missing "$HOME_DIR/linked-files/no-marker"
  # markerFile no aplica a archivos top-level
  assert_symlink_points_to "$HOME_DIR/linked-files/file.txt" "$REPO_DIR/configs/skills-tree/file.txt"
}

@test "descendInto recursivo enlaza hojas dentro de agrupadores anidados" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
    exclude: /^dist$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-b" "$REPO_DIR/configs/skills-tree/leaf-b"
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  assert_symlink_points_to "$HOME_DIR/linked-files/very-deep" "$REPO_DIR/configs/skills-tree/(group1)/(deep)/very-deep"
  assert_path_missing "$HOME_DIR/linked-files/(group1)"
  assert_path_missing "$HOME_DIR/linked-files/no-marker"
  assert_path_missing "$HOME_DIR/linked-files/dist"
}

@test "exclude profundo dentro de un agrupador descarta el subtree" {
  mkdir -p "$REPO_DIR/configs/tree/(group)/keep/leaf"
  mkdir -p "$REPO_DIR/configs/tree/(group)/skip/inner"
  printf "k" > "$REPO_DIR/configs/tree/(group)/keep/leaf/SKILL.md"
  printf "s" > "$REPO_DIR/configs/tree/(group)/skip/inner/SKILL.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: tree/*
    target: linked-files
    descendInto: /^(\(group\)|keep)$/
    markerFile: SKILL.md
    exclude: /^skip$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf" "$REPO_DIR/configs/tree/(group)/keep/leaf"
  assert_path_missing "$HOME_DIR/linked-files/inner"
}

@test "path sin /* con filtros emite advertencia y los ignora" {
  mkdir -p "$REPO_DIR/configs/single-dir"
  printf "x" > "$REPO_DIR/configs/single-dir/payload"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: single-dir
    target: linked-files
    descendInto: /foo/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/single-dir" "$REPO_DIR/configs/single-dir"
  [[ "$output" == *"solo aplican con path terminado en"* ]]
}

@test "regex invalido en descendInto cuenta como error y omite la entrada" {
  mkdir -p "$REPO_DIR/configs/bad-tree/leaf"
  printf "x" > "$REPO_DIR/configs/bad-tree/leaf/SKILL.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: bad-tree/*
    target: linked-files
    descendInto: "/[/"
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -ne 0 ]
  assert_path_missing "$HOME_DIR/linked-files/leaf"
}

@test "colision de basename al aplanar conserva el primero y reporta error" {
  mkdir -p "$REPO_DIR/configs/colliding/(g1)/dup"
  mkdir -p "$REPO_DIR/configs/colliding/(g2)/dup"
  printf "1" > "$REPO_DIR/configs/colliding/(g1)/dup/SKILL.md"
  printf "2" > "$REPO_DIR/configs/colliding/(g2)/dup/SKILL.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: colliding/*
    target: linked-files
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -ne 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/dup" "$REPO_DIR/configs/colliding/(g1)/dup"
  [[ "$output" == *"Colision de basename"* ]]
}

@test "slashes decorativos producen el mismo resultado que sin ellos" {
  mkdir -p "$REPO_DIR/configs/slash-test/keeper"
  mkdir -p "$REPO_DIR/configs/slash-test/dropper"
  printf "k" > "$REPO_DIR/configs/slash-test/keeper/SKILL.md"
  printf "d" > "$REPO_DIR/configs/slash-test/dropper/SKILL.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: slash-test/*
    target: linked-files
    exclude: /^dropper$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/keeper" "$REPO_DIR/configs/slash-test/keeper"
  assert_path_missing "$HOME_DIR/linked-files/dropper"
}

@test "archivos dentro de agrupador se enlazan con descendInto activo" {
  mkdir -p "$REPO_DIR/configs/withfiles/(grp)"
  printf "f" > "$REPO_DIR/configs/withfiles/(grp)/utility.js"
  mkdir -p "$REPO_DIR/configs/withfiles/(grp)/leaf"
  printf "l" > "$REPO_DIR/configs/withfiles/(grp)/leaf/SKILL.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: withfiles/*
    target: linked-files
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/utility.js" "$REPO_DIR/configs/withfiles/(grp)/utility.js"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf" "$REPO_DIR/configs/withfiles/(grp)/leaf"
}

@test "Combinacion (-,-,-): sin filtros mantiene comportamiento del glob original" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/no-marker" "$REPO_DIR/configs/skills-tree/no-marker"
  assert_symlink_points_to "$HOME_DIR/linked-files/dist" "$REPO_DIR/configs/skills-tree/dist"
  assert_symlink_points_to "$HOME_DIR/linked-files/file.txt" "$REPO_DIR/configs/skills-tree/file.txt"
  assert_symlink_points_to "$HOME_DIR/linked-files/excluded.tmp" "$REPO_DIR/configs/skills-tree/excluded.tmp"
  # No desciende en (group1) sin descendInto
  assert_path_missing "$HOME_DIR/linked-files/inner-leaf"
}

@test "Combinacion (-,markerFile,exclude): filtra ambos en top-level" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    markerFile: SKILL.md
    exclude: /^dist$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-b" "$REPO_DIR/configs/skills-tree/leaf-b"
  assert_symlink_points_to "$HOME_DIR/linked-files/file.txt" "$REPO_DIR/configs/skills-tree/file.txt"
  assert_path_missing "$HOME_DIR/linked-files/no-marker"
  assert_path_missing "$HOME_DIR/linked-files/dist"
}

@test "Combinacion (descendInto,-,-): trata no-matches como hojas" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    descendInto: /^\(.*\)$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  # Hojas top-level que no matchean descendInto
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/no-marker" "$REPO_DIR/configs/skills-tree/no-marker"
  assert_symlink_points_to "$HOME_DIR/linked-files/dist" "$REPO_DIR/configs/skills-tree/dist"
  # Hojas dentro del agrupador descubiertas (sin marker, toda hoja-folder vale)
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  assert_symlink_points_to "$HOME_DIR/linked-files/file.txt" "$REPO_DIR/configs/skills-tree/file.txt"
  # El agrupador en si NO se enlaza
  assert_path_missing "$HOME_DIR/linked-files/(group1)"
}

@test "Combinacion (descendInto,-,exclude): poda subtrees sin requerir marker" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    descendInto: /^\(.*\)$/
    exclude: /^(dist|no-marker)$/
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-b" "$REPO_DIR/configs/skills-tree/leaf-b"
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  assert_path_missing "$HOME_DIR/linked-files/no-marker"
  assert_path_missing "$HOME_DIR/linked-files/dist"
}

@test "Combinacion (descendInto,markerFile,-): solo hojas con marker, sin exclude" {
  seed_filter_tree
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-b" "$REPO_DIR/configs/skills-tree/leaf-b"
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  assert_symlink_points_to "$HOME_DIR/linked-files/very-deep" "$REPO_DIR/configs/skills-tree/(group1)/(deep)/very-deep"
  # no-marker no tiene SKILL.md, no se enlaza
  assert_path_missing "$HOME_DIR/linked-files/no-marker"
  # dist no matchea descendInto y no tiene marker -> hoja-folder sin marker -> skip
  # ademas, sin exclude, dist no fue descartado, pero su tratamiento como hoja sin marker es lo que aplica
  assert_path_missing "$HOME_DIR/linked-files/dist"
  assert_path_missing "$HOME_DIR/linked-files/anything"
}
