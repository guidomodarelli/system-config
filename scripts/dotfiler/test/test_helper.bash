#!/usr/bin/env bash

setup_test_environment() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  SCRIPT_UNDER_TEST="$SCRIPT_DIR/dotfiler.sh"
  TEST_ASSETS_DIR="$SCRIPT_DIR/test"

  TEST_DIR="$(mktemp -d)"
  REPO_DIR="$TEST_DIR/repo"
  HOME_DIR="$TEST_DIR/home"
  FAKE_BIN_DIR="$TEST_DIR/fake-bin"

  mkdir -p "$REPO_DIR" "$HOME_DIR" "$FAKE_BIN_DIR"

  create_repo_fixture
}

teardown_test_environment() {
  rm -rf "$TEST_DIR"
}

create_repo_fixture() {
  mkdir -p "$REPO_DIR/scripts/dotfiler" "$REPO_DIR/configs"
  cp "$SCRIPT_UNDER_TEST" "$REPO_DIR/scripts/dotfiler/dotfiler.sh"
  chmod +x "$REPO_DIR/scripts/dotfiler/dotfiler.sh"
  cp -R "$TEST_ASSETS_DIR/support/configs/." "$REPO_DIR/configs/"

  (
    cd "$REPO_DIR"
    git init -q
  )
}

install_fixture() {
  local fixture_name="$1"
  local fixture_dir="$TEST_ASSETS_DIR/fixtures/$fixture_name"

  cp "$fixture_dir/symlinks.yml" "$REPO_DIR/symlinks.yml"

  if [ -d "$fixture_dir/configs" ]; then
    cp -R "$fixture_dir/configs/." "$REPO_DIR/configs/"
  fi

  if [ -d "$fixture_dir/fake-bin" ]; then
    cp -R "$fixture_dir/fake-bin/." "$FAKE_BIN_DIR/"
    chmod +x "$FAKE_BIN_DIR"/*
  fi
}

run_dotfiler() {
  local debug_value="$1"
  shift
  local extra_args="$*"

  run bash -lc "cd '$REPO_DIR/scripts/dotfiler' && HOME='$HOME_DIR' USER='test-user' DEBUG='$debug_value' PATH='$FAKE_BIN_DIR:$PATH' bash ./dotfiler.sh $extra_args"
}

assert_symlink_points_to() {
  local symlink_path="$1"
  local expected_target="$2"

  [ -L "$symlink_path" ]

  local actual_target
  actual_target="$(readlink "$symlink_path")"
  actual_target="$(realpath "$actual_target")"
  expected_target="$(realpath "$expected_target")"

  [ "$actual_target" = "$expected_target" ]
}

assert_path_missing() {
  local path_to_check="$1"

  [ ! -e "$path_to_check" ]
  [ ! -L "$path_to_check" ]
}

assert_no_double_separator() {
  local output_text="$1"
  local separator_line="────────────────────────────────────────────────────────"
  local duplicated_separator=$separator_line$'\n'$separator_line

  [[ "$output_text" != *"$duplicated_separator"* ]]
}

assert_output_contains_line() {
  local output_text="$1"
  local expected_line="$2"

  [[ "$output_text" == *"$expected_line"* ]]
}
