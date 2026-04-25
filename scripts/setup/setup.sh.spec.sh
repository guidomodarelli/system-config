#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup.sh
source "$SCRIPT_DIR/setup.sh"

assert_equals() {
  local expected=$1 actual=$2 message=$3

  if [[ "$expected" != "$actual" ]]; then
    printf "ERROR: %s Expected '%s', got '%s'.\n" "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_success() {
  local message=$1
  shift

  if ! "$@"; then
    printf "ERROR: %s\n" "$message" >&2
    exit 1
  fi
}

assert_failure() {
  local message=$1
  shift

  if "$@"; then
    printf "ERROR: %s\n" "$message" >&2
    exit 1
  fi
}

_initialize_menu_catalog
_validate_menu_catalog

assert_equals "build-essential" "${_MENU_LABELS[0]}" "Bash catalog should be loaded from the bash setup catalog."
assert_equals "install_build_essential" "${_MENU_FUNCS[0]}" "Bash catalog should load function names from the bash setup catalog."
assert_equals "1" "${_MENU_DEFAULT_SELECTED[0]}" "Bash catalog should load default selection state from the bash setup catalog."

original_setup_catalog_path="$SETUP_CATALOG_PATH"
SETUP_CATALOG_PATH="$SCRIPT_DIR/missing-setup.catalog.csv"
assert_failure "Bash catalog initialization should fail when the catalog file is missing." _initialize_menu_catalog
SETUP_CATALOG_PATH="$original_setup_catalog_path"
_initialize_menu_catalog
_validate_menu_catalog

git_function_index="$(_find_menu_function_index install_git)"
assert_equals "26" "$git_function_index" "Catalog allowlist should find setup installer functions."
assert_failure "Catalog allowlist should reject functions outside setup installers." _find_menu_function_index rm

same_window_render_result=0
if _menu_requires_full_render 0 0 5 5 0; then
  same_window_render_result=1
fi
assert_equals "0" "$same_window_render_result" "Navigation inside the same window should allow partial row repaint."

window_change_render_result=0
if _menu_requires_full_render 0 1 5 5 0; then
  window_change_render_result=1
fi
assert_equals "1" "$window_change_render_result" "Navigation that changes the visible window should require a full render."

resize_render_result=0
if _menu_requires_full_render 0 0 5 6 0; then
  resize_render_result=1
fi
assert_equals "1" "$resize_render_result" "Changing the visible height should require a full render."

force_render_result=0
if _menu_requires_full_render 0 0 5 5 1; then
  force_render_result=1
fi
assert_equals "1" "$force_render_result" "Bulk updates and search returns should force a full render."

first_visible_offset="$(_menu_item_row_offset 10 10)"
assert_equals "2" "$first_visible_offset" "First visible menu item should render after range and top indicator."

printf "setup.sh catalog and menu tests passed.\n"
