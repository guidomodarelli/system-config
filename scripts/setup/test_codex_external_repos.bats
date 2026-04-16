#!/usr/bin/env bats

setup() {
  TEST_ROOT="$(mktemp -d)"
  TEST_HOME="$TEST_ROOT/home"
  REMOTES_DIR="$TEST_ROOT/remotes"
  MANIFEST_PATH="$TEST_ROOT/external-repos.yml"
  SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/codex-external-repos.sh"

  mkdir -p "$TEST_HOME" "$REMOTES_DIR"

  CAVEMAN_REMOTE_PATH="$(create_remote_repo "caveman")"
  SUPERPOWERS_REMOTE_PATH="$(create_remote_repo "superpowers")"

  cat > "$MANIFEST_PATH" <<YAML
repos:
  - name: caveman
    kind: marketplace-plugin
    repo_url: $CAVEMAN_REMOTE_PATH
    branch: main
    clone_target: ~/plugins/caveman
    post_install: manual_codex_activation
  - name: superpowers
    kind: skills-repo
    repo_url: $SUPERPOWERS_REMOTE_PATH
    branch: main
    clone_target: ~/.codex/superpowers
    skill_link_target: ~/.agents/skills/superpowers
    skill_source: ~/.codex/superpowers/skills
YAML
}

teardown() {
  rm -rf "$TEST_ROOT"
}

create_remote_repo() {
  local repository_name="$1"
  local bare_repo_path="$REMOTES_DIR/${repository_name}.git"
  local working_repo_path="$TEST_ROOT/${repository_name}-working"

  git -c gc.auto=0 -c maintenance.auto=false init --bare "$bare_repo_path" >/dev/null
  git -c gc.auto=0 -c maintenance.auto=false init -b main "$working_repo_path" >/dev/null

  (
    cd "$working_repo_path" || exit 1
    git config user.name "Test User"
    git config user.email "test@example.com"
    git config gc.auto 0
    git config maintenance.auto false

    if [[ "$repository_name" == "superpowers" ]]; then
      mkdir -p skills
      printf "superpowers skill\n" > skills/SKILL.md
    else
      mkdir -p .codex-plugin
      printf '{ "name": "caveman" }\n' > .codex-plugin/plugin.json
    fi

    git add .
    git -c core.hooksPath=/dev/null commit -m "Initial commit" >/dev/null
    git remote add origin "$bare_repo_path"
    git -c gc.auto=0 -c maintenance.auto=false push origin main >/dev/null
  )

  printf "%s\n" "$bare_repo_path"
}

run_external_repos() {
  run env \
    HOME="$TEST_HOME" \
    CODEX_EXTERNAL_REPOS_MANIFEST="$MANIFEST_PATH" \
    bash "$SCRIPT_UNDER_TEST" "$@"
}

assert_symlink_target() {
  local symlink_path="$1"
  local expected_target="$2"

  [ -L "$symlink_path" ]
  local actual_target
  actual_target="$(readlink "$symlink_path")"
  actual_target="$(realpath "$actual_target")"
  expected_target="$(realpath "$expected_target")"

  [ "$actual_target" = "$expected_target" ]
}

push_new_commit() {
  local repository_name="$1"
  local working_repo_path="$TEST_ROOT/${repository_name}-working"

  (
    cd "$working_repo_path" || exit 1
    printf "update\n" >> CHANGELOG.md
    git add CHANGELOG.md
    git -c core.hooksPath=/dev/null commit -m "Update ${repository_name}" >/dev/null
    git -c gc.auto=0 -c maintenance.auto=false push origin main >/dev/null
  )
}

@test "list prints configured repositories" {
  run_external_repos list

  [ "$status" -eq 0 ]
  [[ "$output" == *"caveman"* ]]
  [[ "$output" == *"marketplace-plugin"* ]]
  [[ "$output" == *"superpowers"* ]]
  [[ "$output" == *"skills-repo"* ]]
}

@test "install clones missing repositories and creates the superpowers skill symlink" {
  run_external_repos install

  [ "$status" -eq 0 ]
  [ -d "$TEST_HOME/plugins/caveman/.git" ]
  [ -d "$TEST_HOME/.codex/superpowers/.git" ]
  assert_symlink_target \
    "$TEST_HOME/.agents/skills/superpowers" \
    "$TEST_HOME/.codex/superpowers/skills"
}

@test "install does not replace existing clones" {
  run_external_repos install
  [ "$status" -eq 0 ]

  local caveman_head_before
  caveman_head_before="$(git -C "$TEST_HOME/plugins/caveman" rev-parse HEAD)"

  push_new_commit "caveman"

  run_external_repos install caveman

  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]

  local caveman_head_after
  caveman_head_after="$(git -C "$TEST_HOME/plugins/caveman" rev-parse HEAD)"

  [ "$caveman_head_before" = "$caveman_head_after" ]
}

@test "update fast-forwards existing repositories and reports missing clones" {
  run_external_repos install superpowers
  [ "$status" -eq 0 ]

  local head_before_update
  head_before_update="$(git -C "$TEST_HOME/.codex/superpowers" rev-parse HEAD)"

  push_new_commit "superpowers"

  run_external_repos update

  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping caveman"* ]]

  local head_after_update
  head_after_update="$(git -C "$TEST_HOME/.codex/superpowers" rev-parse HEAD)"

  [ "$head_before_update" != "$head_after_update" ]
  assert_symlink_target \
    "$TEST_HOME/.agents/skills/superpowers" \
    "$TEST_HOME/.codex/superpowers/skills"
}

@test "update does not create symlink when clone is missing" {
  run_external_repos update superpowers

  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping superpowers"* ]]
  [ ! -e "$TEST_HOME/.agents/skills/superpowers" ]
}

@test "dry-run does not clone repositories or create symlinks" {
  run_external_repos install --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Would install caveman into $TEST_HOME/plugins/caveman"* ]]
  [[ "$output" == *"Would install superpowers into $TEST_HOME/.codex/superpowers"* ]]
  [[ "$output" == *"Would ensure symlink for superpowers"* ]]
  [[ "$output" != *"Installed caveman into"* ]]
  [[ "$output" != *"Installed superpowers into"* ]]
  [[ "$output" != *"Ensured symlink for superpowers"* ]]
  [ ! -e "$TEST_HOME/plugins/caveman" ]
  [ ! -e "$TEST_HOME/.codex/superpowers" ]
  [ ! -e "$TEST_HOME/.agents/skills/superpowers" ]
}

@test "commands fail when requested repository is not defined in manifest" {
  for command_name in list install update; do
    run_external_repos "$command_name" "does-not-exist"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Repository 'does-not-exist' is not defined"* ]]
  done
}
