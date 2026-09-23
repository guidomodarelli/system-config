#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup.sh
source "$SCRIPT_DIR/setup.sh"

_TEST_PLATFORM="linux"
_TEST_IS_UBUNTU=1

is_windows() {
  [[ "$_TEST_PLATFORM" == "wsl" ]]
}

is_ubuntu() {
  [[ "$_TEST_IS_UBUNTU" == "1" && ( "$_TEST_PLATFORM" == "linux" || "$_TEST_PLATFORM" == "wsl" ) ]]
}

is_debian_like() {
  [[ "$_TEST_PLATFORM" == "linux" || "$_TEST_PLATFORM" == "wsl" ]]
}

is_darwin() {
  [[ "$_TEST_PLATFORM" == "darwin" ]]
}

set_test_platform() {
  _TEST_PLATFORM=$1
  _TEST_IS_UBUNTU=1
}

set_test_debian_non_ubuntu() {
  _TEST_PLATFORM="linux"
  _TEST_IS_UBUNTU=0
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

assert_not_contains() {
  local haystack=$1 needle=$2 message=$3

  if [[ "$haystack" == *"$needle"* ]]; then
    printf "ERROR: %s Expected output not to contain '%s'.\n" "$message" "$needle" >&2
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

assert_less_than() {
  local actual=$1
  local expected_upper_bound=$2
  local message=$3

  if [[ "$actual" -ge "$expected_upper_bound" ]]; then
    printf "ERROR: %s Expected '%s' to be less than '%s'.\n" "$message" "$actual" "$expected_upper_bound" >&2
    exit 1
  fi
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

assert_equals "$SCRIPT_DIR/setup.catalog.csv" "$SETUP_CATALOG_PATH" "Bash setup should load the shared setup catalog."
assert_equals "latest-stable-official" "$SETUP_LATEST_VERSION_POLICY" "Bash setup should make the latest stable policy explicit."
assert_equals "build-essential" "${_MENU_LABELS[0]}" "Bash catalog should be loaded from the shared setup catalog."
assert_equals "install_build_essential" "${_MENU_FUNCS[0]}" "Bash catalog should load Bash function names from the shared setup catalog."
assert_equals "1" "${_MENU_DEFAULT_SELECTED[0]}" "Bash catalog should load default selection state from the shared setup catalog."
assert_equals "1" "${_MENU_REQUIRES_ADMIN[0]}" "Bash catalog should load admin metadata from the shared setup catalog."
assert_equals "linux,wsl" "${_MENU_PLATFORMS[0]}" "Bash catalog should load platform metadata from the shared setup catalog."
assert_equals "0" "${_MENU_REQUIRES_RESTART[0]}" "Bash catalog should load restart metadata from the shared setup catalog."
assert_not_contains "$(cat "$SCRIPT_DIR/setup.sh")" "setup.bash.catalog.csv" "Bash setup should not reference the old Bash-only catalog."

original_setup_catalog_path="$SETUP_CATALOG_PATH"
SETUP_CATALOG_PATH="$SCRIPT_DIR/missing-setup.catalog.csv"
assert_failure "Bash catalog initialization should fail when the catalog file is missing." _initialize_menu_catalog
SETUP_CATALOG_PATH="$original_setup_catalog_path"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "Linux setup menu should keep defaults first after catalog reload."

invalid_header_catalog="$(mktemp)"
printf "Id|Label|FunctionName\nfoo|Foo|install_git\n" > "$invalid_header_catalog"
SETUP_CATALOG_PATH="$invalid_header_catalog"
assert_failure "Bash catalog initialization should reject a non-shared header." _initialize_menu_catalog
rm -f "$invalid_header_catalog"
SETUP_CATALOG_PATH="$original_setup_catalog_path"
_initialize_menu_catalog
_validate_menu_catalog

_MENU_PLATFORMS[0]="linux,plan9"
assert_failure "Bash catalog validation should reject unsupported platform tokens." _validate_menu_catalog
_initialize_menu_catalog
_validate_menu_catalog

_MENU_FUNCS[0]="missing_setup_function"
assert_failure "Bash catalog validation should reject missing Bash functions." _validate_menu_catalog
_initialize_menu_catalog
_validate_menu_catalog

assert_equals "1" "$(get_menu_default_selection_by_id xclip)" "Linux setup recommendations should include xclip."
assert_equals "1" "$(get_menu_requires_admin_by_id xclip)" "Linux setup metadata should mark xclip as requiring sudo."
assert_equals "1" "$(get_menu_requires_admin_by_id git)" "Linux setup metadata should keep Git apt installs under sudo."
assert_equals "0" "$(get_menu_default_selection_by_id vscode)" "Linux setup recommendations should preserve VS Code as opt-in."
assert_equals "1" "$(get_menu_requires_admin_by_id vscode)" "Linux setup metadata should keep VS Code installs under sudo."
assert_failure "Linux setup catalog should hide macOS-only GNU grep." get_menu_default_selection_by_id gnu_grep
assert_failure "Linux setup catalog should hide WSL-only win32yank." get_menu_default_selection_by_id win32yank
assert_failure "Linux setup catalog should hide Windows-only bat." get_menu_default_selection_by_id bat
assert_equals "1" "$(get_menu_default_selection_by_id espanso)" "Linux setup recommendations should include Espanso."
assert_equals "1" "$(get_menu_default_selection_by_id hunk)" "Las recomendaciones de setup para Linux deben incluir hunk."
assert_equals "1" "$(get_menu_default_selection_by_id mcp_remote_proxy)" "Linux setup recommendations should include mcp-remote-proxy."
assert_equals "1" "$(get_menu_default_selection_by_id bash)" "Las recomendaciones de setup para Linux deben incluir Bash."
assert_less_than "$(_find_menu_item_index bash)" "$(_find_menu_item_index sdkman)" "El setup debe instalar Bash antes que SDKMAN."
assert_failure "Bash catalog should not include wget as a recommended setup item." get_menu_default_selection_by_id wget
assert_failure "Bash catalog should not include Java JDK 21 as a recommended setup item." get_menu_default_selection_by_id java_jdk

(
  set_test_debian_non_ubuntu
  _initialize_menu_catalog
  _validate_menu_catalog
  assert_equals "1" "$(get_menu_default_selection_by_id xclip)" "Debian setup recommendations should include Debian-compatible apt packages."

  sudo() { printf "%s\n" "$*"; }
  apt_install_output="$(
    install_build_essential
    install_git
    install_xclip
  )"
  assert_contains "$apt_install_output" "apt-get install -y build-essential" "Debian setup should install build-essential through apt."
  assert_contains "$apt_install_output" "apt-get install -y git" "Debian setup should install Git through apt."
  assert_contains "$apt_install_output" "apt-get install -y xclip" "Debian setup should install xclip through apt."
)

(
  set_test_debian_non_ubuntu
  PATH="/usr/bin:/bin"
  _setup_default_linuxbrew_path() { printf "%s" "/bin/echo"; }
  brew_output="$(_brew install jq)"
  assert_contains "$brew_output" "install jq" "Debian setup should find Linuxbrew through the standard Homebrew path when PATH is not refreshed."
)

(
  set_test_platform "darwin"
  _brew() { printf "%s\n" "$*"; }
  gh_install_output="$(install_gh)"
  assert_contains "$gh_install_output" "install gh" "macOS setup should install GitHub CLI through Homebrew."
  ghostty_install_output="$(install_ghostty)"
  assert_contains "$ghostty_install_output" "install --cask ghostty" "macOS setup should install Ghostty through Homebrew Cask."
  hunk_install_output="$(install_hunk)"
  assert_contains "$hunk_install_output" "install modem-dev/tap/hunk" "El setup de macOS debe instalar hunk desde el tap de Homebrew."
  bash_install_output="$(install_bash)"
  assert_contains "$bash_install_output" "install bash" "El setup debe instalar Bash vía Homebrew."
  python3() { printf "%s\n" "$*"; }
  mcp_remote_proxy_install_output="$(install_mcp_remote_proxy)"
  assert_contains "$mcp_remote_proxy_install_output" "-m pip install --user --upgrade --index-url https://pypi.artifacts.furycloud.io/simple/ mcp-remote-proxy" "El setup debe instalar mcp-remote-proxy como herramienta Python de usuario."
)

set_test_platform "wsl"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "WSL setup menu should keep defaults first."
assert_equals "1" "$(get_menu_default_selection_by_id win32yank)" "WSL setup recommendations should include win32yank."
assert_failure "WSL setup catalog should hide Espanso." get_menu_default_selection_by_id espanso
assert_failure "WSL setup catalog should hide Ghostty." get_menu_default_selection_by_id ghostty
assert_failure "WSL setup catalog should hide Linux-only xclip." get_menu_default_selection_by_id xclip

set_test_platform "darwin"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "macOS setup menu should keep defaults first."
assert_equals "1" "$(get_menu_default_selection_by_id gnu_grep)" "macOS setup recommendations should include GNU grep."
assert_failure "macOS setup catalog should hide Linux-only xclip." get_menu_default_selection_by_id xclip
assert_failure "macOS setup catalog should hide WSL-only win32yank." get_menu_default_selection_by_id win32yank
assert_equals "1" "$(get_menu_default_selection_by_id espanso)" "macOS setup recommendations should include Espanso."
assert_equals "1" "$(get_menu_default_selection_by_id gh)" "macOS setup recommendations should include GitHub CLI."
assert_equals "1" "$(get_menu_default_selection_by_id ghostty)" "macOS setup recommendations should include Ghostty."
assert_equals "1" "$(get_menu_default_selection_by_id hunk)" "Las recomendaciones de setup para macOS deben incluir hunk."
assert_equals "1" "$(get_menu_default_selection_by_id mcp_remote_proxy)" "Las recomendaciones de setup para macOS deben incluir mcp-remote-proxy."
assert_equals "1" "$(get_menu_default_selection_by_id bash)" "Las recomendaciones de setup para macOS deben incluir Bash."
assert_less_than "$(_find_menu_item_index bash)" "$(_find_menu_item_index sdkman)" "El setup de macOS debe instalar Bash antes que SDKMAN."

set_test_platform "linux"
_initialize_menu_catalog
_validate_menu_catalog
assert_menu_defaults_are_first "Linux setup menu should keep defaults first before allowlist checks."
assert_equals "1" "$(get_menu_default_selection_by_id ghostty)" "Linux setup recommendations should include Ghostty."

assert_success "Catalog allowlist should find setup installer functions." _find_menu_function_index install_git >/dev/null
assert_success "Catalog allowlist should include GitHub CLI installer functions." _find_menu_function_index install_gh >/dev/null
missed_lookup_output="$(_find_menu_function_index rm 2>/dev/null || true)"
assert_equals "-1" "$missed_lookup_output" "Catalog miss should echo '-1' so callers using \$(...) never receive an empty string interpreted as index 0."
assert_failure "Catalog allowlist should reject functions outside setup installers." _find_menu_function_index rm >/dev/null
assert_equals "$(_find_menu_function_index install_git)" "$(_find_menu_item_index git)" "Catalog item lookup should accept setup ids."
assert_equals "$(_find_menu_function_index install_gh)" "$(_find_menu_item_index gh)" "Catalog item lookup should accept the GitHub CLI setup id."

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

assert_equals "v9.9.9" "$(curl() { printf "https://github.com/example/tool/releases/tag/v9.9.9"; }; _setup_resolve_github_latest_tag example tool)" "GitHub latest resolver should read the latest stable redirect tag."

(
  mktemp() {
    if [[ "$#" -eq 1 && "$1" == "-d" ]]; then
      return 1
    fi
    if [[ "$#" -eq 3 && "$1" == "-d" && "$2" == "-t" ]]; then
      local fallback_temp_dir="${TMPDIR:-/tmp}/${3}.fallback.$$"
      mkdir -p "$fallback_temp_dir"
      printf "%s" "$fallback_temp_dir"
      return 0
    fi
    return 1
  }
  fallback_temp_dir="$(_setup_create_temp_dir)"
  if [[ ! -d "$fallback_temp_dir" ]]; then
    printf "ERROR: Temporary directory helper should fall back to BSD mktemp syntax.\n" >&2
    exit 1
  fi
  rm -rf "$fallback_temp_dir"
)

(
  _setup_resolve_latest_go_version() { printf "1.2.3"; }
  _setup_installed_go_version() { printf "1.2.3"; }
  install_output="$(install_golang)"
  assert_contains "$install_output" "Go ya está en la última versión estable oficial" "Go installer should skip when local version is already latest."
)

(
  temporary_directory="$(mktemp -d)"
  mocked_installed_go_version="1.2.2"
  _setup_resolve_latest_go_version() { printf "1.2.3"; }
  _setup_installed_go_version() { printf "%s" "$mocked_installed_go_version"; }
  _setup_resolve_go_platform() { printf "linux-amd64"; }
  _setup_resolve_go_release_sha256() { printf "deadbeef"; }
  _setup_compute_sha256() { printf "deadbeef"; }
  _setup_create_temp_dir() { printf "%s" "$temporary_directory"; }
  _setup_remove_temp_dir() { rm -rf "$1"; }
  curl() {
    local target=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -o|-fsSLo) target="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -n "$target" ]] && printf "archive" > "$target"
  }
  sudo() { mocked_installed_go_version="1.2.3"; return 0; }
  install_golang >/dev/null
  if [[ -d "$temporary_directory" ]]; then
    printf "ERROR: Go installer should remove temporary downloads after updating.\n" >&2
    exit 1
  fi
)

(
  _setup_resolve_github_latest_tag() { printf "v1.2.3"; }
  _setup_installed_nvm_version() { printf "1.2.3"; }
  install_output="$(install_nvm)"
  assert_contains "$install_output" "NVM ya está en la última versión estable oficial" "NVM installer should skip when local version is already latest."
)

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
assert_equals "4" "$first_visible_offset" "First visible menu item should render after range, legend, spacer, and top indicator."

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
assert_equals "QUIT" "$(printf '\003' | _read_key)" "Ctrl+C should cancel the menu when the terminal delivers it as a character."
assert_equals "QUIT" "$(printf '\004' | _read_key)" "Ctrl+D should cancel the menu."
assert_equals "QUIT" "$(printf '\004' | _read_search_key)" "Ctrl+D should cancel the search."
assert_equals "OTHER" "$(printf 'A' | _read_key)" "Detached arrow fragments should not trigger the select all shortcut."
assert_equals "OTHER" "$(printf '[B' | _read_search_key)" "Detached arrow fragments should be ignored in search input."
assert_equals "TEXT:g" "$(printf 'g' | _read_search_key)" "Search input should keep regular text characters."
assert_equals "TEXT:q" "$(printf 'q' | _read_search_key)" "Search input should allow filtering package names that contain q."

export TERM=xterm-256color
_MENU_LABELS=("Git" "PowerToys")
_MENU_DEFAULT_SELECTED=(1 0)
_MENU_SELECTED=(1 0)
_MENU_REQUIRES_ADMIN=(0 0)
_MENU_REQUIRES_RESTART=(0 0)

selected_row="$(_draw_menu_item 0 1 "${_MENU_LABELS[0]}" 1)"
assert_contains "$selected_row" "$(styleText -c green -- "✅")" "Selected marker should use styleText success green."
assert_contains "$selected_row" "$(styleText -c gray -- "★")" "Default marker should be a discreet gray star."
selected_row_text="$(printf "%s" "$selected_row" | strip_ansi)"
assert_equals "     [✅]  ★ Git" "$selected_row_text" "Default selected row should keep the visible menu text."

cursor_row="$(_draw_menu_item 1 1 "${_MENU_LABELS[1]}" 0)"
assert_contains "$cursor_row" "$(styleText -c cyan -b -- "PowerToys")" "Cursor row should highlight the label in bold cyan."
assert_contains "$cursor_row" "$SETUP_MENU_CURSOR_BACKGROUND" "Cursor row should paint the whole row background."
cursor_row_text="$(printf "%s" "$cursor_row" | strip_ansi)"
assert_equals "  👉 [  ]    PowerToys" "$(printf "%s" "$cursor_row_text" | sed -E 's/ +$//')" "Cursor row should align unselected and non-recommended rows with emoji markers."
cursor_row_columns="$(printf "%s" "$cursor_row_text" | wc -m | tr -d ' ')"
assert_equals "$((SETUP_MENU_HIGHLIGHT_WIDTH + 2 - 1))" "$cursor_row_columns" "Highlighted row should be padded to the fixed width (the pointer emoji counts as one character)."

selected_cursor_row="$(_draw_menu_item 0 0 "${_MENU_LABELS[0]}" 1)"
selected_cursor_expected_segment="]  $(styleText -c gray -- "★")$SETUP_MENU_CURSOR_BACKGROUND "
assert_contains "$selected_cursor_row" "$selected_cursor_expected_segment" "Cursor row should re-apply the background after each colored marker."
selected_cursor_row_text="$(printf "%s" "$selected_cursor_row" | strip_ansi)"
assert_equals "  👉 [✅]  ★ Git" "$(printf "%s" "$selected_cursor_row_text" | sed -E 's/ +$//')" "Selected cursor row should keep the visible menu text."
assert_contains "$(_draw_menu_item 0 1 "Git" 1 "┃" | strip_ansi)" "┃    [✅]" "Rows should start with the given scrollbar glyph."

_MENU_LABELS=(a b c d e f g h i j)
_MENU_SELECTED=(0 0 0 0 0 0 0 0 0 0)
assert_equals " " "$(_menu_scrollbar_glyph 0 0 10 10)" "Scrollbar should be hidden when the list fits."
assert_equals "┃" "$(_menu_scrollbar_glyph 0 0 5 10 | strip_ansi)" "Scrollbar thumb should start at the top for the first window."
assert_equals "│" "$(_menu_scrollbar_glyph 4 0 5 10 | strip_ansi)" "Scrollbar track should fill the rest for the first window."
assert_equals "┃" "$(_menu_scrollbar_glyph 4 5 5 10 | strip_ansi)" "Scrollbar thumb should reach the bottom for the last window."
assert_equals "│" "$(_menu_scrollbar_glyph 0 5 5 10 | strip_ansi)" "Scrollbar track should be above the thumb for the last window."
assert_equals "30" "$(_setup_tty_size() { printf "30 120\n"; }; _setup_terminal_rows)" "Terminal rows should come from stty size of the controlling tty."
assert_equals "42" "$(_setup_tty_size() { :; }; tput() { :; }; LINES=42 _setup_terminal_rows)" "Terminal rows should fall back to LINES without a tty."
assert_equals "10" "$(_setup_terminal_rows() { echo 30; }; _menu_visible_height)" "Visible height should be capped by the number of items."
_MENU_LABELS=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
assert_equals "21" "$(_setup_terminal_rows() { echo 40; }; _menu_visible_height)" "Visible height should fill the viewport minus the reserved lines."
assert_equals "5" "$(_setup_terminal_rows() { echo 10; }; _menu_visible_height)" "Visible height should keep a minimum on tiny terminals."
_MENU_LABELS=("Git" "PowerToys")

range_window="$(_draw_menu_window 0 0 1 2)"
assert_contains "$range_window" "$(styleText -c cyan -- "1")" "First visible item number should use styleText info cyan."
assert_contains "$range_window" "$(styleText -c cyan -- "2")" "Total item count should use styleText info cyan."
assert_contains "$range_window" "$(styleText -c gray -- "★")" "Default marker legend should use the discreet gray star."
assert_contains "$(printf "%s" "$range_window" | strip_ansi)" "seleccionados" "Menu header should show the selected item count."
assert_contains "$(printf "%s" "$range_window" | strip_ansi)" "🔐 requiere sudo" "Menu legend should explain the sudo badge."

reference_output="$(_draw_menu_reference)"
assert_contains "$(printf "%s" "$reference_output" | strip_ansi)" "╭─ 🧭 Atajos ─" "Reference shortcuts should render inside a titled box."
assert_equals "6" "$(printf "%s\n" "$reference_output" | wc -l | tr -d ' ')" "Two-column reference should use 6 lines (the trailing spacer is trimmed by command substitution)."
padded_navigation_shortcut="$(printf "%-18s" "Arriba/Abajo/j/k")"
assert_contains "$reference_output" "$(styleText -c cyan -- "$padded_navigation_shortcut")" "Reference shortcuts should use styleText info cyan."

log_output="$(_setup_log_info "Shared styleText log")"
assert_contains "$log_output" "$(styleText -c blue -b -- "🔹")" "Setup info logs should use the shared styleText helper with the info icon."
assert_contains "$(_setup_log_warning "Cuidado" | strip_ansi)" "🚨 Aviso: Cuidado" "Setup warnings should use the warning icon and label."
assert_contains "$(_setup_log_error "Roto" | strip_ansi)" "❌ Error: Roto" "Setup errors should use the error icon and label."

_MENU_LABELS=("Zsh" "Espanso")
_MENU_DEFAULT_SELECTED=(1 0)
_MENU_REQUIRES_ADMIN=(1 0)
_MENU_REQUIRES_RESTART=(0 1)
assert_equals "★ Zsh 🔐" "$(_menu_display_label 0)" "Recommended admin items should show the star and sudo badge."
assert_equals "  Espanso 🔁" "$(_menu_display_label 1)" "Optional restart items should align with recommended labels and show the restart badge."

assert_equals "45s" "$(_setup_format_duration 45)" "Short durations should be shown in seconds."
assert_equals "2m 05s" "$(_setup_format_duration 125)" "Long durations should be shown in minutes and seconds."

bash32_timeout="$(_setup_read_timeout 0.05 3)"
assert_equals "1" "$bash32_timeout" "Bash 3.2 should fall back to an integer read timeout."
assert_equals "$( ((BASH_VERSINFO[0] >= 4)) && echo 0.05 || echo 1)" "$(_setup_read_timeout 0.05)" "Current bash should use a timeout it supports."
assert_equals "0.05" "$(_setup_read_timeout 0.05 5)" "Bash 4+ should keep fractional read timeouts."

setup_fake_success() { printf "salida real del instalador\n"; }
setup_fake_failure() { return 1; }
_MENU_LABELS=("Fake OK" "Fake Fail" "Fake Restart" "Fake Skip")
_MENU_FUNCS=(setup_fake_success setup_fake_failure setup_fake_success setup_fake_success)
_MENU_SELECTED=(1 1 1 1)
_MENU_PLATFORMS=(all all all plan9)
_MENU_REQUIRES_RESTART=(0 0 1 0)
_MENU_REQUIRES_ADMIN=(0 0 0 0)
_MENU_DEFAULT_SELECTED=(1 1 1 1)
run_output="$(_run_selected_menu_items 0 2>&1 | strip_ansi)"
_run_selected_menu_items 0 >/dev/null 2>&1
summary_output="$(_print_install_summary | strip_ansi)"
assert_contains "$run_output" "╭─ 📦 [1/4] Fake OK" "Each install should open a numbered frame."
assert_contains "$run_output" "salida real del instalador" "Installer output should stay visible inside the frame."
assert_contains "$run_output" "╰─ ✅ Fake OK listo" "Successful installs should close the frame with success."
assert_contains "$run_output" "╰─ ❌ Fake Fail falló" "Failed installs should close the frame with failure."
assert_contains "$run_output" "╰─ ⏩ [4/4] Fake Skip omitido por plataforma" "Unsupported items should be reported as skipped."
assert_contains "$summary_output" "╭─ 📊 Resumen" "Summary should render inside a titled box."
assert_contains "$summary_output" "✅ 2 ok · ❌ 1 fallaron · ⏩ 1 omitidos" "Summary footer should count results."
assert_contains "$summary_output" "🔁 Algunos cambios requieren reiniciar" "Summary should warn about required restarts."
assert_contains "$summary_output" "💥 Proceso con 1 error(es)." "Summary should close with the failure status."
assert_success "Install results should report failures." _setup_install_results_include_failure

_MENU_SELECTED=(1 0 0 0)
dry_run_output="$(_run_selected_menu_items 1 | strip_ansi)"
_run_selected_menu_items 1 >/dev/null
dry_run_summary="$(_print_install_summary | strip_ansi)"
assert_contains "$dry_run_output" "│ [1/1] se ejecutaría Fake OK" "Dry-run should list items inside the simulation box."
assert_contains "$dry_run_summary" "🧪 1 en simulación · no se instaló nada" "Dry-run summary should only report the simulation footer."
assert_not_contains "$dry_run_summary" "│ 🧪 Fake OK" "Dry-run summary should not repeat the item list."

set_test_platform darwin
_initialize_menu_catalog
list_output="$(_list_setup_catalog)"
assert_contains "$list_output" "$(printf 'jq\tinstall_jq\tjq')" "Piped --list output should keep the tab-separated format."
assert_not_contains "$list_output" "╭─" "Piped --list output should not include boxes."

_MENU_LABELS=("Git" "GitHub CLI" "PowerToys" "ripgrep")
_filter_menu_indexes "GIT" 4
assert_equals "0 1" "${_FILTERED_MENU_INDEXES[*]}" "Search should match labels case-insensitively."
_MENU_LABELS=("Zoxide" "Git")
_filter_menu_indexes "zo" 2
assert_equals "0" "${_FILTERED_MENU_INDEXES[*]}" "Search should refresh the lowercase cache when labels change."
_filter_menu_indexes "" 2
assert_equals "0 1" "${_FILTERED_MENU_INDEXES[*]}" "Empty search should list every item."

_MENU_LABELS=("Git" "GitHub CLI" "PowerToys")
_MENU_SELECTED=(1 0 0)
_MENU_DEFAULT_SELECTED=(1 1 0)
_MENU_REQUIRES_ADMIN=(0 0 0)
_MENU_REQUIRES_RESTART=(0 0 0)
_filter_menu_indexes "hub" 3
search_screen="$(_draw_search_window "hub" 0 5)"
search_screen_text="$(printf "%s" "$search_screen" | strip_ansi)"
assert_contains "$search_screen_text" "╭─ 🔎 Buscar paquetes" "Search should render the input inside a titled box."
assert_contains "$search_screen_text" "❯ hub▏" "Search input should show the prompt, query and cursor."
assert_contains "$search_screen_text" "1 de 3" "Search input should show the match counter."
assert_contains "$search_screen_text" "ESPACIO alternar" "Search should show hints on one line."
assert_contains "$search_screen" "$(styleText -c yellow -b -u -- "Hub")" "Search results should highlight the matching part with the original casing."
assert_equals "" "${_SETUP_MENU_HIGHLIGHT_QUERY:-}" "Search highlight should not leak into the main menu."
_filter_menu_indexes "" 3
assert_contains "$(_draw_search_window "" 0 5 | strip_ansi)" "escribí para filtrar…" "Empty search should show a placeholder."
_filter_menu_indexes "zzz" 3
assert_contains "$(_draw_search_window "zzz" 0 5 | strip_ansi)" "🤷 Sin coincidencias para «zzz»" "Search without results should show a friendly empty state."

printf "setup.sh catalog and menu tests passed.\n"
