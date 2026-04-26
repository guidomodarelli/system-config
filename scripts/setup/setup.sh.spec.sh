#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup.sh
source "$SCRIPT_DIR/setup.sh"

_TEST_PLATFORM="linux"

is_windows() {
  [[ "$_TEST_PLATFORM" == "wsl" ]]
}

is_ubuntu() {
  [[ "$_TEST_PLATFORM" == "linux" || "$_TEST_PLATFORM" == "wsl" ]]
}

is_darwin() {
  [[ "$_TEST_PLATFORM" == "darwin" ]]
}

set_test_platform() {
  _TEST_PLATFORM=$1
}

assert_equals() {
  local expected=$1 actual=$2 message=$3

  if [[ "$expected" != "$actual" ]]; then
    printf "ERROR: %s Expected '%s', got '%s'.\n" "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack=$1 needle=$2 message=$3

  if [[ "$haystack" != *"$needle"* ]]; then
    printf "ERROR: %s Expected output to contain '%s'.\n" "$message" "$needle" >&2
    exit 1
  fi
}

strip_ansi() {
  sed -E $'s/\x1b\\[[0-9;]*m//g'
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

get_menu_default_selection_by_id() {
  local requested_id=$1
  local menu_index

  for menu_index in "${!_MENU_IDS[@]}"; do
    if [[ "${_MENU_IDS[$menu_index]}" == "$requested_id" ]]; then
      echo "${_MENU_DEFAULT_SELECTED[$menu_index]}"
      return 0
    fi
  done

  return 1
}

get_menu_requires_admin_by_id() {
  local requested_id=$1
  local menu_index

  for menu_index in "${!_MENU_IDS[@]}"; do
    if [[ "${_MENU_IDS[$menu_index]}" == "$requested_id" ]]; then
      echo "${_MENU_REQUIRES_ADMIN[$menu_index]}"
      return 0
    fi
  done

  return 1
}

assert_menu_defaults_are_first() {
  local found_non_default=0
  local menu_index

  for menu_index in "${!_MENU_DEFAULT_SELECTED[@]}"; do
    if [[ "${_MENU_DEFAULT_SELECTED[$menu_index]}" -eq 0 ]]; then
      found_non_default=1
    elif [[ "$found_non_default" -eq 1 ]]; then
      printf "ERROR: %s Expected all default setup items before optional items.\n" "$1" >&2
      exit 1
    fi
  done
}

set_test_platform "linux"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "Linux setup menu should keep defaults first."

assert_equals "$REPO_ROOT/configs/zsh/.zsh/functions/styleText.zsh" "$SETUP_STYLE_TEXT_PATH" "Bash setup should load the shared styleText helper."
if ! command -v styleText >/dev/null; then
  printf "ERROR: Shared styleText helper should be available.\n" >&2
  exit 1
fi

assert_equals "build-essential" "${_MENU_LABELS[0]}" "Bash catalog should be loaded from the bash setup catalog."
assert_equals "install_build_essential" "${_MENU_FUNCS[0]}" "Bash catalog should load function names from the bash setup catalog."
assert_equals "1" "${_MENU_DEFAULT_SELECTED[0]}" "Bash catalog should load default selection state from the bash setup catalog."
assert_equals "1" "${_MENU_REQUIRES_ADMIN[0]}" "Bash catalog should load admin metadata from the bash setup catalog."
assert_equals "linux,wsl" "${_MENU_PLATFORMS[0]}" "Bash catalog should load platform metadata from the bash setup catalog."
assert_equals "0" "${_MENU_REQUIRES_RESTART[0]}" "Bash catalog should load restart metadata from the bash setup catalog."

original_setup_catalog_path="$SETUP_CATALOG_PATH"
SETUP_CATALOG_PATH="$SCRIPT_DIR/missing-setup.catalog.csv"
assert_failure "Bash catalog initialization should fail when the catalog file is missing." _initialize_menu_catalog
SETUP_CATALOG_PATH="$original_setup_catalog_path"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "Linux setup menu should keep defaults first after catalog reload."

assert_equals "1" "$(get_menu_default_selection_by_id xclip)" "Linux setup recommendations should include xclip."
assert_equals "1" "$(get_menu_requires_admin_by_id xclip)" "Linux setup metadata should mark xclip as requiring sudo."
assert_equals "0" "$(get_menu_default_selection_by_id gnu_grep)" "Linux setup recommendations should not include GNU grep."
assert_equals "0" "$(get_menu_default_selection_by_id win32yank)" "Linux setup recommendations should not include win32yank."
assert_equals "1" "$(get_menu_default_selection_by_id espanso)" "Linux setup recommendations should include Espanso."
assert_failure "Bash catalog should not include wget as a recommended setup item." get_menu_default_selection_by_id wget
assert_failure "Bash catalog should not include Java JDK 21 as a recommended setup item." get_menu_default_selection_by_id java_jdk

set_test_platform "wsl"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "WSL setup menu should keep defaults first."
assert_equals "1" "$(get_menu_default_selection_by_id win32yank)" "WSL setup recommendations should include win32yank."
assert_equals "0" "$(get_menu_default_selection_by_id espanso)" "WSL setup recommendations should not include Espanso."
assert_equals "0" "$(get_menu_default_selection_by_id xclip)" "WSL setup recommendations should not include xclip."

set_test_platform "darwin"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "macOS setup menu should keep defaults first."
assert_equals "1" "$(get_menu_default_selection_by_id gnu_grep)" "macOS setup recommendations should include GNU grep."
assert_equals "0" "$(get_menu_default_selection_by_id xclip)" "macOS setup recommendations should not include xclip."
assert_equals "0" "$(get_menu_default_selection_by_id win32yank)" "macOS setup recommendations should not include win32yank."
assert_equals "1" "$(get_menu_default_selection_by_id espanso)" "macOS setup recommendations should include Espanso."

set_test_platform "linux"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "Linux setup menu should keep defaults first before allowlist checks."

assert_success "Catalog allowlist should find setup installer functions." _find_menu_function_index install_git >/dev/null
assert_failure "Catalog allowlist should reject functions outside setup installers." _find_menu_function_index rm
assert_equals "$(_find_menu_function_index install_git)" "$(_find_menu_item_index git)" "Catalog item lookup should accept setup ids."

_parse_setup_arguments install_git --dry-run fd_find --yes
assert_equals "1" "$SETUP_DRY_RUN" "Bash CLI parsing should accept dry-run after commands."
assert_equals "1" "$SETUP_ASSUME_YES" "Bash CLI parsing should accept yes after commands."
assert_equals "install_git fd_find" "${SETUP_COMMAND_ARGUMENTS[*]}" "Bash CLI parsing should preserve command arguments."

_MENU_SELECTED=()
for menu_index in "${!_MENU_FUNCS[@]}"; do
  _MENU_SELECTED[$menu_index]=0
done
_MENU_SELECTED[$(_find_menu_item_index git)]=1
assert_success "Bash selected metadata should detect sudo requirements." _menu_selection_requires_sudo

_MENU_SELECTED=()
for menu_index in "${!_MENU_FUNCS[@]}"; do
  _MENU_SELECTED[$menu_index]=0
done
_MENU_SELECTED[$(_find_menu_item_index nvm)]=1
assert_failure "Bash selected metadata should not require sudo for user-level installers." _menu_selection_requires_sudo

_INSTALL_RESULT_STATUSES=("ok" "falló")
assert_success "Bash setup results should detect failed installer results." _setup_install_results_include_failure

_INSTALL_RESULT_STATUSES=("ok" "dry-run" "omitido")
assert_failure "Bash setup results should not fail on successful, dry-run, or skipped results." _setup_install_results_include_failure

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
assert_equals "3" "$first_visible_offset" "First visible menu item should render after range, default marker, and top indicator."

assert_equals "UP" "$(printf '\033[A' | _read_key)" "Up arrow should be parsed as one menu key."
assert_equals "DOWN" "$(printf '\033[B' | _read_key)" "Down arrow should be parsed as one menu key."
assert_equals "PAGE_UP" "$(printf '\033[5~' | _read_key)" "Page Up should consume the full terminal sequence."
assert_equals "PAGE_DOWN" "$(printf '\033[6~' | _read_key)" "Page Down should consume the full terminal sequence."
assert_equals "HOME" "$(printf '\033[H' | _read_key)" "Home should support the short CSI terminal sequence."
assert_equals "HOME" "$(printf '\033[1~' | _read_key)" "Home should support the numbered CSI terminal sequence."
assert_equals "HOME" "$(printf '\033OH' | _read_key)" "Home should support the application cursor terminal sequence."
assert_equals "END" "$(printf '\033[F' | _read_key)" "End should support the short CSI terminal sequence."
assert_equals "END" "$(printf '\033[4~' | _read_key)" "End should support the numbered CSI terminal sequence."
assert_equals "END" "$(printf '\033OF' | _read_key)" "End should support the application cursor terminal sequence."
assert_equals "OTHER" "$(printf 'A' | _read_key)" "Detached arrow fragments should not trigger the select all shortcut."
assert_equals "OTHER" "$(printf '[B' | _read_search_key)" "Detached arrow fragments should be ignored in search input."
assert_equals "TEXT:g" "$(printf 'g' | _read_search_key)" "Search input should keep regular text characters."
assert_equals "TEXT:q" "$(printf 'q' | _read_search_key)" "Search input should allow filtering package names that contain q."

export TERM=xterm-256color
_MENU_LABELS=("Git" "PowerToys")
_MENU_DEFAULT_SELECTED=(1 0)
_MENU_SELECTED=(1 0)

selected_row="$(_draw_menu_item 0 1 "${_MENU_LABELS[0]}" 1)"
assert_contains "$selected_row" "$(styleText -c green -- "✅")" "Selected marker should use styleText success green."
assert_contains "$selected_row" "$(styleText -c yellow -- "@")" "Default marker should use styleText warning yellow."
selected_row_text="$(printf "%s" "$selected_row" | strip_ansi)"
assert_equals "    [✅] @ Git" "$selected_row_text" "Default selected row should keep the visible menu text."

cursor_row="$(_draw_menu_item 1 1 "${_MENU_LABELS[1]}" 0)"
assert_contains "$cursor_row" "$(_setup_reverse_start)" "Cursor row should use the shared reverse style modifier."
cursor_row_text="$(printf "%s" "$cursor_row" | strip_ansi)"
assert_equals " 👉 [ ] PowerToys" "$cursor_row_text" "Cursor row should keep the visible menu text."

selected_cursor_row="$(_draw_menu_item 0 0 "${_MENU_LABELS[0]}" 1)"
selected_cursor_expected_segment="$(styleText -c green -- "✅")$(_setup_reverse_start)] $(styleText -c yellow -- "@")$(_setup_reverse_start) Git"
assert_contains "$selected_cursor_row" "$selected_cursor_expected_segment" "Cursor row should restore reverse style after colored selected and default markers."
selected_cursor_row_text="$(printf "%s" "$selected_cursor_row" | strip_ansi)"
assert_equals " 👉 [✅] @ Git" "$selected_cursor_row_text" "Selected cursor row should keep the visible menu text."

range_window="$(_draw_menu_window 0 0 1 2)"
assert_contains "$range_window" "$(styleText -c cyan -- "1")" "First visible item number should use styleText info cyan."
assert_contains "$range_window" "$(styleText -c cyan -- "2")" "Total item count should use styleText info cyan."
assert_contains "$range_window" "$(styleText -c yellow -- "@")" "Default marker legend should use styleText warning yellow."

reference_output="$(_draw_menu_reference)"
assert_contains "$reference_output" "$(styleText -c magenta -- "  +--------------------+--------------------------+")" "Reference table frame should use styleText muted violet."
padded_navigation_shortcut="$(printf "%-18s" "Arriba/Abajo/j/k")"
assert_contains "$reference_output" "$(styleText -c cyan -- "$padded_navigation_shortcut")" "Reference shortcuts should use styleText info cyan."

log_output="$(_setup_log_info "Shared styleText log")"
assert_contains "$log_output" "$(logBlue "INFO")" "Setup info logs should use the shared styleText log helper."

printf "setup.sh catalog and menu tests passed.\n"
