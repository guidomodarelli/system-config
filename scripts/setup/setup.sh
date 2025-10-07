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
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif is_arch; then
    sudo pacman -Sy --noconfirm docker docker-compose
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
  local GO_VERSION="1.23.6"
  local FILE="go${GO_VERSION}.linux-amd64.tar.gz"
  curl -LO https://go.dev/dl/$FILE
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $FILE
  rm -rf $FILE
}

go_install() {
  local package="$1"
  /usr/local/go/bin/go install "$package"
}

install_ghq() {
  go_install github.com/x-motemen/ghq@latest

  mkdir -p $HOME/ghq/work
  mkdir -p $HOME/ghq/projects
}

install_lazydocker() {
  go_install github.com/jesseduffield/lazydocker@latest
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

install_fonts() {
  is_windows && return

  if is_ubuntu; then
    sudo apt install -y fonts-jetbrains-mono fonts-dejavu fonts-cascadia-code
    # TODO: install Iosevka & Victor Mono
  elif is_arch; then
    sudo pacman -Sy --noconfirm ttf-iosevkaterm-nerd ttf-jetbrains-mono ttf-victor-mono-nerd ttf-dejavu-nerd ttf-cascadia-mono-nerd
  fi
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
    sudo unzip -q "$EXA_ZIP" bin/exa -d /usr/local
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
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
    sudo apt install -y git-delta
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

install_git_dependencies() {
  install_git

  install_git_delta
  install_git_filter_repo
}

install_zsh() {
  if is_ubuntu; then
    sudo apt install -y zsh
  elif is_arch; then
    sudo pacman -Sy --noconfirm zsh
  fi
  chsh -s $(which zsh)
}

install_essencials() {
  if is_ubuntu; then
    sudo apt install -y build-essential gcc curl wget zip unzip python3.12-venv
  elif is_arch; then
    sudo pacman -Sy --noconfirm yay base-devel gcc curl wget zip unzip
  fi
}

install_utilities() {
  if is_ubuntu; then
    sudo apt update
    sudo apt install -y jq fzf ripgrep bat zoxide
    sudo snap install yq # https://github.com/mikefarah/yq?tab=readme-ov-file#linux-via-snap
  elif is_arch; then
    sudo pacman -Sy --noconfirm jq fzf ripgrep bat zoxide
    sudo pacman -Sy --noconfirm go-yq # https://github.com/mikefarah/yq?tab=readme-ov-file#arch-linux
  fi
}

install_vagrant() {
  is_windows && return

  wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install -y vagrant
}

install_neovim() {
  _brew install neovim
}

install_sdkman() {
  curl -s "https://get.sdkman.io" | bash
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  sdk version || true  # Check if SDKMAN! is installed correctly
}

install_java_by_sdkman() {
  sdk install java 17.0.14-tem
}

install_difftastic() {
  if is_ubuntu; then
    _brew install difftastic
  elif is_arch; then
    sudo pacman -Sy --noconfirm difftastic
  fi
}

main() {
  if is_ubuntu; then
    sudo apt update
    sudo apt --fix-broken install
  fi

  install_essencials
  install_utilities

  install_user_interface_apps
  install_fonts
  install_btop
  install_xclip
  install_exa
  install_fd_find
  install_lazygit
  install_git_dependencies
  install_antigen
  install_docker
  install_zsh
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

  # Install Homebrew and dependencies
  install_homebrew
  install_neovim
  install_LazyVim
}

if ! is_ubuntu && ! is_arch; then
  echo "Unsupported OS"
  exit 1
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ -n "$1" ]]; then
    echo "Running $0 $@"
    "$@"
  else
    echo "Running $0 main"
    main
  fi
fi
