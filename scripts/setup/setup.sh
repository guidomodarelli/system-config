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
  curl -L git.io/antigen >$HOME/antigen.zsh
}

install_nvm() {
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
}

install_npm_dependencies() {
  echo "Installing npm dependencies"
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

  # https://espanso.org/docs/install/linux/#appimage-x11

  # Create the $HOME/opt destination folder
  mkdir -p ~/opt
  # Download the AppImage inside it
  wget -O ~/opt/Espanso.AppImage 'https://github.com/federico-terzi/espanso/releases/download/v2.2.1/Espanso-X11.AppImage'
  # Make it executable
  chmod u+x ~/opt/Espanso.AppImage
  # Create the "espanso" command alias
  sudo ~/opt/Espanso.AppImage env-path register

  # At this point, you are ready to use espanso by registering it first as a Systemd service and then starting it with:

  # Register espanso as a systemd service (required only once)
  espanso service register

  # NOTE: espanso start
}

install_golang() {
  # https://go.dev/dl/
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
  _go install github.com/x-motemen/ghq@latest

  mkdir -p $HOME/ghq/work
  mkdir -p $HOME/ghq/projects
}

install_lazydocker() {
  _go install github.com/jesseduffield/lazydocker@latest
}

install_VsCode() {
  is_windows && return

  if is_ubuntu; then
    sudo snap install --classic code
  fi
}

install_font_jetbrains_mono_pkg() {
  if is_ubuntu; then sudo apt install -y fonts-jetbrains-mono; fi
}
install_font_dejavu_pkg() {
  if is_ubuntu; then sudo apt install -y fonts-dejavu; fi
}
install_font_cascadia_code_pkg() {
  if is_ubuntu; then sudo apt install -y fonts-cascadia-code; fi
  # Ubuntu ya usa función separada para IosevkaTermCurly (fuente manual)
}

install_fonts() {
  is_windows && return

  install_font_jetbrains_mono_pkg
  install_font_dejavu_pkg
  install_font_cascadia_code_pkg
  # install_font_IosevkaTermCurly  # si se desea instalar la versión manual en Ubuntu
}

install_vlc() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y vlc
  fi
}

install_wezterm() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y wezterm
  fi
}

install_rofi() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y rofi
  fi
}

install_obs_studio() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y obs-studio
  fi
}

install_peek() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y peek
  fi
}

install_user_interface_apps() {
  is_windows && return

  install_vlc
  install_wezterm
  install_rofi
  install_obs_studio
  install_peek
  install_VsCode
  install_espanso
}

install_exa() {
  if is_ubuntu; then
    EXA_VERSION=$(curl -s "https://api.github.com/repos/ogham/exa/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    local EXA_ZIP="exa.zip"
    curl -Lo "$EXA_ZIP" "https://github.com/ogham/exa/releases/latest/download/exa-linux-x86_64-v${EXA_VERSION}.zip"
    sudo unzip -oq "$EXA_ZIP" bin/exa -d /usr/local
    rm -rf "$EXA_ZIP"
  fi
}

install_eza() {
  if is_ubuntu; then
    sudo apt install -y eza
  fi
}

install_homebrew() {
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

_brew() {
  /home/linuxbrew/.linuxbrew/bin/brew "$@"
}

install_fd_find() {
  if is_ubuntu; then
    sudo apt install -y fd-find
    mkdir -p $LOCAL_BINARIES
    if [ ! -f $LOCAL_BINARIES/fd ]; then
      ln -s $(which fdfind) $LOCAL_BINARIES/fd
    fi
  fi
}

install_btop() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y btop
  fi
}

install_xclip() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y xclip
  fi
}

install_git_delta() {
  if is_ubuntu; then
    _brew install git-delta
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
    if is_ubuntu; then
      sudo apt install -y zsh
    fi
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

install_jq() { if is_ubuntu; then sudo apt install -y jq; fi }
install_fzf() { if is_ubuntu; then sudo apt install -y fzf; fi }
install_ripgrep() { if is_ubuntu; then sudo apt install -y ripgrep; fi }
install_batcat() { if is_ubuntu; then sudo apt install -y bat; fi }
install_zoxide() { if is_ubuntu; then sudo apt install -y zoxide; fi }

install_vagrant() {
  is_windows && return

  if is_ubuntu; then
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y vagrant
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
  if is_ubuntu; then
    _brew install yq # https://github.com/mikefarah/yq?tab=readme-ov-file#macos--linux-via-homebrew
  fi
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
  install_batcat
  install_zoxide
  install_exa
  install_fd_find
  install_yq
  install_btop
  install_xclip
  install_win32yank

  # Git tools
  install_git
  install_git_delta
  install_git_filter_repo
  install_ghq

  # Development tools
  # install_vagrant
  install_docker
  install_lazydocker

  # Fonts
  install_fonts
}

if ! is_ubuntu; then
  echo "Unsupported OS"
  exit 1
fi

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
