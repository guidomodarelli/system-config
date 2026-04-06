#!/bin/bash

LOCAL_BINARIES="$HOME/.local/bin"

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
  local repo_root
  # TODO: use git rev-parse to get the repo root instead of assuming the script is in scripts/setup
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  local antigen_source="$repo_root/third-party/antigen/antigen.zsh"

  if [ ! -f "$antigen_source" ]; then
    echo "Antigen source not found at $antigen_source" >&2
    return 1
  fi

  cp "$antigen_source" "$HOME/antigen.zsh"
}

install_nvm() {
  # TODO: try to get the latest version of nvm from GitHub instead of hardcoding it
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
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
  # TODO: try to get the latest version of Go from the website instead of hardcoding it
  local GO_VERSION="1.25.3"
  local FILE="go${GO_VERSION}.linux-amd64.tar.gz"
  curl -LO https://go.dev/dl/$FILE
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $FILE
  rm -rf $FILE
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
  curl -s "https://get.sdkman.io" | bash
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
  # install_sdkman
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_sudo
  if [[ -n "$1" ]]; then
    echo "Running $0 $@"
    "$@"
  else
    echo "Running $0 main"
    main
  fi
fi
