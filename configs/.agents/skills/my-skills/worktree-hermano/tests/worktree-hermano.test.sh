#!/usr/bin/env bash
set -euo pipefail

HELPER=${HELPER:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/worktree-hermano"}
failures=0
tests_run=0
TEST_ROOT=
TEST_FAILED=false

fail() {
  TEST_FAILED=true
  printf 'FAIL: %s\n' "$1" >&2
  return 1
}

assert_status() {
  local expected=$1
  if [[ "$TEST_STATUS" -ne "$expected" ]]; then
    fail "expected exit $expected, got $TEST_STATUS; stdout: $(tr '\n' ' ' < "$STDOUT_FILE"); stderr: $(tr '\n' ' ' < "$STDERR_FILE")"
  fi
}

assert_contains() {
  local file=$1
  local expected=$2
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_exists() {
  local path=$1
  [[ ! -e "$path" && ! -L "$path" ]] || fail "did not expect path to exist: $path"
}

setup_fixture() {
  TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/worktree-hermano-test.XXXXXX")
  TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P)
  WORK_PARENT="$TEST_ROOT/parent"
  REPO="$WORK_PARENT/repository"
  REMOTE="$TEST_ROOT/origin.git"
  STDOUT_FILE="$TEST_ROOT/stdout"
  STDERR_FILE="$TEST_ROOT/stderr"

  mkdir -p "$WORK_PARENT"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.name 'Worktree Test'
  git -C "$REPO" config user.email 'worktree-test@example.com'
  printf 'base\n' > "$REPO/file.txt"
  git -C "$REPO" add file.txt
  git -C "$REPO" commit -qm 'base'
  git -C "$REPO" branch develop
  git -C "$REPO" branch feature/local

  git init --bare -q "$REMOTE"
  git -C "$REPO" remote add origin "$REMOTE"
  git -C "$REPO" push -q -u origin main
  git -C "$REPO" push -q origin develop

  git -C "$REPO" checkout -qb temp/remote-source
  printf 'remote\n' >> "$REPO/file.txt"
  git -C "$REPO" add file.txt
  git -C "$REPO" commit -qm 'remote source'
  git -C "$REPO" push -q origin HEAD:refs/heads/feature/remote
  git -C "$REPO" checkout -q main
  git -C "$REPO" branch -D temp/remote-source >/dev/null
  git -C "$REPO" fetch -q origin

  export TEST_ROOT WORK_PARENT REPO REMOTE STDOUT_FILE STDERR_FILE
}

teardown_fixture() {
  if [[ -n "$TEST_ROOT" ]]; then
    rm -rf -- "$TEST_ROOT"
    TEST_ROOT=
  fi
}

run_helper() {
  set +e
  (
    cd "$REPO"
    "$HELPER" "$@"
  ) > "$STDOUT_FILE" 2> "$STDERR_FILE"
  TEST_STATUS=$?
  set -e
}

test_help_and_invalid_operation() {
  setup_fixture
  run_helper --help
  assert_status 0
  assert_contains "$STDOUT_FILE" 'worktree-hermano create'

  run_helper unknown
  assert_status 2
  teardown_fixture
}

test_create_local_branch() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-local"

  run_helper create --branch feature/local --dry-run
  assert_status 0
  assert_not_exists "$target"
  assert_contains "$STDOUT_FILE" "Destino hermano: $target"

  run_helper create --branch feature/local
  assert_status 0
  [[ -d "$target" ]] || fail "expected worktree directory: $target"
  [[ "$(git -C "$target" branch --show-current)" == 'feature/local' ]] || fail 'expected local branch checkout'
  assert_contains "$STDOUT_FILE" 'Worktree creado correctamente.'
  teardown_fixture
}

test_create_remote_tracking_branch() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-remote"

  run_helper create --branch origin/feature/remote
  assert_status 0
  [[ "$(git -C "$target" branch --show-current)" == 'feature/remote' ]] || fail 'expected remote branch to become local branch'
  [[ "$(git -C "$target" rev-parse --abbrev-ref --symbolic-full-name '@{u}')" == 'origin/feature/remote' ]] || fail 'expected remote tracking branch'
  assert_contains "$STDOUT_FILE" 'tracking local se creará'
  teardown_fixture
}

test_explicit_path_and_existing_path_block() {
  local target
  setup_fixture
  target="$WORK_PARENT/custom-worktree"

  run_helper create --branch feature/local --path "$target"
  assert_status 0
  [[ -d "$target" ]] || fail 'expected explicit path worktree'

  run_helper create --branch feature/local --path "$target"
  assert_status 3
  assert_contains "$STDERR_FILE" 'ruta destino ya existe'
  teardown_fixture
}

test_primary_branch_requires_confirmation() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-main-copy"

  run_helper create --branch main --path "$target"
  assert_status 3
  [[ "$(git -C "$REPO" branch --show-current)" == 'main' ]] || fail 'principal changed without confirmation'
  assert_not_exists "$target"
  assert_contains "$STDERR_FILE" 'requiere confirmación explícita'
  teardown_fixture
}

test_confirmed_primary_switch_to_develop() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-main-copy"

  run_helper create --branch main --path "$target" --confirm-primary-switch-to-develop --dry-run
  assert_status 0
  [[ "$(git -C "$REPO" branch --show-current)" == 'main' ]] || fail 'dry-run changed principal'
  assert_not_exists "$target"

  run_helper create --branch main --path "$target" --confirm-primary-switch-to-develop
  assert_status 0
  [[ "$(git -C "$REPO" branch --show-current)" == 'develop' ]] || fail 'expected principal to move to develop'
  [[ "$(git -C "$target" branch --show-current)" == 'main' ]] || fail 'expected requested branch in new worktree'
  teardown_fixture
}

test_dirty_primary_blocks_confirmed_switch() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-main-copy"
  printf 'local change\n' >> "$REPO/file.txt"

  run_helper create --branch main --path "$target" --confirm-primary-switch-to-develop
  assert_status 3
  [[ "$(git -C "$REPO" branch --show-current)" == 'main' ]] || fail 'dirty principal changed'
  assert_not_exists "$target"
  assert_contains "$STDERR_FILE" 'cambios no committeados'
  teardown_fixture
}

test_dry_run_does_not_mutate() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-local"

  run_helper create --branch feature/local --name ignored-name --dry-run
  assert_status 0
  assert_not_exists "$WORK_PARENT/repository-ignored-name"
  assert_contains "$STDOUT_FILE" 'Dry-run: comandos previstos:'
  teardown_fixture
}

test_list_reports_worktrees() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-local"
  run_helper create --branch feature/local
  assert_status 0

  run_helper list
  assert_status 0
  assert_contains "$STDOUT_FILE" 'rol: principal/actual'
  assert_contains "$STDOUT_FILE" 'rama: feature/local'
  assert_contains "$STDOUT_FILE" "ruta: $target"
  teardown_fixture
}

test_remove_clean_worktree_preserves_branch() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-local"
  run_helper create --branch feature/local
  assert_status 0

  run_helper remove --branch feature/local --dry-run
  assert_status 0
  [[ -d "$target" ]] || fail 'dry-run removed worktree'

  run_helper remove --branch feature/local
  assert_status 0
  assert_not_exists "$target"
  git -C "$REPO" show-ref --verify --quiet refs/heads/feature/local || fail 'remove deleted local branch'
  teardown_fixture
}

test_remove_dirty_or_ignored_worktree_blocks() {
  local target
  setup_fixture
  target="$WORK_PARENT/repository-local"
  run_helper create --branch feature/local
  assert_status 0
  printf 'local change\n' >> "$target/file.txt"

  run_helper remove --branch feature/local
  assert_status 3
  [[ -d "$target" ]] || fail 'dirty worktree was removed'
  assert_contains "$STDERR_FILE" 'cambios o archivos ignorados'
  teardown_fixture
}

test_invalid_path_and_symlink_block() {
  local existing_target
  local symlink_target
  setup_fixture
  existing_target="$WORK_PARENT/existing"
  symlink_target="$WORK_PARENT/repository-symlink"
  mkdir -p "$existing_target"
  ln -s "$existing_target" "$symlink_target"

  run_helper create --branch feature/local --path "$existing_target"
  assert_status 3
  run_helper create --branch feature/local --path "$symlink_target"
  assert_status 3
  assert_contains "$STDERR_FILE" 'ruta destino ya existe'
  teardown_fixture
}

run_test() {
  local name=$1
  local test_function=$2
  tests_run=$((tests_run + 1))
  TEST_FAILED=false
  "$test_function" || true
  if [[ "$TEST_FAILED" == false ]]; then
    printf 'ok %d - %s\n' "$tests_run" "$name"
  else
    failures=$((failures + 1))
    printf 'not ok %d - %s\n' "$tests_run" "$name"
    teardown_fixture
  fi
}

trap teardown_fixture EXIT

run_test 'help and invalid operation' test_help_and_invalid_operation
run_test 'create local branch' test_create_local_branch
run_test 'create remote tracking branch' test_create_remote_tracking_branch
run_test 'explicit and existing path handling' test_explicit_path_and_existing_path_block
run_test 'primary branch confirmation gate' test_primary_branch_requires_confirmation
run_test 'confirmed primary switch to develop' test_confirmed_primary_switch_to_develop
run_test 'dirty primary confirmation gate' test_dirty_primary_blocks_confirmed_switch
run_test 'dry-run does not mutate' test_dry_run_does_not_mutate
run_test 'list reports worktrees' test_list_reports_worktrees
run_test 'remove clean worktree preserves branch' test_remove_clean_worktree_preserves_branch
run_test 'remove dirty worktree gate' test_remove_dirty_or_ignored_worktree_blocks
run_test 'invalid path and symlink gate' test_invalid_path_and_symlink_block

if [[ "$failures" -ne 0 ]]; then
  printf '%d/%d tests fallaron\n' "$failures" "$tests_run" >&2
  exit 1
fi

printf '%d tests pasaron\n' "$tests_run"
