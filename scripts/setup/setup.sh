#!/bin/bash

LOCAL_BINARIES="$HOME/.local/bin"
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SDKMAN_JAVA_IDENTIFIER="21.0.10-tem"

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
  if is_ubuntu; then
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
  fi
  sleep 3
  sudo systemctl start docker.service
  sudo systemctl enable docker.service
  sudo usermod -aG docker $USER
  # NOTE: reboot
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

_draw_menu_item() {
  local idx=$1 cursor=$2 label=$3 is_selected=$4
  local marker=" "
  [[ $is_selected -eq 1 ]] && marker="✔"
  if [[ $idx -eq $cursor ]]; then
    printf "  \033[7m [%s] %s \033[0m" "$marker" "$label"
  else
    printf "   [%s] %s" "$marker" "$label"
  fi
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
        esac
      fi
      echo "ESC"
      ;;
    ' ') echo "SPACE" ;;
    '') echo "ENTER" ;;
    j) echo "DOWN" ;;
    k) echo "UP" ;;
    a|A) echo "ALL" ;;
    q|Q) echo "QUIT" ;;
    *) echo "OTHER" ;;
  esac
}

# Operates on global arrays: _MENU_LABELS, _MENU_SELECTED
_multiselect() {
  local cursor=0
  local count=${#_MENU_LABELS[@]}

  printf "\n  ↑/↓/j/k: navigate | SPACE: toggle | a: toggle all | ENTER: confirm | q: quit\n\n"

  # Initial draw
  for i in "${!_MENU_LABELS[@]}"; do
    _draw_menu_item "$i" "$cursor" "${_MENU_LABELS[$i]}" "${_MENU_SELECTED[$i]}"
    printf "\n"
  done

  while true; do
    local key
    key=$(_read_key)

    case "$key" in
      UP)    ((cursor > 0)) && ((cursor--)) ;;
      DOWN)  ((cursor < count - 1)) && ((cursor++)) ;;
      SPACE) _MENU_SELECTED[$cursor]=$(( 1 - ${_MENU_SELECTED[$cursor]} )) ;;
      ALL)
        local all_on=1
        for s in "${_MENU_SELECTED[@]}"; do
          [[ $s -eq 0 ]] && all_on=0 && break
        done
        local toggle=$(( 1 - all_on ))
        for i in "${!_MENU_SELECTED[@]}"; do
          _MENU_SELECTED[$i]=$toggle
        done
        ;;
      ENTER) printf "\n"; return 0 ;;
      QUIT)  printf "\n"; return 1 ;;
      *) continue ;;
    esac

    # Redraw
    printf "\033[%dA" "$count"
    for i in "${!_MENU_LABELS[@]}"; do
      printf "\r\033[2K"
      _draw_menu_item "$i" "$cursor" "${_MENU_LABELS[$i]}" "${_MENU_SELECTED[$i]}"
      printf "\n"
    done
  done
}

interactive_menu() {
  _MENU_LABELS=(
    "Essentials (build-essential, gcc, curl, wget, zip, unzip, python3-venv)"
    "Golang"
    "Homebrew"
    "NVM (Node Version Manager)"
    "SDKMAN"
    "Java JDK 21 (Temurin via SDKMAN)"
    "Zsh"
    "Antigen (Zsh plugin manager)"
    "Oh My Zsh"
    "jq"
    "fzf"
    "ripgrep"
    "zoxide"
    "GNU grep (ggrep)"
    "eza"
    "fd-find"
    "yq"
    "xclip"
    "win32yank (WSL clipboard)"
    "espanso"
    "Git"
    "git-filter-repo"
    "ghq"
    "Docker"
    "lazydocker"
    "Fonts (JetBrains Mono, DejaVu, Cascadia Code)"
    "VS Code"
    "Font: Iosevka Term Curly"
  )

  local _MENU_FUNCS=(
    install_essentials
    install_golang
    install_homebrew
    install_nvm
    install_sdkman
    install_java_jdk
    install_zsh
    install_antigen
    install_oh_my_zsh
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
    install_git
    install_git_filter_repo
    install_ghq
    install_docker
    install_lazydocker
    install_fonts
    install_VsCode
    install_font_IosevkaTermCurly
  )

  # Pre-select items from the default main() flow
  _MENU_SELECTED=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0)

  printf "\n"
  printf "  ╔══════════════════════════════════════╗\n"
  printf "  ║       System Setup Installer         ║\n"
  printf "  ╚══════════════════════════════════════╝\n"

  if ! _multiselect; then
    echo "  Installation cancelled."
    return 0
  fi

  # Count selected
  local count=0
  for s in "${_MENU_SELECTED[@]}"; do
    ((s == 1)) && ((count++))
  done

  if [[ $count -eq 0 ]]; then
    echo "  No items selected. Exiting."
    return 0
  fi

  echo "  Installing $count selected item(s)..."

  if is_ubuntu; then
    sudo apt update
    sudo apt --fix-broken install
  fi

  for i in "${!_MENU_FUNCS[@]}"; do
    if [[ ${_MENU_SELECTED[$i]} -eq 1 ]]; then
      printf "\n━━━ Installing: %s ━━━\n" "${_MENU_LABELS[$i]}"
      ${_MENU_FUNCS[$i]}
    fi
  done

  printf "\n  ✅ Installation complete!\n"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_sudo
  if [[ -n "$1" ]]; then
    echo "Running $0 $@"
    "$@"
  else
    interactive_menu
  fi
fi
