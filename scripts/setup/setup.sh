#!/bin/bash

LOCAL_BINARIES="$HOME/.local/bin"
SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SETUP_SCRIPT_DIR" rev-parse --show-toplevel)"
SETUP_CATALOG_PATH="$SETUP_SCRIPT_DIR/setup.bash.catalog.csv"
SDKMAN_JAVA_IDENTIFIER="21.0.10-tem"
SETUP_STYLE_TEXT_PATH="$REPO_ROOT/configs/zsh/.zsh/functions/styleText.zsh"

if [[ -f "$SETUP_STYLE_TEXT_PATH" ]]; then
  # shellcheck source=../../configs/zsh/.zsh/functions/styleText.zsh
  source "$SETUP_STYLE_TEXT_PATH"
fi

if ! command -v styleText >/dev/null 2>&1; then
  styleText() {
    while [[ $# -gt 0 && "$1" == -* ]]; do
      if [[ "$1" == "--" ]]; then
        shift
        break
      fi
      shift
      [[ "${1:-}" != -* ]] && shift
    done
    printf "%s" "$*"
  }
fi

if ! command -v logInfo >/dev/null 2>&1; then
  logInfo() { printf "[ INFO ] %s\n" "$*"; }
  logSuccess() { printf "[ SUCCESS ] %s\n" "$*"; }
  logWarn() { printf "[ WARN ] %s\n" "$*"; }
  logError() { printf "[ ERROR ] %s\n" "$*"; }
fi

_setup_color() {
  local color=$1 text=$2
  styleText -c "$color" -- "$text"
}

_setup_colored_line() {
  local color=$1 text=$2
  _setup_color "$color" "$text"
  printf "\n"
}

_setup_reverse_start() {
  printf "\033[;%sm" "${REVERSE:-7}"
}

_setup_style_reset() {
  printf "\033[m"
}

_setup_color_for_menu_row() {
  local color=$1 text=$2 is_cursor=${3:-0}
  _setup_color "$color" "$text"
  if [[ $is_cursor -eq 1 ]]; then
    _setup_reverse_start
  fi
}

_setup_log_error() {
  logError "$1"
}

_setup_log_info() {
  logInfo "$1"
}

_setup_log_warning() {
  logWarn "$1"
}

_setup_log_success() {
  logSuccess "$1"
}

is_windows() {
  if uname -r | grep -iq "microsoft"; then
    return 0  # true
  else
    return 1  # false
  fi
}

is_ubuntu() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == *"ubuntu"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
      return 0  # true
    fi
  fi
  return 1  # false
}

is_darwin() {
  if [[ "$(uname)" == "Darwin" ]]; then
    return 0  # true
  else
    return 1  # false
  fi
}

install_oh_my_zsh() {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_docker_ce() {
  is_ubuntu || return
  sudo apt-get install -y docker-ce
}
install_docker_ce_cli() {
  is_ubuntu || return
  sudo apt-get install -y docker-ce-cli
}
install_containerd_io() {
  is_ubuntu || return
  sudo apt-get install -y containerd.io
}
install_docker_buildx_plugin() {
  is_ubuntu || return
  sudo apt-get install -y docker-buildx-plugin
}
install_docker_compose_plugin() {
  is_ubuntu || return
  sudo apt-get install -y docker-compose-plugin
}

install_docker() {
  if ! is_ubuntu; then
    echo "Docker install is only supported on Ubuntu/Debian in this setup; skipping."
    return 0
  fi

  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  install_docker_ce
  install_docker_ce_cli
  install_containerd_io
  install_docker_buildx_plugin
  install_docker_compose_plugin
  sleep 3
  sudo systemctl start docker.service
  sudo systemctl enable docker.service
  sudo usermod -aG docker "$USER"
  # NOTE: reboot
}

install_lazydocker() {
  _brew install lazydocker
}

install_antigen() {
  local antigen_source="$REPO_ROOT/third-party/antigen/antigen.zsh"

  if [ ! -f "$antigen_source" ]; then
    echo "Antigen source not found at $antigen_source" >&2
    return 1
  fi

  cp "$antigen_source" "$HOME/antigen.zsh"
}

install_nvm() {
  local nvm_version="v0.40.4"
  local latest_release_url=""

  latest_release_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/nvm-sh/nvm/releases/latest)" || true

  if [ -n "$latest_release_url" ]; then
    nvm_version="${latest_release_url##*/}"
  fi

  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
}

install_font() {
  is_windows && return

  local folderName="$1"
  local zipName="${folderName}.zip"
  local url="$2"

  curl -Lo $zipName $url
  unzip $zipName
  cd $folderName
  mkdir -p $HOME/.fonts
  mv *.ttf $HOME/.fonts/
  fc-cache -fv
  cd ..
  rm -rf $folderName $zipName
}

install_font_IosevkaTermCurly() {
  install_font "IosevkaTermCurly" "https://github.com/be5invis/Iosevka/releases/download/v30.1.2/PkgTTF-IosevkaTermCurly-30.1.2.zip"
}

install_espanso() {
  is_windows && return

  # https://espanso.org/docs/install/mac/#install-using-homebrew

  _brew install --cask espanso
  # Register espanso as a systemd service (required only once)
  espanso service register

  # NOTE: espanso start
}

install_golang() {
  # https://go.dev/dl/
  local GO_VERSION
  GO_VERSION="$(curl -fsSL "https://go.dev/VERSION?m=text" | sed -n '1s/^go//p')"

  if [ -z "$GO_VERSION" ]; then
    echo "Failed to resolve the latest Go version from go.dev" >&2
    return 1
  fi

  local FILE="go${GO_VERSION}.linux-amd64.tar.gz"
  curl -fsSLO "https://go.dev/dl/$FILE"
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$FILE"
  rm -rf "$FILE"
}

_go() {
  /usr/local/go/bin/go "$@"
}

install_ghq() {
  _brew install ghq # https://formulae.brew.sh/formula/ghq

  mkdir -p $HOME/ghq/work
  mkdir -p $HOME/ghq/projects
}

install_VsCode() {
  is_windows && return

  if is_ubuntu; then
    sudo snap install --classic code
  fi
}

install_font_jetbrains_mono_pkg() {
  _brew install --cask font-jetbrains-mono
}
install_font_dejavu_pkg() {
  _brew install --cask font-dejavu-sans-mono-nerd-font
}
install_font_cascadia_code_pkg() {
  _brew install --cask font-cascadia-code
}

install_fonts() {
  is_windows && return

  install_font_jetbrains_mono_pkg
  install_font_dejavu_pkg
  install_font_cascadia_code_pkg
}

install_eza() {
  _brew install eza # https://formulae.brew.sh/formula/eza
}

install_homebrew() {
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

_brew() {
  if is_ubuntu; then
    /home/linuxbrew/.linuxbrew/bin/brew "$@"
  elif is_darwin; then
     /opt/homebrew/bin/brew "$@"
   else
     echo "Unsupported OS for brew" >&2
     return 1
  fi
}

install_fd_find() {
  _brew install fd
}

install_xclip() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y xclip
  fi
}

install_git_filter_repo() {
  if is_ubuntu; then
    sudo apt install -y git-filter-repo
  fi
}

install_git() {
  if is_ubuntu; then
    sudo apt install -y git
  fi
}

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    echo "zsh already installed; skipping package installation"
  else
    _brew install zsh
  fi

  local desired_shell
  desired_shell="$(command -v zsh || true)"
  if [ -n "$desired_shell" ] && [ "$SHELL" != "$desired_shell" ]; then
    sudo chsh -s "$desired_shell" "$USER"
  fi
}

install_build_essential() { is_ubuntu && sudo apt install -y build-essential; }
install_gcc() { if is_ubuntu; then sudo apt install -y gcc; fi }
install_curl_pkg() { if is_ubuntu; then sudo apt install -y curl; fi }
install_wget_pkg() { if is_ubuntu; then sudo apt install -y wget; fi }
install_zip_pkg() { if is_ubuntu; then sudo apt install -y zip; fi }
install_unzip_pkg() { if is_ubuntu; then sudo apt install -y unzip; fi }
install_python3_venv() { is_ubuntu && sudo apt install -y python3-venv; }

install_essentials() {
  install_build_essential
  install_gcc
  install_curl_pkg
  install_wget_pkg
  install_zip_pkg
  install_unzip_pkg
  install_python3_venv
}

install_jq() {
  _brew install jq # https://stedolan.github.io/jq/
}

install_fzf() {
  _brew install fzf # https://github.com/junegunn/fzf
}

install_ripgrep() {
  _brew install ripgrep # https://github.com/BurntSushi/ripgrep
}

install_zoxide() {
  _brew install zoxide # https://github.com/ajeetdsouza/zoxide
}

install_ggrep() {
  _brew install grep # https://formulae.brew.sh/formula/grep (GNU grep provides ggrep)
  if is_darwin; then
    local brew_prefix
    brew_prefix="$(_brew --prefix)"
    _brew link --overwrite grep
    ln -sf "${brew_prefix}/bin/ggrep" "${brew_prefix}/bin/grep"
  fi
}

install_sdkman() {
  if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk version || true
    return 0
  fi

  curl -s "https://get.sdkman.io" | bash
  if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk version || true
  else
    echo "ERROR: SDKMAN no se instaló correctamente."
  fi
}

install_java_jdk() {
  install_sdkman || return 1

  if ! command -v sdk >/dev/null 2>&1; then
    echo "ERROR: SDKMAN is not available to install Java." >&2
    return 1
  fi

  if ! sdk list java | grep -Fq "$SDKMAN_JAVA_IDENTIFIER"; then
    echo "ERROR: Java identifier '$SDKMAN_JAVA_IDENTIFIER' was not found in SDKMAN." >&2
    return 1
  fi

  if [ ! -d "$HOME/.sdkman/candidates/java/$SDKMAN_JAVA_IDENTIFIER" ]; then
    sdk install java "$SDKMAN_JAVA_IDENTIFIER" || return 1
  fi

  sdk default java "$SDKMAN_JAVA_IDENTIFIER" || return 1

  export JAVA_HOME
  JAVA_HOME="$(sdk home java "$SDKMAN_JAVA_IDENTIFIER" 2>/dev/null || true)"

  if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    echo "ERROR: SDKMAN did not return a valid JAVA_HOME for '$SDKMAN_JAVA_IDENTIFIER'." >&2
    return 1
  fi

  "$JAVA_HOME/bin/java" -version || return 1
  java -version || return 1
  sdk current java || return 1
}
install_yq() {
  _brew install yq # https://github.com/mikefarah/yq
}

install_win32yank() {
  ! is_windows && return

  # Install win32yank in WSL
  local VERSION="v0.1.1"
  local FILENAME="win32yank-x64.zip"
  local URL="https://github.com/equalsraf/win32yank/releases/download/${VERSION}/${FILENAME}"

  sudo apt install wget -y
  wget "$URL"
  unzip "$FILENAME" -d ~/.local/bin/
  chmod +x ~/.local/bin/win32yank.exe
  rm "$FILENAME"
}

ensure_sudo() {
  command -v sudo >/dev/null 2>&1 || return
  if [ -z "${SUDO_KEEPALIVE_PID:-}" ]; then
    sudo -v
    ( while true; do sudo -n true; sleep 60; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
  fi
}

main() {
  if is_ubuntu; then
    sudo apt update
    sudo apt --fix-broken install
  fi

  # IMPORTANT: Install essential packages first
  install_essentials

  # Install other dependencies that might be needed for subsequent installations
  install_golang
  install_homebrew
  install_sdkman
  install_java_jdk
  install_nvm

  # Shell environment
  install_zsh
  install_antigen
  install_oh_my_zsh

  # CLI utilities
  install_jq
  install_fzf
  install_ripgrep
  install_zoxide
  install_ggrep
  install_eza
  install_fd_find
  install_yq
  install_xclip
  install_win32yank
  install_espanso

  # Git tools
  install_git
  install_git_filter_repo
  install_ghq

  # Development tools
  # install_vagrant
  install_docker
  install_lazydocker

  # Fonts
  install_fonts
}

# ─── Interactive Multi-Select Menu ───────────────────────────────────────────

_initialize_menu_catalog() {
  _MENU_IDS=()
  _MENU_LABELS=()
  _MENU_FUNCS=()
  _MENU_DEFAULT_SELECTED=()

  if [[ ! -f "$SETUP_CATALOG_PATH" ]]; then
    echo "ERROR: No se encontró el catálogo de setup: $SETUP_CATALOG_PATH" >&2
    return 1
  fi

  local id label function_name default_selected
  while IFS='|' read -r id label function_name default_selected; do
    [[ "$id" == "Id" || -z "$id" || "${id:0:1}" == "#" ]] && continue
    [[ -z "$function_name" ]] && continue

    _MENU_IDS+=("$id")
    _MENU_LABELS+=("$label")
    _MENU_FUNCS+=("$function_name")
    _MENU_DEFAULT_SELECTED+=("$default_selected")
  done < "$SETUP_CATALOG_PATH"
}

_reset_menu_selection_to_defaults() {
  _MENU_SELECTED=("${_MENU_DEFAULT_SELECTED[@]}")
}

_validate_menu_catalog() {
  local ids_count=${#_MENU_IDS[@]}
  local labels_count=${#_MENU_LABELS[@]}
  local funcs_count=${#_MENU_FUNCS[@]}
  local defaults_count=${#_MENU_DEFAULT_SELECTED[@]}

  if ((ids_count != labels_count || labels_count != funcs_count || labels_count != defaults_count)); then
    echo "ERROR: El catálogo del menú tiene longitudes inconsistentes." >&2
    return 1
  fi

  local found_non_default=0
  local menu_index
  for menu_index in "${!_MENU_LABELS[@]}"; do
    if ! declare -F "${_MENU_FUNCS[$menu_index]}" >/dev/null 2>&1; then
      echo "ERROR: La función '${_MENU_FUNCS[$menu_index]}' no existe." >&2
      return 1
    fi

    if [[ ${_MENU_DEFAULT_SELECTED[$menu_index]} -eq 0 ]]; then
      found_non_default=1
    elif [[ $found_non_default -eq 1 ]]; then
      echo "ERROR: Los elementos seleccionados por defecto deben estar al inicio del catálogo." >&2
      return 1
    fi
  done

  local duplicated_label
  duplicated_label="$(printf "%s\n" "${_MENU_LABELS[@]}" | sort | uniq -d | head -n 1)"
  if [[ -n "$duplicated_label" ]]; then
    echo "ERROR: Hay etiquetas duplicadas en el catálogo: $duplicated_label" >&2
    return 1
  fi

  local duplicated_id
  duplicated_id="$(printf "%s\n" "${_MENU_IDS[@]}" | sort | uniq -d | head -n 1)"
  if [[ -n "$duplicated_id" ]]; then
    echo "ERROR: Hay identificadores duplicados en el catálogo: $duplicated_id" >&2
    return 1
  fi
}

_find_menu_function_index() {
  local function_name=$1
  local menu_index

  for menu_index in "${!_MENU_FUNCS[@]}"; do
    if [[ "${_MENU_FUNCS[$menu_index]}" == "$function_name" ]]; then
      echo "$menu_index"
      return 0
    fi
  done

  return 1
}

_menu_selected_count() {
  local selected_count=0
  local selection_state

  for selection_state in "${_MENU_SELECTED[@]}"; do
    ((selection_state == 1)) && ((selected_count++))
  done

  echo "$selected_count"
}

_run_selected_menu_items() {
  local dry_run=${1:-0}
  local menu_index
  _INSTALL_RESULT_LABELS=()
  _INSTALL_RESULT_STATUSES=()

  for menu_index in "${!_MENU_FUNCS[@]}"; do
    if [[ ${_MENU_SELECTED[$menu_index]} -eq 1 ]]; then
      if [[ $dry_run -eq 1 ]]; then
        printf "\n"
        _setup_log_info "Dry-run: se ejecutaría ${_MENU_LABELS[$menu_index]}."
        _INSTALL_RESULT_LABELS+=("${_MENU_LABELS[$menu_index]}")
        _INSTALL_RESULT_STATUSES+=("dry-run")
        continue
      fi

      printf "\n"
      _setup_log_info "Instalando: ${_MENU_LABELS[$menu_index]}"
      if ${_MENU_FUNCS[$menu_index]}; then
        _setup_log_success "${_MENU_LABELS[$menu_index]}"
        _INSTALL_RESULT_LABELS+=("${_MENU_LABELS[$menu_index]}")
        _INSTALL_RESULT_STATUSES+=("ok")
      else
        _setup_log_error "Falló: ${_MENU_LABELS[$menu_index]}" >&2
        _INSTALL_RESULT_LABELS+=("${_MENU_LABELS[$menu_index]}")
        _INSTALL_RESULT_STATUSES+=("falló")
      fi
    fi
  done
}

_print_install_summary() {
  local result_index

  printf "\n"
  _setup_log_info "Resumen de instalación:"
  for result_index in "${!_INSTALL_RESULT_LABELS[@]}"; do
    case "${_INSTALL_RESULT_STATUSES[$result_index]}" in
      ok) _setup_colored_line "green" "  [OK] ${_INSTALL_RESULT_LABELS[$result_index]}" ;;
      dry-run) _setup_colored_line "yellow" "  [DRY-RUN] ${_INSTALL_RESULT_LABELS[$result_index]}" ;;
      *) _setup_colored_line "red" "  [ERROR] ${_INSTALL_RESULT_LABELS[$result_index]}" ;;
    esac
  done
}

_menu_is_recommended() {
  local menu_index=$1
  [[ ${_MENU_DEFAULT_SELECTED[$menu_index]} -eq 1 ]]
}

_menu_display_label() {
  local menu_index=$1
  local label="${_MENU_LABELS[$menu_index]}"

  if ! _menu_is_recommended "$menu_index"; then
    printf "%s" "$label"
    return 0
  fi

  printf "@ %s" "$label"
}

_draw_menu_label() {
  local menu_index=$1
  local is_cursor=${2:-0}
  local label="${_MENU_LABELS[$menu_index]}"

  if ! _menu_is_recommended "$menu_index"; then
    printf "%s" "$label"
    return 0
  fi

  _setup_color_for_menu_row "yellow" "@" "$is_cursor"
  printf " %s" "$label"
}

_draw_menu_item() {
  local idx=$1 cursor=$2 label=$3 is_selected=$4
  local marker=" "
  local pointer="  "
  local cursor_prefix=""
  local cursor_suffix=""
  local is_cursor=0
  [[ $is_selected -eq 1 ]] && marker="✅"
  if [[ $idx -eq $cursor ]]; then
    is_cursor=1
    pointer="👉"
    cursor_prefix="$(_setup_reverse_start)"
    cursor_suffix="$(_setup_style_reset)"
  fi

  printf "%s %s [" "$cursor_prefix" "$pointer"
  if [[ $is_selected -eq 1 ]]; then
    _setup_color_for_menu_row "green" "$marker" "$is_cursor"
  else
    printf "%s" "$marker"
  fi
  printf "] "
  _draw_menu_label "$idx" "$is_cursor"
  printf "%s" "$cursor_suffix"
}

_menu_visible_height() {
  local terminal_rows
  terminal_rows="$(tput lines 2>/dev/null || echo 24)"

  local visible_height=$((terminal_rows - 18))
  if ((visible_height < 5)); then
    visible_height=5
  fi

  if ((visible_height > ${#_MENU_LABELS[@]})); then
    visible_height=${#_MENU_LABELS[@]}
  fi

  echo "$visible_height"
}

_menu_adjust_window_start() {
  local cursor=$1 window_start=$2 visible_height=$3 count=$4

  if ((cursor < window_start)); then
    window_start=$cursor
  elif ((cursor >= window_start + visible_height)); then
    window_start=$((cursor - visible_height + 1))
  fi

  if ((window_start < 0)); then
    window_start=0
  fi

  local max_window_start=$((count - visible_height))
  if ((max_window_start < 0)); then
    max_window_start=0
  fi

  if ((window_start > max_window_start)); then
    window_start=$max_window_start
  fi

  echo "$window_start"
}

_draw_menu_window() {
  local cursor=$1 window_start=$2 visible_height=$3 count=$4
  local window_end=$((window_start + visible_height))

  printf "\r\033[2K  Elementos "
  _setup_color "cyan" "$((window_start + 1))"
  printf "-"
  _setup_color "cyan" "$window_end"
  printf " de "
  _setup_color "cyan" "$count"
  printf "\n"
  printf "\r\033[2K  "
  _setup_color "yellow" "@"
  printf " seleccionado por defecto\n"

  if ((window_start > 0)); then
    printf "\r\033[2K  ↑ Hay más elementos arriba\n"
  else
    printf "\r\033[2K\n"
  fi

  local menu_index
  for ((menu_index = window_start; menu_index < window_end; menu_index++)); do
    printf "\r\033[2K"
    _draw_menu_item "$menu_index" "$cursor" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}"
    printf "\n"
  done

  if ((window_end < count)); then
    printf "\r\033[2K  ↓ Hay más elementos abajo\n"
  else
    printf "\r\033[2K\n"
  fi
}

_menu_item_row_offset() {
  local menu_index=$1 window_start=$2
  echo $((3 + menu_index - window_start))
}

_draw_menu_item_line() {
  local menu_index=$1 cursor=$2
  printf "\r\033[2K"
  _draw_menu_item "$menu_index" "$cursor" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}"
}

_redraw_menu_item_from_bottom() {
  local menu_index=$1 cursor=$2 window_start=$3 rendered_lines=$4
  local row_offset lines_up
  row_offset="$(_menu_item_row_offset "$menu_index" "$window_start")"
  lines_up=$((rendered_lines - row_offset))

  printf "\033[%dA" "$lines_up"
  _draw_menu_item_line "$menu_index" "$cursor"
  printf "\033[%dB\r" "$lines_up"
}

_menu_requires_full_render() {
  local previous_window_start=$1 window_start=$2 previous_visible_height=$3 visible_height=$4 force_full_render=$5
  [[ "$force_full_render" -eq 1 || "$previous_window_start" -ne "$window_start" || "$previous_visible_height" -ne "$visible_height" ]]
}

_find_menu_item_index() {
  local query=$1 start_index=$2 count=$3

  if [[ -z "$query" ]]; then
    echo "$start_index"
    return
  fi

  local offset candidate_index label_lower query_lower
  query_lower="$(printf "%s" "$query" | tr '[:upper:]' '[:lower:]')"
  for ((offset = 1; offset <= count; offset++)); do
    candidate_index=$(((start_index + offset) % count))
    label_lower="$(printf "%s" "${_MENU_LABELS[$candidate_index]}" | tr '[:upper:]' '[:lower:]')"
    if [[ "$label_lower" == *"$query_lower"* ]]; then
      echo "$candidate_index"
      return
    fi
  done

  echo "$start_index"
}

_filter_menu_indexes() {
  local query=$1 count=$2
  local query_lower label_lower menu_index

  _FILTERED_MENU_INDEXES=()
  query_lower="$(printf "%s" "$query" | tr '[:upper:]' '[:lower:]')"

  for ((menu_index = 0; menu_index < count; menu_index++)); do
    label_lower="$(printf "%s" "${_MENU_LABELS[$menu_index]}" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$query_lower" || "$label_lower" == *"$query_lower"* ]]; then
      _FILTERED_MENU_INDEXES+=("$menu_index")
    fi
  done
}

_draw_search_window() {
  local query=$1 filtered_cursor=$2 visible_height=$3
  local filtered_count=${#_FILTERED_MENU_INDEXES[@]}
  local visible_count=$visible_height

  if ((visible_count > filtered_count)); then
    visible_count=$filtered_count
  fi

  local search_window_start=0
  if ((filtered_count > 0)); then
    search_window_start="$(_menu_adjust_window_start "$filtered_cursor" 0 "$visible_count" "$filtered_count")"
  fi

  printf "\r\033[2K  Buscar: %s\n" "$query"
  printf "\r\033[2K  Coincidencias: "
  _setup_color "cyan" "$filtered_count"
  printf "\n"
  printf "\r\033[2K  "
  _setup_color "cyan" "ENTER"
  printf ": volver\n"
  printf "\r\033[2K  "
  _setup_color "cyan" "ESPACIO"
  printf ": alternar\n"
  printf "\r\033[2K  "
  _setup_color "cyan" "ESC"
  printf ": cancelar\n"

  if ((filtered_count == 0)); then
    printf "\r\033[2K  Sin coincidencias\n"
    local empty_line
    for ((empty_line = 1; empty_line < visible_height; empty_line++)); do
      printf "\r\033[2K\n"
    done
    return
  fi

  local visible_index menu_index
  for ((visible_index = search_window_start; visible_index < search_window_start + visible_count; visible_index++)); do
    menu_index=${_FILTERED_MENU_INDEXES[$visible_index]}
    printf "\r\033[2K"
    _draw_menu_item "$menu_index" "$menu_index" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}"
    if ((visible_index != filtered_cursor)); then
      printf "\r\033[2K"
      _draw_menu_item "$menu_index" "-1" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}"
    fi
    printf "\n"
  done

  local empty_line
  for ((empty_line = visible_count; empty_line < visible_height; empty_line++)); do
    printf "\r\033[2K\n"
  done
}

_search_menu_incrementally() {
  local cursor=$1 visible_height=$2 count=$3
  local query=""
  local filtered_cursor=0
  _SEARCH_MENU_CURSOR_RESULT="$cursor"

  _filter_menu_indexes "$query" "$count"

  while true; do
    clear
    printf "\n  Búsqueda de paquetes\n"
    printf "  Escribí para filtrar en vivo. Backspace borra.\n\n"
    _draw_search_window "$query" "$filtered_cursor" "$visible_height"

    local key rest
    IFS= read -rsn1 key

    case "$key" in
      $'\033')
        if IFS= read -rsn2 -t 0.05 rest 2>/dev/null; then
          case "$rest" in
            '[A') ((filtered_cursor > 0)) && ((filtered_cursor--)) ;;
            '[B') ((filtered_cursor < ${#_FILTERED_MENU_INDEXES[@]} - 1)) && ((filtered_cursor++)) ;;
            '[H') filtered_cursor=0 ;;
            '[F') filtered_cursor=$((${#_FILTERED_MENU_INDEXES[@]} - 1)); ((filtered_cursor < 0)) && filtered_cursor=0 ;;
          esac
        else
          _SEARCH_MENU_CURSOR_RESULT="$cursor"
          return 1
        fi
        ;;
      '')
        if ((${#_FILTERED_MENU_INDEXES[@]} > 0)); then
          _SEARCH_MENU_CURSOR_RESULT="${_FILTERED_MENU_INDEXES[$filtered_cursor]}"
        else
          _SEARCH_MENU_CURSOR_RESULT="$cursor"
        fi
        return 0
        ;;
      $'\003')
        _SEARCH_MENU_CURSOR_RESULT="$cursor"
        return 1
        ;;
      $'\177'|$'\b')
        if ((${#query} > 0)); then
          query="${query:0:${#query}-1}"
        fi
        ;;
      ' ')
        if ((${#_FILTERED_MENU_INDEXES[@]} > 0)); then
          local menu_index=${_FILTERED_MENU_INDEXES[$filtered_cursor]}
          _MENU_SELECTED[$menu_index]=$((1 - ${_MENU_SELECTED[$menu_index]}))
        fi
        ;;
      k)
        ((filtered_cursor > 0)) && ((filtered_cursor--))
        ;;
      j)
        ((filtered_cursor < ${#_FILTERED_MENU_INDEXES[@]} - 1)) && ((filtered_cursor++))
        ;;
      *)
        query+="$key"
        ;;
    esac

    _filter_menu_indexes "$query" "$count"
    if ((filtered_cursor >= ${#_FILTERED_MENU_INDEXES[@]})); then
      filtered_cursor=$((${#_FILTERED_MENU_INDEXES[@]} - 1))
      ((filtered_cursor < 0)) && filtered_cursor=0
    fi

  done
}

_read_key() {
  local key rest
  IFS= read -rsn1 key
  case "$key" in
    $'\033')
      if IFS= read -rsn2 -t 1 rest 2>/dev/null; then
        case "$rest" in
          '[A') echo "UP"; return ;;
          '[B') echo "DOWN"; return ;;
          '[H') echo "HOME"; return ;;
          '[F') echo "END"; return ;;
          '[5') IFS= read -rsn1 -t 1 rest 2>/dev/null; echo "PAGE_UP"; return ;;
          '[6') IFS= read -rsn1 -t 1 rest 2>/dev/null; echo "PAGE_DOWN"; return ;;
        esac
      fi
      echo "ESC"
      ;;
    ' ') echo "SPACE" ;;
    '') echo "ENTER" ;;
    $'\003') echo "QUIT" ;;
    j) echo "DOWN" ;;
    k) echo "UP" ;;
    a|A) echo "ALL" ;;
    r|R) echo "DEFAULTS" ;;
    /) echo "SEARCH" ;;
    q|Q) echo "QUIT" ;;
    *) echo "OTHER" ;;
  esac
}

_draw_menu_reference_frame_line() {
  _setup_colored_line "magenta" "$1"
}

_draw_menu_reference_row() {
  local shortcut=$1 description=$2
  local padded_shortcut

  padded_shortcut="$(printf "%-18s" "$shortcut")"
  _setup_color "magenta" "  | "
  _setup_color "cyan" "$padded_shortcut"
  _setup_color "magenta" " | "
  printf "%-24s" "$description"
  _setup_color "magenta" " |"
  printf "\n"
}

_draw_menu_reference() {
  _draw_menu_reference_frame_line "  +--------------------+--------------------------+"
  _draw_menu_reference_frame_line "  | Atajos del menú                               |"
  _draw_menu_reference_frame_line "  +--------------------+--------------------------+"
  _draw_menu_reference_row "↑/↓/j/k" "navegar"
  _draw_menu_reference_row "PgUp/PgDn/Home/End" "saltar"
  _draw_menu_reference_row "/" "buscar"
  _draw_menu_reference_row "ESPACIO" "alternar"
  _draw_menu_reference_row "a" "alternar todo"
  _draw_menu_reference_row "r" "restaurar defaults"
  _draw_menu_reference_row "ENTER" "confirmar"
  _draw_menu_reference_row "q/Ctrl+C" "cancelar"
  _draw_menu_reference_frame_line "  +--------------------+--------------------------+"
  printf "\n"
}

# Operates on global arrays: _MENU_LABELS, _MENU_SELECTED
_multiselect() {
  local cursor=0
  local count=${#_MENU_LABELS[@]}
  local window_start=0
  local visible_height
  visible_height="$(_menu_visible_height)"
  local rendered_lines=$((visible_height + 4))
  local previous_interrupt_trap
  previous_interrupt_trap="$(trap -p INT)"

  trap 'printf "\n  Instalación cancelada.\n"; exit 130' INT

  printf "\n"
  _draw_menu_reference

  _draw_menu_window "$cursor" "$window_start" "$visible_height" "$count"

  while true; do
    local key
    local previous_cursor=$cursor
    local previous_window_start=$window_start
    local previous_visible_height=$visible_height
    local previous_rendered_lines=$rendered_lines
    local force_full_render=0
    local should_draw_from_current_position=0
    key=$(_read_key)

    case "$key" in
      UP)    ((cursor > 0)) && ((cursor--)) ;;
      DOWN)  ((cursor < count - 1)) && ((cursor++)) ;;
      PAGE_UP) cursor=$((cursor - visible_height)); ((cursor < 0)) && cursor=0 ;;
      PAGE_DOWN) cursor=$((cursor + visible_height)); ((cursor > count - 1)) && cursor=$((count - 1)) ;;
      HOME) cursor=0 ;;
      END) cursor=$((count - 1)) ;;
      SPACE) _MENU_SELECTED[$cursor]=$(( 1 - ${_MENU_SELECTED[$cursor]} )) ;;
      DEFAULTS) _reset_menu_selection_to_defaults; force_full_render=1 ;;
      SEARCH)
        if _search_menu_incrementally "$cursor" "$visible_height" "$count"; then
          cursor="$_SEARCH_MENU_CURSOR_RESULT"
        fi
        clear
        printf "\n"
        _draw_menu_reference
        force_full_render=1
        should_draw_from_current_position=1
        ;;
      ALL)
        local all_on=1
        for s in "${_MENU_SELECTED[@]}"; do
          [[ $s -eq 0 ]] && all_on=0 && break
        done
        local toggle=$(( 1 - all_on ))
        for i in "${!_MENU_SELECTED[@]}"; do
          _MENU_SELECTED[$i]=$toggle
        done
        force_full_render=1
        ;;
      ENTER)
        if [[ -n "$previous_interrupt_trap" ]]; then
          eval "$previous_interrupt_trap"
        else
          trap - INT
        fi
        printf "\n"
        return 0
        ;;
      QUIT)
        if [[ -n "$previous_interrupt_trap" ]]; then
          eval "$previous_interrupt_trap"
        else
          trap - INT
        fi
        printf "\n"
        return 1
        ;;
      *) continue ;;
    esac

    visible_height="$(_menu_visible_height)"
    rendered_lines=$((visible_height + 4))
    window_start="$(_menu_adjust_window_start "$cursor" "$window_start" "$visible_height" "$count")"

    if [[ $should_draw_from_current_position -eq 1 ]]; then
      _draw_menu_window "$cursor" "$window_start" "$visible_height" "$count"
    elif _menu_requires_full_render "$previous_window_start" "$window_start" "$previous_visible_height" "$visible_height" "$force_full_render"; then
      printf "\033[%dA" "$previous_rendered_lines"
      _draw_menu_window "$cursor" "$window_start" "$visible_height" "$count"
    elif [[ "$key" == "SPACE" ]]; then
      _redraw_menu_item_from_bottom "$cursor" "$cursor" "$window_start" "$rendered_lines"
    elif ((previous_cursor != cursor)); then
      _redraw_menu_item_from_bottom "$previous_cursor" "$cursor" "$window_start" "$rendered_lines"
      _redraw_menu_item_from_bottom "$cursor" "$cursor" "$window_start" "$rendered_lines"
    fi
  done
}

_print_selected_menu_items() {
  local menu_index

  for menu_index in "${!_MENU_LABELS[@]}"; do
    if [[ ${_MENU_SELECTED[$menu_index]} -eq 1 ]]; then
      printf "  - %s\n" "${_MENU_LABELS[$menu_index]}"
    fi
  done
}

_confirm_selected_menu_items() {
  local dry_run=${1:-0}
  local selected_count
  selected_count="$(_menu_selected_count)"

  printf "\n"
  if [[ $dry_run -eq 1 ]]; then
    _setup_log_warning "Modo dry-run activo: no se instalará nada."
  fi

  _setup_log_info "Elementos seleccionados ($selected_count):"
  _print_selected_menu_items
  printf "\n  ENTER: continuar\n"
  printf "  q/Ctrl+C: cancelar\n"

  while true; do
    local key
    key="$(_read_key)"
    case "$key" in
      ENTER) printf "\n"; return 0 ;;
      QUIT|ESC) printf "\n"; return 1 ;;
    esac
  done
}

interactive_menu() {
  local dry_run=${1:-0}
  _initialize_menu_catalog || return 1
  _validate_menu_catalog || return 1
  _reset_menu_selection_to_defaults

  clear
  printf "\n"
  _setup_colored_line "magenta" "  ╔══════════════════════════════════════╗"
  _setup_colored_line "magenta" "  ║     Instalador de setup del sistema  ║"
  _setup_colored_line "magenta" "  ╚══════════════════════════════════════╝"

  if ! _multiselect; then
    _setup_log_warning "Instalación cancelada."
    return 0
  fi

  # Count selected
  local count
  count=$(_menu_selected_count)

  if [[ $count -eq 0 ]]; then
    _setup_log_warning "No se seleccionaron elementos. No se instalará nada."
    return 0
  fi

  if ! _confirm_selected_menu_items "$dry_run"; then
    _setup_log_warning "Instalación cancelada."
    return 0
  fi

  _setup_log_info "Se procesarán $count elemento(s) seleccionado(s)."

  if [[ $dry_run -eq 0 ]] && is_ubuntu; then
    sudo apt update
    sudo apt --fix-broken install
  fi

  _run_selected_menu_items "$dry_run"
  _print_install_summary

  printf "\n"
  _setup_log_success "Proceso completo."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dry_run=0
  if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=1
    shift
  fi

  if [[ $dry_run -eq 0 ]]; then
    ensure_sudo
  fi

  if [[ -n "$1" ]]; then
    _initialize_menu_catalog || exit 1
    _validate_menu_catalog || exit 1
    if ! _find_menu_function_index "$1" >/dev/null; then
      _setup_log_error "La función '$1' no está permitida por el catálogo de setup." >&2
      exit 1
    fi

    if [[ $dry_run -eq 1 ]]; then
      _setup_log_warning "Dry-run: se ejecutaría $*"
    else
      _setup_log_info "Ejecutando $0 $*"
      "$1"
    fi
  else
    interactive_menu "$dry_run"
  fi
fi
