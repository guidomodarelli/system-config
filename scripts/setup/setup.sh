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

is_arch() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == *"arch"* ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
      return 0  # true
    fi
  fi
  return 1  # false
}

install_LazyVim() {
  # Make a backup of your current Neovim files:
  ## remove previous backup if exists
  rm -rf ~/.config/nvim.bak ~/.local/share/nvim.bak ~/.local/state/nvim.bak ~/.cache/nvim.bak

  ## required
  mv ~/.config/nvim{,.bak}

  ## optional but recommended
  mv ~/.local/share/nvim{,.bak}
  mv ~/.local/state/nvim{,.bak}
  mv ~/.cache/nvim{,.bak}

  # Clone the starter
  git clone https://github.com/LazyVim/starter ~/.config/nvim

  # Remove the .git folder, so you can add it to your own repo later
  rm -rf ~/.config/nvim/.git
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
install_docker_arch_engine() {
  is_arch || return
  sudo pacman -Sy --noconfirm docker
}
install_docker_arch_compose() {
  is_arch || return
  sudo pacman -Sy --noconfirm docker-compose
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
  elif is_arch; then
    install_docker_arch_engine
    install_docker_arch_compose
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

install_go_dependencies() {
  install_ghq
  install_lazydocker
}

install_VsCode() {
  is_windows && return

  if is_ubuntu; then
    sudo snap install --classic code
  elif is_arch; then
    yay -S --noconfirm --needed visual-studio-code-bin
  fi
}

install_font_jetbrains_mono_pkg() {
  if is_ubuntu; then sudo apt install -y fonts-jetbrains-mono; elif is_arch; then sudo pacman -Sy --noconfirm ttf-jetbrains-mono; fi
}
install_font_dejavu_pkg() {
  if is_ubuntu; then sudo apt install -y fonts-dejavu; elif is_arch; then sudo pacman -Sy --noconfirm ttf-dejavu-nerd; fi
}
install_font_cascadia_code_pkg() {
  if is_ubuntu; then sudo apt install -y fonts-cascadia-code; elif is_arch; then sudo pacman -Sy --noconfirm ttf-cascadia-mono-nerd; fi
}
install_font_victor_mono_pkg() {
  if is_arch; then sudo pacman -Sy --noconfirm ttf-victor-mono-nerd; fi
}
install_font_iosevka_term_pkg() {
  if is_arch; then sudo pacman -Sy --noconfirm ttf-iosevkaterm-nerd; fi
  # Ubuntu ya usa función separada para IosevkaTermCurly (fuente manual)
}

install_fonts() {
  is_windows && return

  install_font_jetbrains_mono_pkg
  install_font_dejavu_pkg
  install_font_cascadia_code_pkg
  install_font_victor_mono_pkg
  install_font_iosevka_term_pkg
  # install_font_IosevkaTermCurly  # si se desea instalar la versión manual en Ubuntu
}

install_vlc() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y vlc
  elif is_arch; then
    sudo pacman -Sy --noconfirm vlc
  fi
}

install_wezterm() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y wezterm
  elif is_arch; then
    sudo pacman -Sy --noconfirm wezterm
  fi
}

install_rofi() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y rofi
  elif is_arch; then
    sudo pacman -Sy --noconfirm rofi
  fi
}

install_obs_studio() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y obs-studio
  elif is_arch; then
    sudo pacman -Sy --noconfirm obs-studio
  fi
}

install_peek() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y peek
  elif is_arch; then
    sudo pacman -Sy --noconfirm peek
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
  elif is_arch; then
    sudo pacman -Sy --noconfirm exa
  fi
}

install_eza() {
  if is_ubuntu; then
    sudo apt install -y eza
  elif is_arch; then
    yay -S --noconfirm --needed eza
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
  elif is_arch; then
    sudo pacman -Sy --noconfirm fd
  fi
}

install_lazygit() {
  if is_ubuntu; then
    sudo snap install lazygit
  elif is_arch; then
    yay -S --noconfirm --needed lazygit-git
  fi
}

install_btop() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y btop
  elif is_arch; then
    sudo pacman -Sy --noconfirm btop
  fi
}

install_xclip() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y xclip
  elif is_arch; then
    sudo pacman -Sy --noconfirm xclip
  fi
}

install_git_delta() {
  if is_ubuntu; then
    _brew install git-delta
  elif is_arch; then
    sudo pacman -Sy --noconfirm git-delta
  fi
}

install_git_filter_repo() {
  if is_ubuntu; then
    sudo apt install -y git-filter-repo
  elif is_arch; then
    sudo pacman -Sy --noconfirm git-filter-repo
  fi
}

install_git() {
  if is_ubuntu; then
    sudo apt install -y git
  elif is_arch; then
    sudo pacman -Sy --noconfirm git
  fi
}

install_git_and_dependencies() {
  install_git

  install_git_delta
  install_git_filter_repo
}

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    echo "zsh already installed; skipping package installation"
  else
    if is_ubuntu; then
      sudo apt install -y zsh
    elif is_arch; then
      sudo pacman -Sy --noconfirm zsh
    fi
  fi

  local desired_shell
  desired_shell="$(command -v zsh || true)"
  if [ -n "$desired_shell" ] && [ "$SHELL" != "$desired_shell" ]; then
    sudo chsh -s "$desired_shell" "$USER"
  fi
}

install_build_essential() { is_ubuntu && sudo apt install -y build-essential; }
install_gcc() { if is_ubuntu; then sudo apt install -y gcc; elif is_arch; then sudo pacman -Sy --noconfirm gcc; fi }
install_curl_pkg() { if is_ubuntu; then sudo apt install -y curl; elif is_arch; then sudo pacman -Sy --noconfirm curl; fi }
install_wget_pkg() { if is_ubuntu; then sudo apt install -y wget; elif is_arch; then sudo pacman -Sy --noconfirm wget; fi }
install_zip_pkg() { if is_ubuntu; then sudo apt install -y zip; elif is_arch; then sudo pacman -Sy --noconfirm zip; fi }
install_unzip_pkg() { if is_ubuntu; then sudo apt install -y unzip; elif is_arch; then sudo pacman -Sy --noconfirm unzip; fi }
install_python3_venv() { is_ubuntu && sudo apt install -y python3-venv; }
install_yay() { is_arch && sudo pacman -Sy --noconfirm yay || true; }
install_base_devel() { is_arch && sudo pacman -Sy --noconfirm base-devel || true; }

install_essentials() {
  install_build_essential
  install_gcc
  install_curl_pkg
  install_wget_pkg
  install_zip_pkg
  install_unzip_pkg
  install_python3_venv
  install_yay
  install_base_devel
}

install_jq() { if is_ubuntu; then sudo apt install -y jq; elif is_arch; then sudo pacman -Sy --noconfirm jq; fi }
install_fzf_pkg() { if is_ubuntu; then sudo apt install -y fzf; elif is_arch; then sudo pacman -Sy --noconfirm fzf; fi }
install_ripgrep_pkg() { if is_ubuntu; then sudo apt install -y ripgrep; elif is_arch; then sudo pacman -Sy --noconfirm ripgrep; fi }
install_bat_pkg() { if is_ubuntu; then sudo apt install -y bat; elif is_arch; then sudo pacman -Sy --noconfirm bat; fi }
install_zoxide_pkg() { if is_ubuntu; then sudo apt install -y zoxide; elif is_arch; then sudo pacman -Sy --noconfirm zoxide; fi }

install_utilities() {
  if is_ubuntu; then sudo apt update; fi
  install_jq
  install_fzf_pkg
  install_ripgrep_pkg
  install_bat_pkg
  install_zoxide_pkg
}


install_vagrant() {
  is_windows && return

  if is_ubuntu; then
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y vagrant
  elif is_arch; then
    # Opcional: implementar instalación en Arch (ej: sudo pacman -Sy --noconfirm vagrant)
    echo "Vagrant no implementado para Arch en este script."
  fi
}

install_neovim() {
  _brew install neovim
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

install_java_by_sdkman() {
  # Requiere que sdkman ya esté cargado en la sesión
  if command -v sdk >/dev/null 2>&1; then
    sdk install java 17.0.14-tem
  else
    echo "sdk no disponible; omitiendo instalación de Java."
  fi
}

install_difftastic() {
  if is_ubuntu; then
    _brew install difftastic
  elif is_arch; then
    sudo pacman -Sy --noconfirm difftastic
  fi
}

install_yq() {
  if is_ubuntu; then
    _brew install yq # https://github.com/mikefarah/yq?tab=readme-ov-file#macos--linux-via-homebrew
  elif is_arch; then
    sudo pacman -Sy --noconfirm go-yq # https://github.com/mikefarah/yq?tab=readme-ov-file#arch-linux
  fi
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

  install_zsh

  install_essentials
  install_utilities

  # Install Homebrew and dependencies
  install_homebrew
  install_neovim
  install_yq

  install_user_interface_apps
  install_fonts
  install_btop
  install_xclip
  install_exa
  install_fd_find
  install_lazygit
  install_git_and_dependencies
  install_antigen
  install_docker
  install_oh_my_zsh
  install_vagrant

  # Install SDKMAN! and dependencies
  install_sdkman
  install_java_by_sdkman

  # Install Golang and dependencies
  install_golang
  install_go_dependencies

  # Install NVM and dependencies
  install_nvm
  # install_npm_dependencies

  install_LazyVim
}

if ! is_ubuntu && ! is_arch; then
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
