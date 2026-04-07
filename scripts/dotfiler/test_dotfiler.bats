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
  assert_path_missing "$HOME_DIR/linked-files/excluded-file"
  assert_symlink_points_to \
    "$HOME_DIR/linked-files/included-file" \
    "$REPO_DIR/configs/included-file"
}
