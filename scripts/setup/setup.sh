#!/bin/bash

LOCAL_BINARIES="$HOME/.local/bin"
SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SETUP_SCRIPT_DIR" rev-parse --show-toplevel)"
SETUP_CATALOG_PATH="$SETUP_SCRIPT_DIR/setup.catalog.csv"
SETUP_STYLE_TEXT_PATH="$REPO_ROOT/configs/zsh/.zsh/functions/styleText.zsh"
SETUP_ESCAPE_SEQUENCE_TIMEOUT_SECONDS=0.05
SETUP_INPUT_FLUSH_TIMEOUT_SECONDS=0.02
SETUP_LATEST_VERSION_POLICY="latest-stable-official"

SETUP_BOX_RULE_WIDTH=64
# ASCII-only decorations: the setup runs on fresh machines and in terminals
# without Unicode or emoji fonts.
_setup_load_ascii_decorations() {
  SETUP_ICON_APP=""
  SETUP_ICON_REAL_RUN=">"
  SETUP_ICON_DRY_RUN="~"
  SETUP_ICON_PLATFORM=""
  SETUP_ICON_CATALOG=""
  SETUP_ICON_RECOMMENDED="*"
  SETUP_ICON_ADMIN="#"
  SETUP_ICON_RESTART="^"
  SETUP_ICON_PACKAGE=">"
  SETUP_ICON_SELECTED="x"
  SETUP_ICON_POINTER=">"
  SETUP_ICON_OK="+"
  SETUP_ICON_FAILED_ITEM="x"
  SETUP_ICON_SKIPPED="-"
  SETUP_ICON_INFO="-"
  SETUP_ICON_WARN="!"
  SETUP_ICON_ERROR="x"
  SETUP_ICON_TIME=""
  SETUP_ICON_SUMMARY=""
  SETUP_ICON_SHORTCUTS=""
  SETUP_ICON_SEARCH=""
  SETUP_ICON_NO_RESULTS="?"
  SETUP_SEARCH_PROMPT=">"
  SETUP_SEARCH_CURSOR="_"
  SETUP_ICON_REFRESH="~"
  SETUP_ICON_DONE="+"
  SETUP_ICON_FAILED_RUN="x"
  SETUP_BOX_TOP_LEFT="+"
  SETUP_BOX_BOTTOM_LEFT="+"
  SETUP_BOX_VERTICAL="|"
  SETUP_BOX_TEE="+"
  SETUP_BOX_HORIZONTAL="-"
  SETUP_SCROLLBAR_THUMB_GLYPH="#"
  SETUP_SCROLLBAR_TRACK_GLYPH="|"
  SETUP_SEPARATOR="-"
  SETUP_ELLIPSIS="..."
  SETUP_ARROW_UP="^"
  SETUP_ARROW_DOWN="v"
  SETUP_QUOTE_OPEN='"'
  SETUP_QUOTE_CLOSE='"'
  SETUP_POINTER_BLANK=" "
  SETUP_MARK_BLANK=" "
  SETUP_ICON_CHECKED="[x]"
  SETUP_ICON_UNCHECKED="[ ]"
  SETUP_BAR_FILLED="#"
  SETUP_BAR_EMPTY="."
}
_setup_load_ascii_decorations

SETUP_SUMMARY_LABEL_WIDTH=32
SETUP_SHORTCUT_WIDTH=18
SETUP_SHORTCUT_DESCRIPTION_WIDTH=20
# Menu window: header box (3 lines) and top indicator above the rows.
SETUP_MENU_HEADER_LINES=4
# Below the rows: bottom indicator and the details line of the cursor item.
SETUP_MENU_FOOTER_LINES=2
SETUP_MENU_SELECTION_BAR_WIDTH=12
SETUP_MENU_MAX_LABEL_COLUMN=40
# Lines outside the item rows: leading blank + banner (5), blank (1),
# shortcuts box + spacer (7), window header (4), bottom indicator (1) and the
# details line (1) and the line where the cursor rests (1).
SETUP_MENU_RESERVED_LINES=20
SETUP_MENU_MIN_VISIBLE_ITEMS=5
SETUP_DEFAULT_TERMINAL_ROWS=24
# Subtle 256-color background for the row under the cursor.
SETUP_MENU_CURSOR_BACKGROUND_CODE="48;5;237"
SETUP_MENU_CURSOR_BACKGROUND=$'\033['"$SETUP_MENU_CURSOR_BACKGROUND_CODE"'m'
SETUP_MENU_HIGHLIGHT_WIDTH=58

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

# Styled once at load: the menu redraws the scrollbar on every key.
SETUP_MENU_SCROLLBAR_THUMB="$(styleText -c cyan -- "$SETUP_SCROLLBAR_THUMB_GLYPH")"
SETUP_MENU_SCROLLBAR_TRACK="$(styleText -c gray -- "$SETUP_SCROLLBAR_TRACK_GLYPH")"


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

_setup_color_bold() {
  local color=$1 text=$2
  styleText -c "$color" -b -- "$text"
}

_setup_colored_line() {
  local color=$1 text=$2
  _setup_color "$color" "$text"
  printf "\n"
}




_setup_repeat_text() {
  local text=$1 count=$2 result=""
  while ((count > 0)); do
    result+="$text"
    count=$((count - 1))
  done
  printf "%s" "$result"
}

# Boxes are open on the right so rows can have any width; only the left border
# and horizontal rules are drawn.
_setup_box_top() {
  local title=${1:-}
  if [[ -z "$title" ]]; then
    _setup_colored_line "gray" "$SETUP_BOX_TOP_LEFT$(_setup_repeat_text "$SETUP_BOX_HORIZONTAL" "$SETUP_BOX_RULE_WIDTH")"
    return 0
  fi
  local rule_length=$((SETUP_BOX_RULE_WIDTH - ${#title} - 4))
  ((rule_length < 1)) && rule_length=1
  _setup_color "gray" "$SETUP_BOX_TOP_LEFT$SETUP_BOX_HORIZONTAL "
  styleText -c blue -b -- "$title"
  _setup_color "gray" " $(_setup_repeat_text "$SETUP_BOX_HORIZONTAL" "$rule_length")"
  printf "\n"
}

_setup_box_row() {
  _setup_color "gray" "$SETUP_BOX_VERTICAL"
  printf " %s\n" "$1"
}

_setup_box_divider() {
  _setup_colored_line "gray" "$SETUP_BOX_TEE$(_setup_repeat_text "$SETUP_BOX_HORIZONTAL" "$SETUP_BOX_RULE_WIDTH")"
}

_setup_box_bottom() {
  _setup_colored_line "gray" "$SETUP_BOX_BOTTOM_LEFT$(_setup_repeat_text "$SETUP_BOX_HORIZONTAL" "$SETUP_BOX_RULE_WIDTH")"
}

_setup_box_close() {
  _setup_color "gray" "$SETUP_BOX_BOTTOM_LEFT$SETUP_BOX_HORIZONTAL"
  printf " %s\n" "$1"
}

_setup_log_line() {
  local color=$1 prefix=$2 message=$3
  printf "%s %s\n" "$(styleText -c "$color" -b -- "$prefix")" "$message"
}

_setup_log_error() {
  _setup_log_line "red" "${SETUP_ICON_ERROR:+$SETUP_ICON_ERROR }Error:" "$1"
}

_setup_log_info() {
  _setup_log_line "blue" "$SETUP_ICON_INFO" "$1"
}

_setup_log_warning() {
  _setup_log_line "yellow" "${SETUP_ICON_WARN:+$SETUP_ICON_WARN }Aviso:" "$1"
}

_setup_log_success() {
  _setup_log_line "green" "$SETUP_ICON_OK" "$1"
}

_setup_platform_display_name() {
  case "$(_setup_current_platform)" in
    darwin) printf "macOS" ;;
    wsl) printf "WSL" ;;
    linux) printf "Linux" ;;
    windows) printf "Windows" ;;
    *) _setup_current_platform ;;
  esac
}

_setup_format_duration() {
  local total_seconds=$1
  if ((total_seconds >= 60)); then
    printf "%dm %02ds" $((total_seconds / 60)) $((total_seconds % 60))
  else
    printf "%ds" "$total_seconds"
  fi
}

_setup_print_banner() {
  local dry_run=${1:-0}
  local mode_text="${SETUP_ICON_REAL_RUN:+$SETUP_ICON_REAL_RUN }instalación"
  if [[ $dry_run -eq 1 ]]; then
    mode_text="${SETUP_ICON_DRY_RUN:+$SETUP_ICON_DRY_RUN }simulación: no se instalará nada"
  fi
  local recommended_count=0 default_selected
  for default_selected in "${_MENU_DEFAULT_SELECTED[@]}"; do
    ((default_selected == 1)) && recommended_count=$((recommended_count + 1))
  done

  _setup_box_top
  _setup_box_row "$(styleText -c magenta -b -- "${SETUP_ICON_APP:+$SETUP_ICON_APP }setup del sistema") $(_setup_color "gray" "$SETUP_SEPARATOR") $mode_text"
  _setup_box_row "$(_setup_color "gray" "${SETUP_ICON_PLATFORM:+$SETUP_ICON_PLATFORM }$(_setup_platform_display_name) $SETUP_SEPARATOR ${SETUP_ICON_CATALOG:+$SETUP_ICON_CATALOG }${#_MENU_LABELS[@]} ítems $SETUP_SEPARATOR ${SETUP_ICON_RECOMMENDED:+$SETUP_ICON_RECOMMENDED }$recommended_count recomendados")"
  _setup_box_bottom
}

# Badges appended to a menu label: sudo and restart requirements.
# Sets _SETUP_MENU_BADGES without a subshell (hot path while redrawing).
_menu_load_item_badges() {
  local menu_index=$1
  _SETUP_MENU_BADGES=""
  [[ "${_MENU_REQUIRES_ADMIN[$menu_index]:-0}" == "1" ]] && _SETUP_MENU_BADGES+=" $SETUP_ICON_ADMIN"
  [[ "${_MENU_REQUIRES_RESTART[$menu_index]:-0}" == "1" ]] && _SETUP_MENU_BADGES+=" $SETUP_ICON_RESTART"
  return 0
}

_menu_item_badges() {
  _menu_load_item_badges "$1"
  printf "%s" "$_SETUP_MENU_BADGES"
}

is_windows() {
  if uname -r | grep -iq "microsoft"; then
    return 0  # true
  else
    return 1  # false
  fi
}

is_ubuntu() {
  [ -f /etc/os-release ] || return 1
  ( . /etc/os-release; [[ "${ID:-}" == "ubuntu" ]] )
}

is_debian_like() {
  [ -f /etc/os-release ] || return 1
  ( . /etc/os-release; [[ "${ID:-}" == "debian" || "${ID:-}" == "ubuntu" || " ${ID_LIKE:-} " == *" debian "* ]] )
}

_setup_read_os_release_field() {
  local field=$1
  [ -f /etc/os-release ] || return 1
  ( . /etc/os-release; printf "%s" "${!field:-}" )
}

is_darwin() {
  if [[ "$(uname)" == "Darwin" ]]; then
    return 0  # true
  else
    return 1  # false
  fi
}

# Uses the platform cached by _initialize_menu_catalog when available; the
# detection forks uname and reads os-release, which is slow per catalog item.
_setup_current_platform() {
  if [[ -n "${_SETUP_PLATFORM_CACHE:-}" ]]; then
    echo "$_SETUP_PLATFORM_CACHE"
    return 0
  fi

  if is_windows; then
    echo "wsl"
  elif is_darwin; then
    echo "darwin"
  elif is_debian_like; then
    echo "linux"
  else
    echo "unknown"
  fi
}

_setup_platforms_include_current() {
  local supported_platforms=${1:-all}
  local current_platform

  [[ -z "$supported_platforms" || "$supported_platforms" == "all" ]] && return 0
  current_platform="${_SETUP_PLATFORM_CACHE:-$(_setup_current_platform)}"

  case ",$supported_platforms," in
    *",$current_platform,"*) return 0 ;;
    *) return 1 ;;
  esac
}

_setup_platform_token_is_supported() {
  case "$1" in
    all|linux|wsl|darwin|windows) return 0 ;;
    *) return 1 ;;
  esac
}

install_oh_my_zsh() {
  _setup_log_info "Instalando la última versión estable oficial de Oh My Zsh."

  if [[ -d "$HOME/.oh-my-zsh/.git" ]]; then
    git -C "$HOME/.oh-my-zsh" pull --ff-only
    return 0
  fi

  local temp_dir install_script
  temp_dir="$(_setup_create_temp_dir)"
  install_script="$temp_dir/oh-my-zsh-install.sh"
  if ! curl -fsSLo "$install_script" "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  if ! RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$install_script"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  _setup_remove_temp_dir "$temp_dir"
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "Oh My Zsh no quedó instalado en $HOME/.oh-my-zsh." >&2
    return 1
  fi
}

install_docker_ce() {
  is_debian_like || return
  sudo apt-get install -y docker-ce
}
install_docker_ce_cli() {
  is_debian_like || return
  sudo apt-get install -y docker-ce-cli
}
install_containerd_io() {
  is_debian_like || return
  sudo apt-get install -y containerd.io
}
install_docker_buildx_plugin() {
  is_debian_like || return
  sudo apt-get install -y docker-buildx-plugin
}
install_docker_compose_plugin() {
  is_debian_like || return
  sudo apt-get install -y docker-compose-plugin
}

install_docker() {
  if ! is_debian_like; then
    echo "La instalación de Docker solo está soportada en Ubuntu/Debian en este setup; se omite."
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    echo "Docker ya está instalado; el package manager resolverá la última versión estable si se actualiza por separado."
    return 0
  fi

  local docker_distribution_id docker_distribution_codename
  docker_distribution_id="$(_setup_read_os_release_field ID)"
  docker_distribution_codename="$(_setup_read_os_release_field VERSION_CODENAME)"
  if [[ "$docker_distribution_id" == "ubuntu" ]]; then
    docker_distribution_codename="$(_setup_read_os_release_field UBUNTU_CODENAME)"
    [[ -z "$docker_distribution_codename" ]] && docker_distribution_codename="$(_setup_read_os_release_field VERSION_CODENAME)"
  elif [[ "$docker_distribution_id" != "debian" ]]; then
    echo "Docker solo puede configurar repositorios oficiales para Ubuntu o Debian. Distribución detectada: ${docker_distribution_id:-desconocida}." >&2
    return 1
  fi

  if [[ -z "$docker_distribution_codename" ]]; then
    echo "No se pudo resolver el codename de la distribución para configurar Docker." >&2
    return 1
  fi

  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL "https://download.docker.com/linux/$docker_distribution_id/gpg" -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$docker_distribution_id \
    $docker_distribution_codename stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  install_docker_ce
  install_docker_ce_cli
  install_containerd_io
  install_docker_buildx_plugin
  install_docker_compose_plugin
  sleep 3
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files docker.service >/dev/null 2>&1; then
    sudo systemctl start docker.service
    sudo systemctl enable docker.service
  else
    echo "systemctl no está disponible; se omite la activación del servicio Docker."
  fi
  _setup_log_warning "Agregando '$USER' al grupo 'docker'. Esto otorga acceso equivalente a root al daemon Docker (montaje de '/' vía contenedores)."
  sudo usermod -aG docker "$USER"
  # NOTE: reboot
}

install_lazydocker() {
  _brew install lazydocker # https://formulae.brew.sh/formula/lazydocker
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
  local nvm_version installed_nvm_version temp_dir install_script

  nvm_version="$(_setup_resolve_github_latest_tag "nvm-sh" "nvm")"
  if [[ -z "$nvm_version" ]]; then
    echo "No se pudo resolver la última versión estable oficial de NVM." >&2
    return 1
  fi

  installed_nvm_version="$(_setup_installed_nvm_version)"
  if [[ "$installed_nvm_version" == "${nvm_version#v}" ]]; then
    echo "NVM ya está en la última versión estable oficial ($nvm_version)."
    return 0
  fi

  _setup_log_info "Instalando NVM $nvm_version, última versión estable oficial."
  temp_dir="$(_setup_create_temp_dir)"
  install_script="$temp_dir/nvm-install.sh"
  if ! curl -fsSLo "$install_script" "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  if ! bash "$install_script"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  _setup_remove_temp_dir "$temp_dir"
  installed_nvm_version="$(_setup_installed_nvm_version)"
  if [[ "$installed_nvm_version" != "${nvm_version#v}" ]]; then
    echo "NVM no quedó en la última versión estable oficial esperada ($nvm_version)." >&2
    return 1
  fi
}

_setup_fonts_install_dir() {
  if is_darwin; then
    printf "%s" "$HOME/Library/Fonts"
  else
    printf "%s" "$HOME/.fonts"
  fi
}

install_font() {
  is_windows && return

  local folder_name="$1"
  local zip_name="${folder_name}.zip"
  local url="$2"
  local expected_sha256="${3:-}"
  local temp_dir actual_sha256 fonts_dir
  fonts_dir="$(_setup_fonts_install_dir)"

  temp_dir="$(_setup_create_temp_dir)"
  if ! curl -fsSLo "$temp_dir/$zip_name" "$url"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi

  if [[ -n "$expected_sha256" ]]; then
    actual_sha256="$(_setup_compute_sha256 "$temp_dir/$zip_name")"
    if [[ -z "$actual_sha256" || "$actual_sha256" != "$expected_sha256" ]]; then
      echo "SHA256 inválido para $zip_name. Esperado: $expected_sha256, obtenido: ${actual_sha256:-vacío}." >&2
      _setup_remove_temp_dir "$temp_dir"
      return 1
    fi
  fi

  if ! _setup_zip_entries_are_safe "$temp_dir/$zip_name"; then
    echo "ZIP de fuente con entradas inseguras (path traversal o absoluta): $zip_name." >&2
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi

  mkdir -p "$fonts_dir"
  if ! unzip -j -o -q "$temp_dir/$zip_name" '*.ttf' -d "$fonts_dir"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi

  _setup_remove_temp_dir "$temp_dir"

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -fv >/dev/null
  fi
}

install_font_IosevkaTermCurly() {
  local iosevka_tag iosevka_version
  iosevka_tag="$(_setup_resolve_github_latest_tag "be5invis" "Iosevka")"
  if [[ -z "$iosevka_tag" ]]; then
    echo "No se pudo resolver la última versión estable oficial de Iosevka." >&2
    return 1
  fi
  iosevka_version="${iosevka_tag#v}"
  install_font \
    "IosevkaTermCurly" \
    "https://github.com/be5invis/Iosevka/releases/download/${iosevka_tag}/PkgTTF-IosevkaTermCurly-${iosevka_version}.zip"
}

install_espanso() {
  is_windows && return

  if is_darwin; then
    # https://espanso.org/docs/install/mac/#install-using-homebrew
    _brew install --cask espanso
    return 0
  fi

  echo "Espanso en Linux requiere instalación manual desde https://espanso.org/docs/install/linux/. Se omite." >&2
  return 0

  # NOTE: en macOS, ejecutar `espanso service register` y `espanso start` luego de la instalación.
}

_setup_resolve_go_platform() {
  local kernel machine os arch
  kernel="$(uname -s)"
  machine="$(uname -m)"

  case "$kernel" in
    Linux) os="linux" ;;
    Darwin) os="darwin" ;;
    *) return 1 ;;
  esac

  case "$machine" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) return 1 ;;
  esac

  printf "%s-%s" "$os" "$arch"
}

_setup_resolve_go_release_sha256() {
  local go_version=$1 file_name=$2
  curl -fsSL "https://go.dev/dl/?mode=json&include=all" |
    awk -v ver="go${go_version}" -v fname="$file_name" '
      $0 ~ "\"version\"" { in_block = ($0 ~ ver) ? 1 : 0; next }
      in_block && $0 ~ "\"filename\"" { match_file = ($0 ~ fname) ? 1 : 0 }
      match_file && $0 ~ "\"sha256\"" {
        gsub(/[",]/, "", $0); split($0, parts, ":"); print parts[2]; exit
      }
    ' | tr -d ' '
}

install_golang() {
  # https://go.dev/dl/
  local go_version installed_go_version go_platform file_name expected_sha256 actual_sha256 temp_dir

  go_version="$(_setup_resolve_latest_go_version)"
  if [ -z "$go_version" ]; then
    echo "No se pudo resolver la última versión estable oficial de Go desde go.dev." >&2
    return 1
  fi

  installed_go_version="$(_setup_installed_go_version)"
  if [[ "$installed_go_version" == "$go_version" ]]; then
    echo "Go ya está en la última versión estable oficial ($go_version)."
    return 0
  fi

  go_platform="$(_setup_resolve_go_platform)" || {
    echo "Plataforma no soportada para instalar Go: $(uname -s) $(uname -m)." >&2
    return 1
  }

  _setup_log_info "Instalando Go $go_version ($go_platform), última versión estable oficial."
  file_name="go${go_version}.${go_platform}.tar.gz"
  expected_sha256="$(_setup_resolve_go_release_sha256 "$go_version" "$file_name")"
  if [[ -z "$expected_sha256" ]]; then
    echo "No se pudo resolver el SHA256 oficial de $file_name desde go.dev." >&2
    return 1
  fi

  temp_dir="$(_setup_create_temp_dir)"
  if ! curl -fsSLo "$temp_dir/$file_name" "https://go.dev/dl/$file_name"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi

  actual_sha256="$(_setup_compute_sha256 "$temp_dir/$file_name")"
  if [[ -z "$actual_sha256" || "$actual_sha256" != "$expected_sha256" ]]; then
    echo "SHA256 inválido para $file_name. Esperado: $expected_sha256, obtenido: ${actual_sha256:-vacío}." >&2
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi

  if ! sudo rm -rf /usr/local/go || ! sudo tar -C /usr/local -xzf "$temp_dir/$file_name"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  _setup_remove_temp_dir "$temp_dir"
  installed_go_version="$(_setup_installed_go_version)"
  if [[ "$installed_go_version" != "$go_version" ]]; then
    echo "Go no quedó en la última versión estable oficial esperada ($go_version)." >&2
    return 1
  fi
}

_go() {
  /usr/local/go/bin/go "$@"
}

install_ghq() {
  _brew install ghq # https://formulae.brew.sh/formula/ghq

  mkdir -p "$HOME/ghq/work"
  mkdir -p "$HOME/ghq/projects"
}

install_vscode() {
  is_windows && return

  if is_ubuntu; then
    sudo snap install --classic code
  fi
}

install_font_jetbrains_mono_pkg() {
  is_darwin || return 0
  _brew install --cask font-jetbrains-mono
}
install_font_dejavu_pkg() {
  is_darwin || return 0
  _brew install --cask font-dejavu-sans-mono-nerd-font
}
install_font_cascadia_code_pkg() {
  is_darwin || return 0
  _brew install --cask font-cascadia-code
}

install_fonts() {
  is_windows && return

  if ! is_darwin; then
    echo "Las fuentes empaquetadas vía Homebrew Cask solo están disponibles en macOS. Se omite." >&2
    return 0
  fi

  install_font_jetbrains_mono_pkg
  install_font_dejavu_pkg
  install_font_cascadia_code_pkg
}

install_eza() {
  _brew install eza # https://formulae.brew.sh/formula/eza
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew ya está instalado; actualizando metadatos para resolver últimas versiones estables."
    brew update
    return 0
  fi

  local temp_dir install_script
  temp_dir="$(_setup_create_temp_dir)"
  install_script="$temp_dir/homebrew-install.sh"
  if ! curl -fsSLo "$install_script" "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  if ! NONINTERACTIVE=1 /bin/bash "$install_script"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  _setup_remove_temp_dir "$temp_dir"

  local brew_binary
  if is_darwin && [[ -x /opt/homebrew/bin/brew ]]; then
    brew_binary="/opt/homebrew/bin/brew"
  elif is_darwin && [[ -x /usr/local/bin/brew ]]; then
    brew_binary="/usr/local/bin/brew"
  elif [[ -x "$(_setup_default_linuxbrew_path)" ]]; then
    brew_binary="$(_setup_default_linuxbrew_path)"
  fi

  if [[ -n "${brew_binary:-}" ]]; then
    eval "$("$brew_binary" shellenv)"
  fi
}

_brew() {
  local brew_command=""

  if command -v brew >/dev/null 2>&1; then
    brew_command="$(command -v brew)"
  elif is_debian_like && [[ -x "$(_setup_default_linuxbrew_path)" ]]; then
    brew_command="$(_setup_default_linuxbrew_path)"
  elif is_darwin && [[ -x /opt/homebrew/bin/brew ]]; then
    brew_command="/opt/homebrew/bin/brew"
  elif is_darwin && [[ -x /usr/local/bin/brew ]]; then
    brew_command="/usr/local/bin/brew"
  else
    echo "Homebrew no está disponible para este comando de setup. Instalá Homebrew primero." >&2
    return 1
  fi

  "$brew_command" "$@"
}

_setup_default_linuxbrew_path() {
  printf "%s" "/home/linuxbrew/.linuxbrew/bin/brew"
}

install_fd_find() {
  _brew install fd
}

install_bash() {
  _brew install bash # https://formulae.brew.sh/formula/bash
}

install_xclip() {
  is_windows && return

  if is_debian_like; then
    sudo apt-get install -y xclip
  fi
}

install_git_filter_repo() {
  if is_debian_like; then
    sudo apt-get install -y git-filter-repo
  fi
}

install_git() {
  if is_debian_like; then
    sudo apt-get install -y git
  fi
}

install_gh() {
  _brew install gh # https://cli.github.com/
}

install_hunk() {
  _brew install modem-dev/tap/hunk
}

install_ghostty() {
  _brew install --cask ghostty # https://ghostty.org/
}

install_mcp_remote_proxy() {
  python3 -m pip install --user --upgrade --index-url https://pypi.artifacts.furycloud.io/simple/ mcp-remote-proxy
}

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    echo "Zsh ya está instalado; se omite la instalación del paquete."
  else
    _brew install zsh
  fi

  local desired_shell
  desired_shell="$(command -v zsh || true)"
  if [ -n "$desired_shell" ] && [ "$SHELL" != "$desired_shell" ]; then
    sudo chsh -s "$desired_shell" "$USER"
  fi
}

install_build_essential() { is_debian_like && sudo apt-get install -y build-essential; }
install_gcc() { if is_debian_like; then sudo apt-get install -y gcc; fi }
install_curl_pkg() { if is_debian_like; then sudo apt-get install -y curl; fi }
install_wget_pkg() { if is_debian_like; then sudo apt-get install -y wget; fi }
install_zip_pkg() { if is_debian_like; then sudo apt-get install -y zip; fi }
install_unzip_pkg() { if is_debian_like; then sudo apt-get install -y unzip; fi }
install_python3_venv() { is_debian_like && sudo apt-get install -y python3-venv; }

install_essentials() {
  install_build_essential
  install_gcc
  install_curl_pkg
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
  is_darwin || return

  _brew install grep # https://formulae.brew.sh/formula/grep (GNU grep provides ggrep)
  _brew link --overwrite grep
}

install_sdkman() {
  if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk selfupdate force || true
    sdk version || true
    return 0
  fi

  local temp_dir install_script
  temp_dir="$(_setup_create_temp_dir)"
  install_script="$temp_dir/sdkman-install.sh"
  if ! curl -fsSLo "$install_script" "https://get.sdkman.io"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  if ! bash "$install_script"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  _setup_remove_temp_dir "$temp_dir"
  if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk version || true
  else
    echo "ERROR: SDKMAN no se instaló correctamente."
  fi
}

install_yq() {
  _brew install yq # https://github.com/mikefarah/yq
}

install_win32yank() {
  ! is_windows && return

  local win32yank_version file_name url temp_dir
  win32yank_version="$(_setup_resolve_github_latest_tag "equalsraf" "win32yank")"
  if [[ -z "$win32yank_version" ]]; then
    echo "No se pudo resolver la última versión estable oficial de win32yank." >&2
    return 1
  fi

  file_name="win32yank-x64.zip"
  url="https://github.com/equalsraf/win32yank/releases/download/${win32yank_version}/${file_name}"
  temp_dir="$(_setup_create_temp_dir)"
  if ! curl -fsSLo "$temp_dir/$file_name" "$url"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  if ! _setup_zip_entries_are_safe "$temp_dir/$file_name"; then
    echo "ZIP de win32yank con entradas inseguras (path traversal o absoluta)." >&2
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  mkdir -p "$LOCAL_BINARIES"
  if ! unzip -j -o -q "$temp_dir/$file_name" 'win32yank.exe' -d "$LOCAL_BINARIES/" || ! chmod +x "$LOCAL_BINARIES/win32yank.exe"; then
    _setup_remove_temp_dir "$temp_dir"
    return 1
  fi
  _setup_remove_temp_dir "$temp_dir"
  if [[ ! -x "$LOCAL_BINARIES/win32yank.exe" ]]; then
    echo "win32yank no quedó instalado en $LOCAL_BINARIES/win32yank.exe." >&2
    return 1
  fi
}

_setup_create_temp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t setup
}

_setup_remove_temp_dir() {
  local temp_dir=$1
  [[ -n "$temp_dir" && -d "$temp_dir" ]] && rm -rf "$temp_dir"
}

_setup_compute_sha256() {
  local file_path=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{print $1}'
  else
    return 1
  fi
}

_setup_zip_entries_are_safe() {
  local zip_path=$1
  command -v unzip >/dev/null 2>&1 || return 1
  local entries
  entries="$(unzip -Z1 "$zip_path" 2>/dev/null)" || return 1
  local entry
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    case "$entry" in
      /*) return 1 ;;
      *..*) return 1 ;;
    esac
  done <<< "$entries"
  return 0
}

_setup_resolve_github_latest_tag() {
  local owner=$1 repository=$2 latest_release_url
  latest_release_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${owner}/${repository}/releases/latest")" || return 1
  printf "%s" "${latest_release_url##*/}"
}

_setup_resolve_latest_go_version() {
  curl -fsSL "https://go.dev/VERSION?m=text" | sed -n '1s/^go//p'
}

_setup_installed_go_version() {
  if [[ -x /usr/local/go/bin/go ]]; then
    /usr/local/go/bin/go version | awk '{print $3}' | sed 's/^go//'
  elif command -v go >/dev/null 2>&1; then
    go version | awk '{print $3}' | sed 's/^go//'
  fi
}

_setup_installed_nvm_version() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm --version
  fi
}

_is_setup_menu_item_recommended_for_platform() {
  local menu_item_id=$1
  local base_default_selected=$2
  local supported_platforms=${3:-all}
  local current_platform

  [[ "$base_default_selected" -eq 1 ]] || return 1
  _setup_platforms_include_current "$supported_platforms" || return 1
  current_platform="${_SETUP_PLATFORM_CACHE:-$(_setup_current_platform)}"

  # wsl: is_windows; darwin: is_darwin; linux: debian-like, not WSL nor macOS.
  case "$menu_item_id" in
    espanso)
      [[ "$current_platform" != "wsl" ]]
      ;;
    gnu_grep)
      [[ "$current_platform" == "darwin" ]]
      ;;
    xclip)
      [[ "$current_platform" == "linux" ]]
      ;;
    win32yank)
      [[ "$current_platform" == "wsl" ]]
      ;;
    *)
      return 0
      ;;
  esac
}

_append_menu_item_to_sorted_catalog() {
  local source_index=$1

  _SORTED_MENU_IDS+=("${_MENU_IDS[$source_index]}")
  _SORTED_MENU_LABELS+=("${_MENU_LABELS[$source_index]}")
  _SORTED_MENU_FUNCS+=("${_MENU_FUNCS[$source_index]}")
  _SORTED_MENU_DEFAULT_SELECTED+=("${_MENU_DEFAULT_SELECTED[$source_index]}")
  _SORTED_MENU_REQUIRES_ADMIN+=("${_MENU_REQUIRES_ADMIN[$source_index]}")
  _SORTED_MENU_PLATFORMS+=("${_MENU_PLATFORMS[$source_index]}")
  _SORTED_MENU_REQUIRES_RESTART+=("${_MENU_REQUIRES_RESTART[$source_index]}")
}

_sort_menu_catalog_by_default_selection() {
  local menu_index
  _SORTED_MENU_IDS=()
  _SORTED_MENU_LABELS=()
  _SORTED_MENU_FUNCS=()
  _SORTED_MENU_DEFAULT_SELECTED=()
  _SORTED_MENU_REQUIRES_ADMIN=()
  _SORTED_MENU_PLATFORMS=()
  _SORTED_MENU_REQUIRES_RESTART=()

  for menu_index in "${!_MENU_DEFAULT_SELECTED[@]}"; do
    if [[ ${_MENU_DEFAULT_SELECTED[$menu_index]} -eq 1 ]]; then
      _append_menu_item_to_sorted_catalog "$menu_index"
    fi
  done

  for menu_index in "${!_MENU_DEFAULT_SELECTED[@]}"; do
    if [[ ${_MENU_DEFAULT_SELECTED[$menu_index]} -eq 0 ]]; then
      _append_menu_item_to_sorted_catalog "$menu_index"
    fi
  done

  _MENU_IDS=("${_SORTED_MENU_IDS[@]}")
  _MENU_LABELS=("${_SORTED_MENU_LABELS[@]}")
  _MENU_FUNCS=("${_SORTED_MENU_FUNCS[@]}")
  _MENU_DEFAULT_SELECTED=("${_SORTED_MENU_DEFAULT_SELECTED[@]}")
  _MENU_REQUIRES_ADMIN=("${_SORTED_MENU_REQUIRES_ADMIN[@]}")
  _MENU_PLATFORMS=("${_SORTED_MENU_PLATFORMS[@]}")
  _MENU_REQUIRES_RESTART=("${_SORTED_MENU_REQUIRES_RESTART[@]}")
}

ensure_sudo() {
  command -v sudo >/dev/null 2>&1 || return
  if [ -z "${SUDO_KEEPALIVE_PID:-}" ]; then
    sudo -v
    local parent_pid=$$
    (
      while kill -0 "$parent_pid" 2>/dev/null; do
        sudo -n true 2>/dev/null || exit 0
        sleep 60
      done
    ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
  fi
}

# ─── Interactive Multi-Select Menu ───────────────────────────────────────────

_initialize_menu_catalog() {
  _MENU_IDS=()
  _MENU_LABELS=()
  _MENU_FUNCS=()
  _MENU_DEFAULT_SELECTED=()
  _MENU_REQUIRES_ADMIN=()
  _MENU_PLATFORMS=()
  _MENU_REQUIRES_RESTART=()

  if [[ ! -f "$SETUP_CATALOG_PATH" ]]; then
    echo "ERROR: No se encontró el catálogo de setup: $SETUP_CATALOG_PATH" >&2
    return 1
  fi

  local expected_catalog_header="Id|Label|BashFunctionName|PowerShellFunctionName|DefaultSelected|RequiresAdmin|Platforms|RequiresRestart"
  # Detect the platform once for the whole catalog; cleared at the end so later
  # calls (and tests that switch platforms) detect it again.
  _SETUP_PLATFORM_CACHE=""
  _SETUP_PLATFORM_CACHE="$(_setup_current_platform)"

  local id label bash_function_name power_shell_function_name default_selected requires_admin supported_platforms requires_restart function_name
  local catalog_header
  {
    IFS= read -r catalog_header
    if [[ "$catalog_header" != "$expected_catalog_header" ]]; then
      echo "ERROR: El catálogo de setup debe usar el encabezado común: $expected_catalog_header" >&2
      return 1
    fi
    while IFS='|' read -r id label bash_function_name power_shell_function_name default_selected requires_admin supported_platforms requires_restart; do
    [[ -z "$id" || "${id:0:1}" == "#" ]] && continue
    function_name="$bash_function_name"
    [[ -z "$function_name" ]] && continue
    requires_admin="${requires_admin:-0}"
    supported_platforms="${supported_platforms:-all}"
    requires_restart="${requires_restart:-0}"

    if ! _setup_platforms_include_current "$supported_platforms"; then
      continue
    fi

    _MENU_IDS+=("$id")
    _MENU_LABELS+=("$label")
    _MENU_FUNCS+=("$function_name")
    _MENU_REQUIRES_ADMIN+=("$requires_admin")
    _MENU_PLATFORMS+=("$supported_platforms")
    _MENU_REQUIRES_RESTART+=("$requires_restart")
    if _is_setup_menu_item_recommended_for_platform "$id" "$default_selected" "$supported_platforms"; then
      _MENU_DEFAULT_SELECTED+=("1")
    else
      _MENU_DEFAULT_SELECTED+=("0")
    fi
    done
  } < "$SETUP_CATALOG_PATH"

  _SETUP_PLATFORM_DISPLAY_NAME="$(_setup_platform_display_name)"
  _SETUP_PLATFORM_CACHE=""
  _sort_menu_catalog_by_default_selection
}

_reset_menu_selection_to_defaults() {
  _MENU_SELECTED=("${_MENU_DEFAULT_SELECTED[@]}")
}

_validate_menu_catalog() {
  local ids_count=${#_MENU_IDS[@]}
  local labels_count=${#_MENU_LABELS[@]}
  local funcs_count=${#_MENU_FUNCS[@]}
  local defaults_count=${#_MENU_DEFAULT_SELECTED[@]}
  local admin_count=${#_MENU_REQUIRES_ADMIN[@]}
  local platforms_count=${#_MENU_PLATFORMS[@]}
  local restart_count=${#_MENU_REQUIRES_RESTART[@]}

  if ((ids_count != labels_count || labels_count != funcs_count || labels_count != defaults_count || labels_count != admin_count || labels_count != platforms_count || labels_count != restart_count)); then
    echo "ERROR: El catálogo del menú tiene longitudes inconsistentes." >&2
    return 1
  fi

  local found_non_default=0
  local menu_index platform_token
  local -a setup_validation_platform_tokens
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

    if [[ "${_MENU_REQUIRES_ADMIN[$menu_index]}" != "0" && "${_MENU_REQUIRES_ADMIN[$menu_index]}" != "1" ]]; then
      echo "ERROR: RequiresAdmin debe ser 0 o 1 para '${_MENU_LABELS[$menu_index]}'." >&2
      return 1
    fi

    if [[ "${_MENU_REQUIRES_RESTART[$menu_index]}" != "0" && "${_MENU_REQUIRES_RESTART[$menu_index]}" != "1" ]]; then
      echo "ERROR: RequiresRestart debe ser 0 o 1 para '${_MENU_LABELS[$menu_index]}'." >&2
      return 1
    fi

    IFS=',' read -ra setup_validation_platform_tokens <<< "${_MENU_PLATFORMS[$menu_index]:-all}"
    for platform_token in "${setup_validation_platform_tokens[@]}"; do
      if ! _setup_platform_token_is_supported "$platform_token"; then
        echo "ERROR: Plataforma no soportada '$platform_token' para '${_MENU_LABELS[$menu_index]}'." >&2
        return 1
      fi
    done
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

# Echoes the matching index and returns 0 on match.
# On miss, returns 1 and echoes "-1" so callers using $(...) never receive
# an empty string that bash would silently interpret as index 0.
_find_menu_function_index() {
  local function_name=$1
  local menu_index

  for menu_index in "${!_MENU_FUNCS[@]}"; do
    if [[ "${_MENU_FUNCS[$menu_index]}" == "$function_name" ]]; then
      echo "$menu_index"
      return 0
    fi
  done

  echo "-1"
  return 1
}

# Echoes the matching index and returns 0 on match.
# On miss, returns 1 and echoes "-1" so callers using $(...) never receive
# an empty string that bash would silently interpret as index 0.
_find_menu_item_index() {
  local item_identifier=$1
  local menu_index

  for menu_index in "${!_MENU_FUNCS[@]}"; do
    if [[ "${_MENU_FUNCS[$menu_index]}" == "$item_identifier" || "${_MENU_IDS[$menu_index]}" == "$item_identifier" ]]; then
      echo "$menu_index"
      return 0
    fi
  done

  echo "-1"
  return 1
}

_menu_selection_requires_sudo() {
  local menu_index

  for menu_index in "${!_MENU_SELECTED[@]}"; do
    if [[ "${_MENU_SELECTED[$menu_index]}" -eq 1 && "${_MENU_REQUIRES_ADMIN[$menu_index]}" -eq 1 ]]; then
      return 0
    fi
  done

  return 1
}

_menu_indexes_require_sudo() {
  local menu_index

  for menu_index in "$@"; do
    if [[ "${_MENU_REQUIRES_ADMIN[$menu_index]}" -eq 1 ]]; then
      return 0
    fi
  done

  return 1
}

_install_results_require_restart() {
  local result_index
  for result_index in "${!_INSTALL_RESULT_LABELS[@]}"; do
    if [[ "${_INSTALL_RESULT_REQUIRES_RESTART[$result_index]}" -eq 1 && "${_INSTALL_RESULT_STATUSES[$result_index]}" == "ok" ]]; then
      return 0
    fi
  done
  return 1
}

_menu_selected_count() {
  local selected_count=0
  local selection_state

  for selection_state in "${_MENU_SELECTED[@]}"; do
    ((selection_state == 1)) && selected_count=$((selected_count + 1))
  done

  echo "$selected_count"
}

_record_install_result() {
  local menu_index=$1 status=$2 duration_seconds=$3 requires_restart=$4
  _INSTALL_RESULT_LABELS+=("${_MENU_LABELS[$menu_index]}")
  _INSTALL_RESULT_STATUSES+=("$status")
  _INSTALL_RESULT_DURATIONS+=("$duration_seconds")
  _INSTALL_RESULT_REQUIRES_RESTART+=("$requires_restart")
}

# Runs each selected item inside its own frame. Installer output is shown raw
# (it may prompt for sudo), so there is no spinner around it.
_run_selected_menu_items() {
  local dry_run=${1:-0}
  local menu_index
  local total_selected current_position=0
  total_selected="$(_menu_selected_count)"
  _INSTALL_RESULT_LABELS=()
  _INSTALL_RESULT_STATUSES=()
  _INSTALL_RESULT_DURATIONS=()
  _INSTALL_RESULT_REQUIRES_RESTART=()
  SETUP_RUN_STARTED_AT_SECONDS=$(date +%s)

  if [[ $dry_run -eq 1 ]]; then
    printf "\n"
    _setup_box_top "${SETUP_ICON_DRY_RUN:+$SETUP_ICON_DRY_RUN }Simulación"
  fi

  for menu_index in "${!_MENU_FUNCS[@]}"; do
    [[ ${_MENU_SELECTED[$menu_index]} -eq 1 ]] || continue
    current_position=$((current_position + 1))
    local label="${_MENU_LABELS[$menu_index]}"
    local position_text="[$current_position/$total_selected]"

    if [[ $dry_run -eq 1 ]]; then
      _setup_box_row "$(_setup_color "gray" "$position_text") se ejecutaría $label$(_menu_item_badges "$menu_index")"
      _record_install_result "$menu_index" "dry-run" 0 "${_MENU_REQUIRES_RESTART[$menu_index]}"
      continue
    fi

    if ! _setup_platforms_include_current "${_MENU_PLATFORMS[$menu_index]}"; then
      printf "\n"
      _setup_box_close "${SETUP_ICON_SKIPPED:+$SETUP_ICON_SKIPPED }$position_text $label omitido por plataforma"
      _record_install_result "$menu_index" "omitido" 0 0
      continue
    fi

    printf "\n"
    _setup_box_top "${SETUP_ICON_PACKAGE:+$SETUP_ICON_PACKAGE }$position_text $label"
    local item_started_at_seconds duration_seconds
    item_started_at_seconds=$(date +%s)
    if ${_MENU_FUNCS[$menu_index]}; then
      duration_seconds=$(($(date +%s) - item_started_at_seconds))
      _setup_box_close "$(styleText -c green -b -- "${SETUP_ICON_OK:+$SETUP_ICON_OK }$label listo") $(_setup_color "gray" "$SETUP_SEPARATOR ${SETUP_ICON_TIME:+$SETUP_ICON_TIME }$(_setup_format_duration "$duration_seconds")")"
      _record_install_result "$menu_index" "ok" "$duration_seconds" "${_MENU_REQUIRES_RESTART[$menu_index]}"
    else
      duration_seconds=$(($(date +%s) - item_started_at_seconds))
      _setup_box_close "$(styleText -c red -b -- "${SETUP_ICON_FAILED_ITEM:+$SETUP_ICON_FAILED_ITEM }$label falló") $(_setup_color "gray" "$SETUP_SEPARATOR ${SETUP_ICON_TIME:+$SETUP_ICON_TIME }$(_setup_format_duration "$duration_seconds")")" >&2
      _record_install_result "$menu_index" "falló" "$duration_seconds" 0
    fi
  done

  if [[ $dry_run -eq 1 ]]; then
    _setup_box_bottom
  fi
}

_print_install_summary() {
  local result_index status label duration_text
  local ok_count=0 failed_count=0 skipped_count=0 dry_run_count=0
  local total_seconds=$(($(date +%s) - ${SETUP_RUN_STARTED_AT_SECONDS:-$(date +%s)}))

  printf "\n"
  _setup_box_top "${SETUP_ICON_SUMMARY:+$SETUP_ICON_SUMMARY }Resumen"
  for result_index in "${!_INSTALL_RESULT_LABELS[@]}"; do
    status="${_INSTALL_RESULT_STATUSES[$result_index]}"
    # The simulation box already listed every item.
    if [[ "$status" == "dry-run" ]]; then
      dry_run_count=$((dry_run_count + 1))
      continue
    fi
    label="$(printf "%-${SETUP_SUMMARY_LABEL_WIDTH}s" "${_INSTALL_RESULT_LABELS[$result_index]}")"
    duration_text="$(_setup_format_duration "${_INSTALL_RESULT_DURATIONS[$result_index]:-0}")"
    case "$status" in
      ok)
        ok_count=$((ok_count + 1))
        _setup_box_row "${SETUP_ICON_OK:+$SETUP_ICON_OK }$(_setup_color "green" "$label") $(_setup_color "gray" "$duration_text")"
        ;;
      omitido)
        skipped_count=$((skipped_count + 1))
        _setup_box_row "${SETUP_ICON_SKIPPED:+$SETUP_ICON_SKIPPED }$(_setup_color "yellow" "$label") $(_setup_color "gray" "omitido por plataforma")"
        ;;
      *)
        failed_count=$((failed_count + 1))
        _setup_box_row "${SETUP_ICON_FAILED_ITEM:+$SETUP_ICON_FAILED_ITEM }$(_setup_color "red" "$label") $(_setup_color "gray" "$duration_text")"
        ;;
    esac
  done

  _setup_box_divider
  if ((dry_run_count > 0)); then
    _setup_box_row "${SETUP_ICON_DRY_RUN:+$SETUP_ICON_DRY_RUN }$dry_run_count en simulación $SETUP_SEPARATOR no se instaló nada"
  else
    _setup_box_row "${SETUP_ICON_OK:+$SETUP_ICON_OK }$ok_count ok $SETUP_SEPARATOR ${SETUP_ICON_FAILED_ITEM:+$SETUP_ICON_FAILED_ITEM }$failed_count fallaron $SETUP_SEPARATOR ${SETUP_ICON_SKIPPED:+$SETUP_ICON_SKIPPED }$skipped_count omitidos $SETUP_SEPARATOR ${SETUP_ICON_TIME:+$SETUP_ICON_TIME }$(_setup_format_duration "$total_seconds")"
  fi
  if _install_results_require_restart; then
    _setup_box_row "$(styleText -c yellow -b -- "${SETUP_ICON_RESTART:+$SETUP_ICON_RESTART }Algunos cambios requieren reiniciar o abrir una nueva sesión para aplicarse.")"
  fi
  if ((failed_count > 0)); then
    _setup_box_row "$(styleText -c red -b -- "${SETUP_ICON_FAILED_RUN:+$SETUP_ICON_FAILED_RUN }Proceso con $failed_count error(es).")"
  else
    _setup_box_row "$(styleText -c green -b -- "${SETUP_ICON_DONE:+$SETUP_ICON_DONE }Proceso completo.")"
  fi
  _setup_box_bottom
}

_setup_install_results_include_failure() {
  local result_status

  for result_status in "${_INSTALL_RESULT_STATUSES[@]}"; do
    if [[ "$result_status" == "falló" ]]; then
      return 0
    fi
  done

  return 1
}

_menu_is_recommended() {
  local menu_index=$1
  [[ ${_MENU_DEFAULT_SELECTED[$menu_index]} -eq 1 ]]
}

_menu_display_label() {
  local menu_index=$1
  local label="${_MENU_LABELS[$menu_index]}"

  if ! _menu_is_recommended "$menu_index"; then
    printf "  %s%s" "$label" "$(_menu_item_badges "$menu_index")"
    return 0
  fi

  printf "%s %s%s" "$SETUP_ICON_RECOMMENDED" "$label" "$(_menu_item_badges "$menu_index")"
}

# Label padded to the label column, followed by right-side tags. Unselected
# items are dimmed so the selection is readable at a glance.
_draw_menu_label() {
  local menu_index=$1
  local is_cursor=${2:-0}
  local is_selected=${3:-1}
  local label="${_MENU_LABELS[$menu_index]}"
  local label_style="default"
  [[ $is_selected -ne 1 ]] && label_style="dimmed"
  [[ $is_cursor -eq 1 ]] && label_style="cursor"

  # Discreet star so recommended items stay visible whatever the selection.
  if _menu_is_recommended "$menu_index"; then
    _setup_color "gray" "$SETUP_ICON_RECOMMENDED"
    printf " "
  else
    printf "  "
  fi
  _draw_menu_label_text "$label" "$label_style" "${_MENU_LOWERCASE_LABELS[$menu_index]:-}"
  _menu_load_item_tags "$menu_index"
  if [[ -n "$_SETUP_MENU_TAGS" ]]; then
    local label_column=${_SETUP_MENU_LABEL_COLUMN:-$SETUP_MENU_MAX_LABEL_COLUMN}
    local padding=$((label_column - ${#label} + 2))
    ((padding < 2)) && padding=2
    printf "%*s%s" "$padding" "" "$_SETUP_MENU_TAGS"
  fi
}

# Right-side tags: sudo and restart requirements.
_menu_load_item_tags() {
  local menu_index=$1
  _SETUP_MENU_TAGS=""
  if [[ "${_MENU_REQUIRES_ADMIN[$menu_index]:-0}" == "1" ]]; then
    _SETUP_MENU_TAGS+="$(styleText -c yellow -- "${SETUP_ICON_ADMIN:+$SETUP_ICON_ADMIN }sudo")  "
  fi
  if [[ "${_MENU_REQUIRES_RESTART[$menu_index]:-0}" == "1" ]]; then
    _SETUP_MENU_TAGS+="$(styleText -c blue -- "${SETUP_ICON_RESTART:+$SETUP_ICON_RESTART }reinicio")  "
  fi
  _SETUP_MENU_TAGS="${_SETUP_MENU_TAGS%  }"
  return 0
}

# Width of the label column: longest label, capped.
_menu_load_label_column() {
  local label longest=0
  for label in "${_MENU_LABELS[@]}"; do
    ((${#label} > longest)) && longest=${#label}
  done
  ((longest > SETUP_MENU_MAX_LABEL_COLUMN)) && longest=$SETUP_MENU_MAX_LABEL_COLUMN
  _SETUP_MENU_LABEL_COLUMN=$longest
}

# Prints the label, highlighting the part that matches the active search query
# (_SETUP_MENU_HIGHLIGHT_QUERY, lowercase) in underlined yellow.
_draw_menu_label_text() {
  local label=$1 label_style=$2 lowercase_label=${3:-}
  local query="${_SETUP_MENU_HIGHLIGHT_QUERY:-}"

  if [[ -z "$query" ]]; then
    _draw_menu_label_segment "$label_style" "$label"
    return 0
  fi

  if [[ -z "$lowercase_label" ]]; then
    lowercase_label="$(printf "%s" "$label" | tr '[:upper:]' '[:lower:]')"
  fi
  if [[ "$lowercase_label" != *"$query"* ]]; then
    _draw_menu_label_segment "$label_style" "$label"
    return 0
  fi

  local match_prefix="${lowercase_label%%"$query"*}"
  local match_start=${#match_prefix}
  local match_length=${#query}
  _draw_menu_label_segment "$label_style" "${label:0:$match_start}"
  styleText -c yellow -b -u -- "${label:$match_start:$match_length}"
  _draw_menu_label_segment "$label_style" "${label:$((match_start + match_length))}"
}

_draw_menu_label_segment() {
  local label_style=$1 text=$2
  [[ -z "$text" ]] && return 0
  case "$label_style" in
    cursor) _setup_color_bold "cyan" "$text" ;;
    dimmed) _setup_color "gray" "$text" ;;
    *) printf "%s" "$text" ;;
  esac
}

# Draws one menu row: scrollbar, cursor pointer, checkbox and label.
_draw_menu_item() {
  local idx=$1 cursor=$2 label=$3 is_selected=$4 scrollbar_glyph=${5:- }

  printf "%s " "$scrollbar_glyph"
  if [[ $idx -ne $cursor ]]; then
    _draw_menu_item_content "$idx" 0 "$is_selected"
    return 0
  fi

  _setup_highlight_row "$(_draw_menu_item_content "$idx" 1 "$is_selected")"
}

_draw_menu_item_content() {
  local idx=$1 is_cursor=$2 is_selected=$3
  local pointer="$SETUP_POINTER_BLANK"
  [[ $is_cursor -eq 1 ]] && pointer="$SETUP_ICON_POINTER"

  printf "%s " "$pointer"
  if [[ $is_selected -eq 1 ]]; then
    _setup_color "green" "$SETUP_ICON_CHECKED"
  else
    _setup_color "gray" "$SETUP_ICON_UNCHECKED"
  fi
  printf "  "
  _draw_menu_label "$idx" "$is_cursor" "$is_selected"
}

# Paints a whole row with the cursor background. Every style reset inside the
# row re-applies the background, and the row is padded to a fixed width.
_setup_highlight_row() {
  local row=$1
  local reset=$'\033[m'
  local ansi_pattern=$'\033\\[[0-9;]*m'
  local plain_row=$row
  while [[ $plain_row =~ $ansi_pattern ]]; do
    plain_row=${plain_row/"${BASH_REMATCH[0]}"/}
  done

  local visible_columns=${#plain_row}

  local padding=$((SETUP_MENU_HIGHLIGHT_WIDTH - visible_columns))
  ((padding < 1)) && padding=1
  # styleText escapes start with ";" (an implicit reset that clears the
  # background), so the background is injected into every escape too.
  local style_start=$'\033[;'
  local style_start_with_background="$style_start$SETUP_MENU_CURSOR_BACKGROUND_CODE;"
  local styled_row="${row//$reset/$reset$SETUP_MENU_CURSOR_BACKGROUND}"
  styled_row="${styled_row//$style_start/$style_start_with_background}"
  printf "%s%s%*s%s" "$SETUP_MENU_CURSOR_BACKGROUND" "$styled_row" "$padding" "" "$reset"
}

# Reads the real terminal height. `tput lines` inside $(...) has no terminal on
# stdout/stderr and falls back to 24 rows, so ask the controlling tty first.
_setup_tty_size() {
  { stty size </dev/tty; } 2>/dev/null
}

_setup_terminal_rows() {
  local terminal_size terminal_rows
  terminal_size="$(_setup_tty_size)"
  terminal_rows="${terminal_size%% *}"
  if [[ "$terminal_rows" =~ ^[0-9]+$ ]] && ((terminal_rows > 0)); then
    echo "$terminal_rows"
    return 0
  fi

  terminal_rows="$({ tput lines 2>/dev/tty; } 2>/dev/null)"
  if [[ "$terminal_rows" =~ ^[0-9]+$ ]] && ((terminal_rows > 0)); then
    echo "$terminal_rows"
    return 0
  fi

  echo "${LINES:-$SETUP_DEFAULT_TERMINAL_ROWS}"
}

# Fills the viewport down to its last line; the list scrolls when it is taller.
_menu_visible_height() {
  local terminal_rows
  terminal_rows="$(_setup_terminal_rows)"

  local visible_height=$((terminal_rows - SETUP_MENU_RESERVED_LINES))
  if ((visible_height < SETUP_MENU_MIN_VISIBLE_ITEMS)); then
    visible_height=$SETUP_MENU_MIN_VISIBLE_ITEMS
  fi

  if ((visible_height > ${#_MENU_LABELS[@]})); then
    visible_height=${#_MENU_LABELS[@]}
  fi

  echo "$visible_height"
}

# Scrollbar glyph for a visible row: thumb where the window sits, track
# elsewhere, blank when the whole list fits.
# Sets _SETUP_MENU_SCROLLBAR_GLYPH for a visible row without a subshell: thumb
# where the window sits, track elsewhere, blank when the whole list fits.
_menu_load_scrollbar_glyph() {
  local row_position=$1 window_start=$2 visible_height=$3 count=$4
  _SETUP_MENU_SCROLLBAR_GLYPH=" "

  if ((count <= visible_height || visible_height <= 0)); then
    return 0
  fi

  local thumb_size=$((visible_height * visible_height / count))
  if ((thumb_size < 1)); then
    thumb_size=1
  fi
  local max_window_start=$((count - visible_height))
  local thumb_start=$((window_start * (visible_height - thumb_size) / max_window_start))

  if ((row_position >= thumb_start && row_position < thumb_start + thumb_size)); then
    _SETUP_MENU_SCROLLBAR_GLYPH="$SETUP_MENU_SCROLLBAR_THUMB"
  else
    _SETUP_MENU_SCROLLBAR_GLYPH="$SETUP_MENU_SCROLLBAR_TRACK"
  fi
}

_menu_scrollbar_glyph() {
  _menu_load_scrollbar_glyph "$@"
  printf "%s" "$_SETUP_MENU_SCROLLBAR_GLYPH"
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
  _menu_load_label_column

  local selected_count=0 selection_state
  for selection_state in "${_MENU_SELECTED[@]}"; do
    [[ "$selection_state" == "1" ]] && selected_count=$((selected_count + 1))
  done
  local filled_width=0
  ((count > 0)) && filled_width=$((selected_count * SETUP_MENU_SELECTION_BAR_WIDTH / count))

  printf "\r\033[2K"
  _setup_box_top "${SETUP_ICON_CATALOG:+$SETUP_ICON_CATALOG }Paquetes $SETUP_SEPARATOR ${_SETUP_PLATFORM_DISPLAY_NAME:-$(_setup_platform_display_name)}"
  printf "\r\033[2K"
  _setup_box_row "${SETUP_ICON_SELECTED:+$SETUP_ICON_SELECTED }$(_setup_color "cyan" "$selected_count") de $count seleccionados  $(_setup_color "green" "$(_setup_repeat_text "$SETUP_BAR_FILLED" "$filled_width")")$(_setup_color "gray" "$(_setup_repeat_text "$SETUP_BAR_EMPTY" $((SETUP_MENU_SELECTION_BAR_WIDTH - filled_width)))")  $(_setup_color "gray" "$SETUP_SEPARATOR mostrando $((window_start + 1))-$window_end")"
  printf "\r\033[2K"
  _setup_box_bottom

  if ((window_start > 0)); then
    printf "\r\033[2K  %s\n" "$(_setup_color "gray" "$SETUP_ARROW_UP Hay más elementos arriba")"
  else
    printf "\r\033[2K\n"
  fi

  local menu_index
  for ((menu_index = window_start; menu_index < window_end; menu_index++)); do
    printf "\r\033[2K"
    _menu_load_scrollbar_glyph $((menu_index - window_start)) "$window_start" "$visible_height" "$count"
    _draw_menu_item "$menu_index" "$cursor" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}" "$_SETUP_MENU_SCROLLBAR_GLYPH"
    printf "\n"
  done

  if ((window_end < count)); then
    printf "\r\033[2K  %s\n" "$(_setup_color "gray" "$SETUP_ARROW_DOWN Hay más elementos abajo")"
  else
    printf "\r\033[2K\n"
  fi
  _draw_menu_details_line "$cursor"
}

# Details of the item under the cursor: id, function, platforms and whether it
# is recommended.
_draw_menu_details_line() {
  local menu_index=$1
  local platforms="${_MENU_PLATFORMS[$menu_index]:-all}"
  [[ "$platforms" == "all" ]] && platforms="todas las plataformas"
  local recommendation="opcional"
  _menu_is_recommended "$menu_index" && recommendation="$SETUP_ICON_RECOMMENDED recomendado"
  printf "\r\033[2K  %s\n" "$(_setup_color "gray" "${SETUP_ICON_INFO:+$SETUP_ICON_INFO }${_MENU_IDS[$menu_index]:-} $SETUP_SEPARATOR ${_MENU_FUNCS[$menu_index]:-} $SETUP_SEPARATOR ${platforms//,/, } $SETUP_SEPARATOR $recommendation")"
}

_menu_item_row_offset() {
  local menu_index=$1 window_start=$2
  echo $((SETUP_MENU_HEADER_LINES + menu_index - window_start))
}

_draw_menu_item_line() {
  local menu_index=$1 cursor=$2 window_start=${3:-0} visible_height=${4:-0}
  printf "\r\033[2K"
  _menu_load_scrollbar_glyph $((menu_index - window_start)) "$window_start" "$visible_height" "${#_MENU_LABELS[@]}"
  _draw_menu_item "$menu_index" "$cursor" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}" "$_SETUP_MENU_SCROLLBAR_GLYPH"
}

_redraw_menu_item_from_bottom() {
  local menu_index=$1 cursor=$2 window_start=$3 rendered_lines=$4
  local row_offset lines_up
  row_offset="$(_menu_item_row_offset "$menu_index" "$window_start")"
  lines_up=$((rendered_lines - row_offset))

  printf "\033[%dA" "$lines_up"
  _draw_menu_item_line "$menu_index" "$cursor" "$window_start" $((rendered_lines - SETUP_MENU_HEADER_LINES - SETUP_MENU_FOOTER_LINES))
  printf "\033[%dB\r" "$lines_up"
}

_redraw_full_menu_window() {
  local previous_rendered_lines=$1
  shift
  printf "\033[%dA" "$previous_rendered_lines"
  _draw_menu_window "$@"
}

_redraw_cursor_move() {
  local previous_cursor=$1 cursor=$2 window_start=$3 rendered_lines=$4
  _redraw_menu_item_from_bottom "$previous_cursor" "$cursor" "$window_start" "$rendered_lines"
  _redraw_menu_item_from_bottom "$cursor" "$cursor" "$window_start" "$rendered_lines"
  # The details line is the last rendered line, right above the resting cursor.
  printf "\033[1A"
  _draw_menu_details_line "$cursor"
}

_menu_requires_full_render() {
  local previous_window_start=$1 window_start=$2 previous_visible_height=$3 visible_height=$4 force_full_render=$5
  [[ "$force_full_render" -eq 1 || "$previous_window_start" -ne "$window_start" || "$previous_visible_height" -ne "$visible_height" ]]
}

_find_menu_item_index_by_label() {
  local query=$1 start_index=$2 count=$3

  if [[ -z "$query" ]]; then
    echo "$start_index"
    return
  fi

  local offset candidate_index
  _menu_load_lowercase_labels "$query"
  for ((offset = 1; offset <= count; offset++)); do
    candidate_index=$(((start_index + offset) % count))
    if [[ "${_MENU_LOWERCASE_LABELS[$candidate_index]}" == *"$_MENU_LOWERCASE_QUERY"* ]]; then
      echo "$candidate_index"
      return
    fi
  done

  echo "$start_index"
}

# Lowercases the query and every label with a single tr call (bash 3.2 has no
# ${var,,}), instead of one process per label on each key press.
# Lowercases labels once per catalog (bash 3.2 has no ${var,,}) and only the
# query on each key press, instead of one process per label.
_menu_load_lowercase_labels() {
  local query=$1
  local labels_signature="${#_MENU_LABELS[@]}|${_MENU_LABELS[*]}"

  if [[ "${_MENU_LOWERCASE_LABELS_SIGNATURE:-}" != "$labels_signature" ]]; then
    local lowercase_labels
    lowercase_labels="$(printf "%s\n" "${_MENU_LABELS[@]}" | tr '[:upper:]' '[:lower:]')"
    _MENU_LOWERCASE_LABELS=()
    IFS=$'\n' read -r -d '' -a _MENU_LOWERCASE_LABELS <<< "$lowercase_labels" || true
    _MENU_LOWERCASE_LABELS_SIGNATURE="$labels_signature"
  fi

  _MENU_LOWERCASE_QUERY=""
  if [[ -n "$query" ]]; then
    _MENU_LOWERCASE_QUERY="$(printf "%s" "$query" | tr '[:upper:]' '[:lower:]')"
  fi
}

_filter_menu_indexes() {
  local query=$1 count=$2
  local menu_index

  _FILTERED_MENU_INDEXES=()
  _menu_load_lowercase_labels "$query"

  for ((menu_index = 0; menu_index < count; menu_index++)); do
    if [[ -z "$_MENU_LOWERCASE_QUERY" || "${_MENU_LOWERCASE_LABELS[$menu_index]}" == *"$_MENU_LOWERCASE_QUERY"* ]]; then
      _FILTERED_MENU_INDEXES+=("$menu_index")
    fi
  done
}

# Search screen: an input box with prompt, cursor and match counter, a single
# hint line, and the filtered results with the same rows as the main menu.
_draw_search_window() {
  local query=$1 filtered_cursor=$2 visible_height=$3
  local filtered_count=${#_FILTERED_MENU_INDEXES[@]}
  local total_count=${#_MENU_LABELS[@]}
  local visible_count=$visible_height

  if ((visible_count > filtered_count)); then
    visible_count=$filtered_count
  fi

  local search_window_start=0
  if ((filtered_count > 0)); then
    search_window_start="$(_menu_adjust_window_start "$filtered_cursor" 0 "$visible_count" "$filtered_count")"
  fi

  local input_text search_placeholder="escribí para filtrar$SETUP_ELLIPSIS"
  if [[ -z "$query" ]]; then
    input_text="$(_setup_color "cyan" "$SETUP_SEARCH_CURSOR")$(_setup_color "gray" "$search_placeholder")"
  else
    input_text="$(styleText -b -- "$query")$(_setup_color "cyan" "$SETUP_SEARCH_CURSOR")"
  fi
  local counter_text="$filtered_count de $total_count"
  local input_padding=$((SETUP_BOX_RULE_WIDTH - ${#query} - ${#counter_text} - 6))
  [[ -z "$query" ]] && input_padding=$((input_padding - ${#search_placeholder}))
  ((input_padding < 1)) && input_padding=1

  printf "\r\033[2K"
  _setup_box_top "${SETUP_ICON_SEARCH:+$SETUP_ICON_SEARCH }Buscar paquetes"
  printf "\r\033[2K"
  _setup_box_row "$(styleText -c magenta -b -- "$SETUP_SEARCH_PROMPT") $input_text$(printf "%*s" "$input_padding" "")$(_setup_color "gray" "$counter_text")"
  printf "\r\033[2K"
  _setup_box_bottom
  printf "\r\033[2K  %s %s  %s %s  %s %s  %s %s\n" \
    "$(_setup_color "cyan" "$SETUP_ARROW_UP/$SETUP_ARROW_DOWN")" "$(_setup_color "gray" "mover")" \
    "$(_setup_color "cyan" "ESPACIO")" "$(_setup_color "gray" "alternar")" \
    "$(_setup_color "cyan" "ENTER")" "$(_setup_color "gray" "volver")" \
    "$(_setup_color "cyan" "ESC")" "$(_setup_color "gray" "cancelar")"
  printf "\r\033[2K\n"

  if ((filtered_count == 0)); then
    printf "\r\033[2K  %s Sin coincidencias para $SETUP_QUOTE_OPEN%s$SETUP_QUOTE_CLOSE\n" "$SETUP_ICON_NO_RESULTS" "$query"
    printf "\r\033[2K  %s\n" "$(_setup_color "gray" "Probá con menos letras o parte del nombre.")"
    local empty_line
    for ((empty_line = 2; empty_line < visible_height; empty_line++)); do
      printf "\r\033[2K\n"
    done
    return
  fi

  _SETUP_MENU_HIGHLIGHT_QUERY="$_MENU_LOWERCASE_QUERY"
  local visible_index menu_index
  for ((visible_index = search_window_start; visible_index < search_window_start + visible_count; visible_index++)); do
    menu_index=${_FILTERED_MENU_INDEXES[$visible_index]}
    local row_cursor=-1
    ((visible_index == filtered_cursor)) && row_cursor=$menu_index
    _menu_load_scrollbar_glyph $((visible_index - search_window_start)) "$search_window_start" "$visible_count" "$filtered_count"
    printf "\r\033[2K"
    _draw_menu_item "$menu_index" "$row_cursor" "${_MENU_LABELS[$menu_index]}" "${_MENU_SELECTED[$menu_index]}" "$_SETUP_MENU_SCROLLBAR_GLYPH"
    printf "\n"
  done
  _SETUP_MENU_HIGHLIGHT_QUERY=""

  local empty_line
  for ((empty_line = visible_count; empty_line < visible_height; empty_line++)); do
    printf "\r\033[2K\n"
  done
}

# Whole search screen in one frame: cursor home, content, clear the rest.
# Whole search screen in one frame: cursor home, content, clear the rest.
_draw_search_screen() {
  printf "\033[H\033[2K\n"
  _draw_search_window "$@"
  printf "\033[J"
}

_search_menu_incrementally() {
  local cursor=$1 visible_height=$2 count=$3
  local query=""
  local filtered_cursor=0
  _SEARCH_MENU_CURSOR_RESULT="$cursor"

  _filter_menu_indexes "$query" "$count"

  clear
  while true; do
    _setup_write_buffered _draw_search_screen "$query" "$filtered_cursor" "$visible_height"

    local key
    key="$(_read_search_key)"

    case "$key" in
      UP)
        ((filtered_cursor > 0)) && ((filtered_cursor--))
        ;;
      DOWN)
        ((filtered_cursor < ${#_FILTERED_MENU_INDEXES[@]} - 1)) && ((filtered_cursor++))
        ;;
      HOME)
        filtered_cursor=0
        ;;
      END)
        filtered_cursor=$((${#_FILTERED_MENU_INDEXES[@]} - 1))
        ((filtered_cursor < 0)) && filtered_cursor=0
        ;;
      PAGE_UP)
        filtered_cursor=$((filtered_cursor - visible_height))
        ((filtered_cursor < 0)) && filtered_cursor=0
        ;;
      PAGE_DOWN)
        filtered_cursor=$((filtered_cursor + visible_height))
        ((filtered_cursor > ${#_FILTERED_MENU_INDEXES[@]} - 1)) && filtered_cursor=$((${#_FILTERED_MENU_INDEXES[@]} - 1))
        ((filtered_cursor < 0)) && filtered_cursor=0
        ;;
      ENTER)
        if ((${#_FILTERED_MENU_INDEXES[@]} > 0)); then
          _SEARCH_MENU_CURSOR_RESULT="${_FILTERED_MENU_INDEXES[$filtered_cursor]}"
        else
          _SEARCH_MENU_CURSOR_RESULT="$cursor"
        fi
        return 0
        ;;
      QUIT|ESC)
        _SEARCH_MENU_CURSOR_RESULT="$cursor"
        return 1
        ;;
      BACKSPACE)
        if ((${#query} > 0)); then
          query="${query:0:${#query}-1}"
        fi
        ;;
      SPACE)
        if ((${#_FILTERED_MENU_INDEXES[@]} > 0)); then
          local menu_index=${_FILTERED_MENU_INDEXES[$filtered_cursor]}
          _MENU_SELECTED[$menu_index]=$((1 - ${_MENU_SELECTED[$menu_index]}))
        fi
        ;;
      TEXT:*)
        query+="${key#TEXT:}"
        ;;
    esac

    _filter_menu_indexes "$query" "$count"
    if ((filtered_cursor >= ${#_FILTERED_MENU_INDEXES[@]})); then
      filtered_cursor=$((${#_FILTERED_MENU_INDEXES[@]} - 1))
      ((filtered_cursor < 0)) && filtered_cursor=0
    fi

  done
}

_setup_stty_available() {
  [[ -t 0 ]] && command -v stty >/dev/null 2>&1
}

# Renders a command into memory and writes it at once, so the terminal never
# shows a half-cleared frame.
_setup_write_buffered() {
  local frame
  frame="$("$@"; printf ".")"
  printf "%s" "${frame%.}"
}

_setup_hide_cursor() {
  [[ -t 1 ]] && printf "\033[?25l"
  return 0
}

_setup_show_cursor() {
  [[ -t 1 ]] && printf "\033[?25h"
  return 0
}

_setup_enter_interactive_input_mode() {
  _setup_hide_cursor
  _SETUP_PREVIOUS_STTY_STATE=""
  if _setup_stty_available; then
    _SETUP_PREVIOUS_STTY_STATE="$(stty -g 2>/dev/null || true)"
    stty -echo 2>/dev/null || true
  fi
}

_setup_restore_interactive_input_mode() {
  if [[ -n "${_SETUP_PREVIOUS_STTY_STATE:-}" ]] && _setup_stty_available; then
    stty "$_SETUP_PREVIOUS_STTY_STATE" 2>/dev/null || true
  fi
  _SETUP_PREVIOUS_STTY_STATE=""
}

# Bash 3.2 (macOS /bin/bash) rejects fractional read timeouts; fall back to the
# smallest integer timeout it accepts.
_setup_read_timeout() {
  local bash_major_version=${2:-${BASH_VERSINFO[0]}}
  if ((bash_major_version >= 4)); then
    printf "%s" "$1"
  else
    printf "1"
  fi
}

_setup_flush_pending_input() {
  local pending_key
  if ((BASH_VERSINFO[0] >= 4)); then
    while IFS= read -rsn1 -t "$SETUP_INPUT_FLUSH_TIMEOUT_SECONDS" pending_key 2>/dev/null; do
      :
    done
    return 0
  fi

  # Without fractional timeouts, drain input with a non-blocking terminal read.
  # `read -n` would reset the terminal to its own blocking mode, so use dd,
  # which honors `min 0 time 0` and returns immediately when nothing is queued.
  _setup_stty_available || return 0
  local previous_stty_state
  previous_stty_state="$(stty -g 2>/dev/null)" || return 0
  stty -icanon min 0 time 0 2>/dev/null || return 0
  while [[ -n "$(dd bs=64 count=1 2>/dev/null)" ]]; do
    :
  done
  stty "$previous_stty_state" 2>/dev/null || true
}

_setup_finish_interactive_input_mode() {
  _setup_flush_pending_input
  _setup_restore_interactive_input_mode
  _setup_show_cursor
}

_read_escape_sequence() {
  local sequence="" sequence_part

  # Bash 3.2 only accepts integer read timeouts, which would make a lone ESC
  # wait one second. With a terminal, read the rest of the sequence with dd,
  # which returns after at most 0.1s (stty time is in tenths of a second).
  if ((BASH_VERSINFO[0] < 4)) && _setup_stty_available; then
    local previous_stty_state
    if previous_stty_state="$(stty -g 2>/dev/null)" && stty -icanon min 0 time 1 2>/dev/null; then
      sequence="$(dd bs=8 count=1 2>/dev/null)"
      stty "$previous_stty_state" 2>/dev/null || true
      printf "%s" "$sequence"
      return 0
    fi
  fi

  local read_timeout
  read_timeout="$(_setup_read_timeout "$SETUP_ESCAPE_SEQUENCE_TIMEOUT_SECONDS")"
  while IFS= read -rsn1 -t "$read_timeout" sequence_part 2>/dev/null; do
    sequence+="$sequence_part"
    case "$sequence_part" in
      [A-Za-z~])
        [[ "$sequence" != "O" ]] && break
        ;;
    esac
  done

  printf "%s" "$sequence"
}

_map_escape_sequence_to_key() {
  case "$1" in
    '[A'|'OA') echo "UP" ;;
    '[B'|'OB') echo "DOWN" ;;
    '[H'|'[1~'|'[7~'|'OH') echo "HOME" ;;
    '[F'|'[4~'|'[8~'|'OF') echo "END" ;;
    '[5~') echo "PAGE_UP" ;;
    '[6~') echo "PAGE_DOWN" ;;
    '') echo "ESC" ;;
    *) echo "OTHER" ;;
  esac
}

_read_key() {
  local key
  IFS= read -rsn1 key
  case "$key" in
    $'\033')
      _map_escape_sequence_to_key "$(_read_escape_sequence)"
      ;;
    ' ') echo "SPACE" ;;
    '') echo "ENTER" ;;
    $'\003'|$'\004') echo "QUIT" ;;
    j) echo "DOWN" ;;
    k) echo "UP" ;;
    a) echo "ALL" ;;
    A|'['|'B'|'C'|'D'|'F'|'H'|'O'|'~') echo "OTHER" ;;
    d|D) echo "DEFAULTS" ;;
    /) echo "SEARCH" ;;
    q|Q) echo "QUIT" ;;
    *) echo "OTHER" ;;
  esac
}

_read_search_key() {
  local key
  IFS= read -rsn1 key
  case "$key" in
    $'\033')
      _map_escape_sequence_to_key "$(_read_escape_sequence)"
      ;;
    ' ') echo "SPACE" ;;
    '') echo "ENTER" ;;
    $'\003'|$'\004') echo "QUIT" ;;
    $'\177'|$'\b') echo "BACKSPACE" ;;
    j) echo "DOWN" ;;
    k) echo "UP" ;;
    '['|'A'|'B'|'C'|'D'|'F'|'H'|'O'|'~') echo "OTHER" ;;
    *) printf "TEXT:%s" "$key" ;;
  esac
}


_draw_menu_reference_cell() {
  local shortcut=$1 description=$2 description_width=${3:-$SETUP_SHORTCUT_DESCRIPTION_WIDTH}
  _setup_color "cyan" "$(printf "%-${SETUP_SHORTCUT_WIDTH}s" "$shortcut")"
  printf " %-${description_width}s" "$description"
}

_draw_menu_reference_row() {
  _setup_color "gray" "$SETUP_BOX_VERTICAL"
  printf " "
  _draw_menu_reference_cell "$1" "$2"
  if [[ -n "${3:-}" ]]; then
    _draw_menu_reference_cell "$3" "$4" 0
  fi
  printf "\n"
}

_draw_menu_reference() {
  _setup_box_top "${SETUP_ICON_SHORTCUTS:+$SETUP_ICON_SHORTCUTS }Atajos"
  _draw_menu_reference_row "Arriba/Abajo/j/k" "navegar" "ESPACIO" "alternar"
  _draw_menu_reference_row "PgUp/PgDn/Home/End" "saltar" "a" "alternar todo"
  _draw_menu_reference_row "/" "buscar" "d" "restaurar defaults"
  _draw_menu_reference_row "ENTER" "confirmar" "q/ESC/Ctrl+C/D" "cancelar"
  _setup_box_bottom
  printf "\n"
}

# Operates on global arrays: _MENU_LABELS, _MENU_SELECTED
_multiselect() {
  local cursor=0
  local count=${#_MENU_LABELS[@]}
  local window_start=0
  local visible_height
  visible_height="$(_menu_visible_height)"
  local rendered_lines=$((visible_height + SETUP_MENU_HEADER_LINES + SETUP_MENU_FOOTER_LINES))
  local previous_interrupt_trap
  previous_interrupt_trap="$(trap -p INT)"
  _setup_enter_interactive_input_mode

  trap '_setup_finish_interactive_input_mode; printf "\n  Instalación cancelada.\n"; exit 130' INT

  printf "\n"
  _draw_menu_reference

  _setup_write_buffered _draw_menu_window "$cursor" "$window_start" "$visible_height" "$count"

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
      SPACE) _MENU_SELECTED[$cursor]=$(( 1 - ${_MENU_SELECTED[$cursor]} )); force_full_render=1 ;;
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
        _setup_finish_interactive_input_mode
        if [[ -n "$previous_interrupt_trap" ]]; then
          eval "$previous_interrupt_trap"
        else
          trap - INT
        fi
        printf "\n"
        return 0
        ;;
      QUIT|ESC)
        _setup_finish_interactive_input_mode
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
    rendered_lines=$((visible_height + SETUP_MENU_HEADER_LINES + SETUP_MENU_FOOTER_LINES))
    window_start="$(_menu_adjust_window_start "$cursor" "$window_start" "$visible_height" "$count")"

    if [[ $should_draw_from_current_position -eq 1 ]]; then
      _setup_write_buffered _draw_menu_window "$cursor" "$window_start" "$visible_height" "$count"
    elif _menu_requires_full_render "$previous_window_start" "$window_start" "$previous_visible_height" "$visible_height" "$force_full_render"; then
      _setup_write_buffered _redraw_full_menu_window "$previous_rendered_lines" "$cursor" "$window_start" "$visible_height" "$count"
    elif [[ "$key" == "SPACE" ]]; then
      _setup_write_buffered _redraw_menu_item_from_bottom "$cursor" "$cursor" "$window_start" "$rendered_lines"
    elif ((previous_cursor != cursor)); then
      _setup_write_buffered _redraw_cursor_move "$previous_cursor" "$cursor" "$window_start" "$rendered_lines"
    fi
  done
}

_print_selected_menu_items() {
  local menu_index

  for menu_index in "${!_MENU_LABELS[@]}"; do
    if [[ ${_MENU_SELECTED[$menu_index]} -eq 1 ]]; then
      _setup_box_row "$(_menu_display_label "$menu_index")"
    fi
  done
}

_confirm_selected_menu_items() {
  local dry_run=${1:-0}
  local selected_count
  local previous_interrupt_trap
  selected_count="$(_menu_selected_count)"
  previous_interrupt_trap="$(trap -p INT)"
  _setup_enter_interactive_input_mode

  trap '_setup_finish_interactive_input_mode; printf "\n  Instalación cancelada.\n"; exit 130' INT

  printf "\n"
  _setup_box_top "${SETUP_ICON_CATALOG:+$SETUP_ICON_CATALOG }Se van a procesar ($selected_count)"
  _print_selected_menu_items
  _setup_box_divider
  if [[ $dry_run -eq 1 ]]; then
    _setup_box_row "$(styleText -c yellow -b -- "${SETUP_ICON_DRY_RUN:+$SETUP_ICON_DRY_RUN }Simulación: no se instalará nada.")"
  fi
  _setup_box_row "$(_setup_color "cyan" "ENTER") continuar $SETUP_SEPARATOR $(_setup_color "cyan" "q/ESC/Ctrl+C/D") cancelar"
  _setup_box_bottom

  while true; do
    local key
    key="$(_read_key)"
    case "$key" in
      ENTER)
        _setup_finish_interactive_input_mode
        if [[ -n "$previous_interrupt_trap" ]]; then
          eval "$previous_interrupt_trap"
        else
          trap - INT
        fi
        printf "\n"
        return 0
        ;;
      QUIT|ESC)
        _setup_finish_interactive_input_mode
        if [[ -n "$previous_interrupt_trap" ]]; then
          eval "$previous_interrupt_trap"
        else
          trap - INT
        fi
        printf "\n"
        return 1
        ;;
    esac
  done
}

interactive_menu() {
  local dry_run=${1:-0}
  local assume_yes=${2:-0}
  _initialize_menu_catalog || return 1
  _validate_menu_catalog || return 1
  _reset_menu_selection_to_defaults

  clear
  printf "\n"
  _setup_print_banner "$dry_run"

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

  if [[ $assume_yes -eq 0 ]] && ! _confirm_selected_menu_items "$dry_run"; then
    _setup_log_warning "Instalación cancelada."
    return 0
  fi

  if [[ $dry_run -eq 0 ]] && _menu_selection_requires_sudo; then
    ensure_sudo
  fi

  if [[ $dry_run -eq 0 ]] && is_debian_like; then
    printf "\n"
    _setup_box_top "${SETUP_ICON_REFRESH:+$SETUP_ICON_REFRESH }Actualizando índices de apt"
    sudo apt-get update
    sudo apt-get --fix-broken install -y
    _setup_box_close "${SETUP_ICON_OK:+$SETUP_ICON_OK }apt listo"
  fi

  _run_selected_menu_items "$dry_run"
  _print_install_summary
  if _setup_install_results_include_failure; then
    return 1
  fi
}

_print_setup_usage() {
  cat <<'EOF'
Uso:
  setup.sh [--dry-run] [--yes] [--list] [id|función ...]

Opciones:
  --dry-run  Muestra qué se ejecutaría sin instalar nada.
  --yes      Omite la confirmación antes de ejecutar los ítems seleccionados.
  --list     Lista los ítems del catálogo (tabla en terminal, TSV al redirigir).
  --help     Muestra esta ayuda.
EOF
}

_list_setup_catalog() {
  local menu_index

  _initialize_menu_catalog || return 1
  _validate_menu_catalog || return 1

  # Piped output keeps the tab-separated format for scripts.
  if [[ ! -t 1 ]]; then
    for menu_index in "${!_MENU_IDS[@]}"; do
      printf "%s\t%s\t%s\n" "${_MENU_IDS[$menu_index]}" "${_MENU_FUNCS[$menu_index]}" "${_MENU_LABELS[$menu_index]}"
    done
    return 0
  fi

  _setup_box_top "${SETUP_ICON_CATALOG:+$SETUP_ICON_CATALOG }Catálogo $SETUP_SEPARATOR $(_setup_platform_display_name) (${#_MENU_IDS[@]})"
  for menu_index in "${!_MENU_IDS[@]}"; do
    _setup_box_row "$(_setup_color "cyan" "$(printf "%-22s" "${_MENU_IDS[$menu_index]}")") $(_menu_display_label "$menu_index")"
  done
  _setup_box_divider
  _setup_box_row "$(_setup_color "gray" "${SETUP_ICON_RECOMMENDED:+$SETUP_ICON_RECOMMENDED }recomendado $SETUP_SEPARATOR ${SETUP_ICON_ADMIN:+$SETUP_ICON_ADMIN }requiere sudo $SETUP_SEPARATOR ${SETUP_ICON_RESTART:+$SETUP_ICON_RESTART }requiere reinicio")"
  _setup_box_bottom
}

_parse_setup_arguments() {
  SETUP_DRY_RUN=0
  SETUP_ASSUME_YES=0
  SETUP_SHOW_HELP=0
  SETUP_LIST_ITEMS=0
  SETUP_COMMAND_ARGUMENTS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) SETUP_DRY_RUN=1 ;;
      --yes|-y) SETUP_ASSUME_YES=1 ;;
      --help|-h) SETUP_SHOW_HELP=1 ;;
      --list) SETUP_LIST_ITEMS=1 ;;
      --)
        shift
        SETUP_COMMAND_ARGUMENTS+=("$@")
        break
        ;;
      --*)
        _setup_log_error "Opción no reconocida: $1" >&2
        return 1
        ;;
      *)
        SETUP_COMMAND_ARGUMENTS+=("$1")
        ;;
    esac
    shift
  done
}

_run_setup_items_by_identifier() {
  local dry_run=$1
  local assume_yes=$2
  shift
  shift
  local menu_indexes=()
  local item_identifier menu_index

  _initialize_menu_catalog || return 1
  _validate_menu_catalog || return 1

  for item_identifier in "$@"; do
    if ! menu_index="$(_find_menu_item_index "$item_identifier")"; then
      _setup_log_error "El ítem '$item_identifier' no está permitido por el catálogo de setup." >&2
      return 1
    fi
    menu_indexes+=("$menu_index")
  done

  if [[ $dry_run -eq 0 ]] && _menu_indexes_require_sudo "${menu_indexes[@]}"; then
    ensure_sudo
  fi

  _MENU_SELECTED=()
  for menu_index in "${!_MENU_FUNCS[@]}"; do
    _MENU_SELECTED[$menu_index]=0
  done

  for menu_index in "${menu_indexes[@]}"; do
    _MENU_SELECTED[$menu_index]=1
  done

  _setup_print_banner "$dry_run"

  if [[ $assume_yes -eq 0 ]] && ! _confirm_selected_menu_items "$dry_run"; then
    _setup_log_warning "Instalación cancelada."
    return 0
  fi

  _run_selected_menu_items "$dry_run"
  _print_install_summary
  if _setup_install_results_include_failure; then
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _parse_setup_arguments "$@" || exit 1

  if [[ $SETUP_SHOW_HELP -eq 1 ]]; then
    _print_setup_usage
  elif [[ $SETUP_LIST_ITEMS -eq 1 ]]; then
    _list_setup_catalog
  elif [[ ${#SETUP_COMMAND_ARGUMENTS[@]} -gt 0 ]]; then
    _run_setup_items_by_identifier "$SETUP_DRY_RUN" "$SETUP_ASSUME_YES" "${SETUP_COMMAND_ARGUMENTS[@]}"
  else
    interactive_menu "$SETUP_DRY_RUN" "$SETUP_ASSUME_YES"
  fi
fi
