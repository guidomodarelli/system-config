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

@test "hardLink true crea un hard link para archivos regulares" {
  printf "hard-link-content" > "$REPO_DIR/configs/hard-source"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: hard-source
    target: linked-files
    hardLink: true
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_hard_link_points_to \
    "$HOME_DIR/linked-files/hard-source" \
    "$REPO_DIR/configs/hard-source"
  [ "$(cat "$HOME_DIR/linked-files/hard-source")" = "hard-link-content" ]
  [[ "$output" == *"hard link"* ]]
}

@test "hardLink dry-run no crea destinos" {
  printf "hard-link-content" > "$REPO_DIR/configs/hard-source"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: hard-source
    target: linked-files
    hardLink: true
YAML

  run_dotfiler "false" "--dry-run" "--no-color"

  [ "$status" -eq 0 ]
  assert_path_missing "$HOME_DIR/linked-files/hard-source"
  [[ "$output" == *"(hard link)"* ]]
  [[ "$output" == *"simulación: no se escriben cambios"* ]]
}

@test "hardLink rechaza directorios sin modificar destino" {
  mkdir -p "$REPO_DIR/configs/hard-directory"
  mkdir -p "$HOME_DIR/linked-files"
  printf "previous-content" > "$HOME_DIR/linked-files/hard-directory"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: hard-directory
    target: linked-files
    hardLink: true
YAML

  run_dotfiler "false" "--quiet" "--no-color"

  [ "$status" -eq 1 ]
  [ -f "$HOME_DIR/linked-files/hard-directory" ]
  [ "$(cat "$HOME_DIR/linked-files/hard-directory")" = "previous-content" ]
  [ ! -e "$HOME_DIR/linked-files/hard-directory.bak" ]
  [[ "$output" == *"Hard link requiere un archivo regular"* ]]
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
  [[ "$output" == *"simulación, no se escribieron cambios"* ]]
  assert_summary_value "$output" "creados" 1
  assert_summary_value "$output" "reemplazados" 0
}

@test "--quiet hides per-item logs but prints summary" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--quiet"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Resumen"* ]]
  [[ "$output" != *"📁"* ]]
  [[ "$output" != *"dotfiler ·"* ]]
  ! assert_item_line "$output" "creado" "debug-source"
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
  [[ "$output" == *"📁 ~/target-a"* ]]
  [[ "$output" == *"📁 ~/target-b"* ]]
  [[ "$output" == *"╰─ 1 cambio"$'\n\n'"📁 ~/target-b"* ]]
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
  [[ "$output" != *".codex//"* ]]
  [[ "$output" == *"📁 ~/.codex"$'\n'* ]]
  assert_item_line "$output" "creado" "debug-source"
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

@test "exactTarget enlaza un directorio en la ruta exacta sin repetir basename" {
  mkdir -p "$REPO_DIR/configs/.agents/rules"
  printf "payload-rules" > "$REPO_DIR/configs/.agents/rules/payload-validation-boundaries.md"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: .agents/rules
    exactTarget: .agents/rules
YAML

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/.agents/rules" \
    "$REPO_DIR/configs/.agents/rules"
  assert_path_missing "$HOME_DIR/.agents/rules/rules"
  [ "$(cat "$HOME_DIR/.agents/rules/payload-validation-boundaries.md")" = "payload-rules" ]
}

@test "un archivo de configuración en raíz se enlaza directamente en HOME" {
  printf "set -g allow-passthrough on\\n" > "$REPO_DIR/configs/.tmux.conf"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: .tmux.conf
    target: .
YAML

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_symlink_points_to \
    "$HOME_DIR/.tmux.conf" \
    "$REPO_DIR/configs/.tmux.conf"
}

@test "output does not print duplicated separators consecutively" {
  install_fixture "debug_flow"

  run_dotfiler "false"

  [ "$status" -eq 0 ]
  assert_no_double_blank_line "$output"
}

@test "summary table snapshot remains stable in spanish without color" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--dry-run" "--quiet" "--no-color"

  [ "$status" -eq 0 ]
  assert_output_contains_line "$output" "╭─ 📊 Resumen ─"
  assert_summary_value "$output" "creados" 1
  assert_summary_value "$output" "reemplazados" 0
  assert_summary_value "$output" "sin cambios" 0
  assert_summary_value "$output" "eliminados" 0
  assert_summary_value "$output" "respaldos" 0
  assert_summary_value "$output" "errores" 0
  assert_output_contains_line "$output" "simulación, no se escribieron cambios"
  assert_output_contains_line "$output" "🎉 Sin errores."
  [[ "$output" != *"Windows (PS)"* ]]
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
  assert_output_contains_line "$output" "🩺 Diagnóstico"
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
  assert_output_contains_line "$output" "🩺 Diagnóstico"
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
  assert_item_line "$output" "respaldo" "backup-source"
  assert_item_line "$output" "reemplazado" "backup-source"
  assert_summary_value "$output" "respaldos" 1
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
  assert_item_line "$output" "reemplazado" "replace-source"
  assert_summary_value "$output" "reemplazados" 1
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
  # The destination is outside HOME, so dotfiler uses sudo; fake it to avoid
  # a real password prompt.
  cat > "$FAKE_BIN_DIR/sudo" <<'BASH'
#!/usr/bin/env bash
exec "$@"
BASH
  chmod +x "$FAKE_BIN_DIR/sudo"

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

write_conditional_excludes_config() {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
    exclude: /^dist$/
    conditionalExcludes:
      - pattern: /^inner-leaf$/
        whenPathExists: ~/.work-marker
YAML
}

@test "conditionalExcludes no excluye cuando la ruta condicional no existe" {
  seed_filter_tree
  write_conditional_excludes_config

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
}

@test "conditionalExcludes excluye cuando la ruta condicional existe y conserva exclude base" {
  seed_filter_tree
  write_conditional_excludes_config
  mkdir -p "$HOME_DIR/.work-marker"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_path_missing "$HOME_DIR/linked-files/inner-leaf"
  assert_path_missing "$HOME_DIR/linked-files/dist"
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/very-deep" "$REPO_DIR/configs/skills-tree/(group1)/(deep)/very-deep"
}

@test "conditionalExcludes elimina symlink previo que ahora queda excluido" {
  seed_filter_tree
  write_conditional_excludes_config
  run_dotfiler "false" "--no-color"
  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"

  mkdir -p "$HOME_DIR/.work-marker"
  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_path_missing "$HOME_DIR/linked-files/inner-leaf"
  assert_item_line "$output" "eliminado" "inner-leaf"
  [[ "$output" == *"(excluido por ~/.work-marker)"* ]]
  assert_summary_value "$output" "eliminados" 1
}

@test "conditionalExcludes en dry-run informa eliminacion sin borrar el symlink" {
  seed_filter_tree
  write_conditional_excludes_config
  run_dotfiler "false" "--no-color"
  [ "$status" -eq 0 ]

  mkdir -p "$HOME_DIR/.work-marker"
  run_dotfiler "false" "--dry-run" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  assert_item_line "$output" "eliminado" "inner-leaf"
  [[ "$output" == *"(excluido por ~/.work-marker)"* ]]
  [[ "$output" == *"simulación: no se escriben cambios"* ]]
}

@test "conditionalExcludes no elimina archivos reales ni symlinks hacia otro origen" {
  seed_filter_tree
  write_conditional_excludes_config
  mkdir -p "$HOME_DIR/.work-marker" "$HOME_DIR/linked-files"
  printf "otro" > "$HOME_DIR/other-source"
  ln -s "$HOME_DIR/other-source" "$HOME_DIR/linked-files/inner-leaf"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$HOME_DIR/other-source"

  rm "$HOME_DIR/linked-files/inner-leaf"
  printf "real" > "$HOME_DIR/linked-files/inner-leaf"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [ -f "$HOME_DIR/linked-files/inner-leaf" ] && [ ! -L "$HOME_DIR/linked-files/inner-leaf" ]
  [ "$(cat "$HOME_DIR/linked-files/inner-leaf")" = "real" ]
}

@test "conditionalExcludes con regex invalido falla con diagnostico" {
  seed_filter_tree
  mkdir -p "$HOME_DIR/.work-marker"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    conditionalExcludes:
      - pattern: /^(unclosed$/
        whenPathExists: ~/.work-marker
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Patron regex invalido en conditionalExcludes"* ]]
  assert_path_missing "$HOME_DIR/linked-files/leaf-a"
}

write_directory_migration_config() {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-files
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
YAML
}

@test "reemplaza symlink de directorio hacia el repo por carpeta real sin escribir en el repo" {
  seed_filter_tree
  write_directory_migration_config
  ln -s "$REPO_DIR/configs/skills-tree" "$HOME_DIR/linked-files"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [ -d "$HOME_DIR/linked-files" ] && [ ! -L "$HOME_DIR/linked-files" ]
  assert_symlink_points_to "$HOME_DIR/linked-files/leaf-a" "$REPO_DIR/configs/skills-tree/leaf-a"
  assert_symlink_points_to "$HOME_DIR/linked-files/inner-leaf" "$REPO_DIR/configs/skills-tree/(group1)/inner-leaf"
  [ -z "$(find "$REPO_DIR/configs/skills-tree" -type l)" ]
  [ -f "$REPO_DIR/configs/skills-tree/leaf-a/SKILL.md" ]
  assert_item_line "$output" "carpeta real" "linked-files"
  [[ "$output" == *"(antes symlink a skills-tree)"* ]]
}

@test "dry-run informa reemplazo de symlink de directorio sin modificar nada" {
  seed_filter_tree
  write_directory_migration_config
  ln -s "$REPO_DIR/configs/skills-tree" "$HOME_DIR/linked-files"

  run_dotfiler "false" "--dry-run" "--no-color"

  [ "$status" -eq 0 ]
  [ -L "$HOME_DIR/linked-files" ]
  [ -z "$(find "$REPO_DIR/configs/skills-tree" -type l)" ]
  assert_item_line "$output" "carpeta real" "linked-files"
  [[ "$output" == *"(antes symlink a skills-tree)"* ]]
}

@test "rechaza crear links cuando el destino resuelve dentro del repo por un ancestro" {
  seed_filter_tree
  ln -s "$REPO_DIR/configs" "$HOME_DIR/linked-configs"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: skills-tree/*
    target: linked-configs/skills-tree
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -ne 0 ]
  [ -L "$HOME_DIR/linked-configs" ]
  [ -z "$(find "$REPO_DIR/configs/skills-tree" -type l)" ]
  [[ "$output" == *"Directorio destino dentro del repositorio"* ]]
}

@test "enlaces ya correctos no se recrean y se informan como al dia" {
  install_fixture "debug_flow"
  run_dotfiler "false" "--no-color"
  [ "$status" -eq 0 ]
  local inode_before
  inode_before=$(ls -di "$HOME_DIR/linked-files/debug-source" | awk '{print $1}')

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [ "$(ls -di "$HOME_DIR/linked-files/debug-source" | awk '{print $1}')" = "$inode_before" ]
  assert_output_contains_line "$output" "✅ Todos los enlaces están al día (1)."
  assert_summary_value "$output" "sin cambios" 1
  assert_summary_value "$output" "creados" 0
  [[ "$output" != *"📁"* ]]
}

@test "--verbose lista cada enlace sin cambios dentro de su grupo" {
  install_fixture "debug_flow"
  run_dotfiler "false" "--no-color"

  run_dotfiler "false" "--no-color" "--verbose"

  [ "$status" -eq 0 ]
  [[ "$output" == *"📁 ~/linked-files"* ]]
  assert_item_line "$output" "sin cambios" "debug-source"
  [[ "$output" == *"╰─ ✅ 1 sin cambios"* ]]
}

@test "grupos con cambios cierran con conteo de cambios y sin cambios" {
  printf "first" > "$REPO_DIR/configs/first-file"
  printf "second" > "$REPO_DIR/configs/second-file"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: first-file
    target: linked-files
YAML
  run_dotfiler "false" "--no-color"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: first-file
    target: linked-files
  - path: second-file
    target: linked-files
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  assert_item_line "$output" "creado" "second-file"
  [[ "$output" == *"╰─ 1 cambio · ✅ 1 sin cambios"* ]]
}

@test "entradas no consecutivas con el mismo destino se agrupan bajo un unico header" {
  printf "first" > "$REPO_DIR/configs/first-file"
  printf "middle" > "$REPO_DIR/configs/middle-file"
  printf "second" > "$REPO_DIR/configs/second-file"
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: first-file
    target: shared
  - path: middle-file
    target: other
  - path: second-file
    target: shared
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [ "$(printf "%s\n" "$output" | grep -c "📁 ~/shared")" -eq 1 ]
  [[ "$output" == *"📁 ~/shared"$'\n'*"first-file"*"second-file"* ]]
}

@test "--plain oculta emojis y mantiene cajas y etiquetas" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--plain"

  [ "$status" -eq 0 ]
  [[ "$output" != *"📁"* ]]
  [[ "$output" != *"✨"* ]]
  [[ "$output" != *"🎉"* ]]
  [[ "$output" == *"│ creado       debug-source"* ]]
  [[ "$output" == *"╭─ Resumen ─"* ]]
  [[ "$output" == *"Sin errores."* ]]
}

@test "errores muestran caja de diagnostico con destino y causa" {
  cat > "$REPO_DIR/symlinks.yml" <<'YAML'
paths:
  - path: nonexistent-source
    target: linked-files
YAML

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 1 ]
  [[ "$output" == *"╭─ 🩺 Diagnóstico ─"* ]]
  [[ "$output" == *"│ 1. ~/linked-files/nonexistent-source"* ]]
  [[ "$output" == *"│    "*"Ruta de origen inexistente"* ]]
  [[ "$output" == *"💥 Finalizado con 1 error(es)."* ]]
}

@test "DOTFILER_PROGRESS=always muestra loader de resolucion y progreso de enlaces" {
  install_fixture "debug_flow"

  DOTFILER_PROGRESS=always run_dotfiler_with_env "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Enlazando"*"1/1"*"debug-source"* ]]
  [[ "$output" == *$'\r\e[K'* ]]
  [[ "$output" == *$'\e[?25h'* ]]
  assert_item_line "$output" "creado" "debug-source"
  assert_summary_value "$output" "creados" 1
}

@test "sin terminal interactiva no se emiten secuencias de loader" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Enlazando"* ]]
  [[ "$output" != *$'\e[?25l'* ]]
}

# Fails when the text has non-ASCII bytes other than Spanish letters.
assert_ascii_decorations() {
  local output_text="$1"
  local without_spanish_letters
  without_spanish_letters="$(printf "%s" "$output_text" | LC_ALL=C sed -e 's/á//g; s/é//g; s/í//g; s/ó//g; s/ú//g; s/ñ//g; s/Á//g; s/É//g; s/Í//g; s/Ó//g; s/Ú//g; s/Ñ//g')"
  ! printf "%s" "$without_spanish_letters" | LC_ALL=C grep -q '[^ -~[:cntrl:]]'
}

@test "--ascii usa solo ASCII en decoraciones" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--ascii" "--no-color"

  [ "$status" -eq 0 ]
  assert_ascii_decorations "$output"
  [[ "$output" == *"+- Resumen -"* ]]
  [[ "$output" == *"> ~/linked-files"* ]]
  [[ "$output" == *"| + creado"*"-> debug-source"* ]]
  [[ "$output" == *"+----"* ]]
}

@test "--unicode usa cajas Unicode sin emojis" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--unicode" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" == *"╭─ Resumen ─"* ]]
  [[ "$output" == *"▸ ~/linked-files"* ]]
  [[ "$output" == *"│ + creado"* ]]
  [[ "$output" == *"✓ Sin errores."* ]]
  [[ "$output" != *"📁"* ]]
  [[ "$output" != *"✨"* ]]
  [[ "$output" != *"🎉"* ]]
  [[ "$output" != *"📊"* ]]
}

@test "--ascii con DOTFILER_PROGRESS=always usa spinner y barra ASCII" {
  install_fixture "debug_flow"

  DOTFILER_PROGRESS=always run_dotfiler_with_env "--ascii" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Enlazando "*"1/1"* ]]
  [[ "$output" == *"############"* ]]
  [[ "$output" != *"▰"* ]]
  [[ "$output" != *"⠋"* ]]
}

@test "--ascii y --unicode juntas fallan como error de uso" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--ascii" "--unicode"

  [ "$status" -eq 2 ]
  [[ "$output" == *"--ascii y --unicode son excluyentes"* ]]
  assert_path_missing "$HOME_DIR/linked-files/debug-source"
}

@test "sin flags de modo se mantienen los emojis" {
  install_fixture "debug_flow"

  run_dotfiler "false" "--no-color"

  [ "$status" -eq 0 ]
  [[ "$output" == *"📁 ~/linked-files"* ]]
  [[ "$output" == *"╭─ 📊 Resumen ─"* ]]
}
