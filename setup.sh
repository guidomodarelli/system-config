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
    if [[ "$ID" == *"ubuntu"* ]]; then
      return 0  # true
    fi
  fi
  return 1  # false
}

install_LazyVim() {
  # Make a backup of your current Neovim files:
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
    sudo apt update
    sudo apt install -y docker.io docker-compose
  else
    sudo pacman -Sy --noconfirm docker docker-compose
  fi
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

install_aicommits() {
  # https://github.com/Nutlope/aicommits
  npm install -g aicommits
  # NOTE: aicommits config set OPENAI_KEY=<your token>
  aicommits config set generate=3
}

install_npm_dependencies() {
  npm i -g yarn

  install_aicommits
}

install_font() {
  if is_windows; then
    return
  fi

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
	if is_windows; then
		return
	fi

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
}

install_ghq() {
  go install github.com/x-motemen/ghq@latest
}

install_go_dependencies() {
  install_ghq
}

install_VsCode() {
  if is_ubuntu; then
		sudo snap install --classic code
	else
		yay -S --noconfirm --needed visual-studio-code-bin
	fi
}

install_fonts() {
	if is_ubuntu; then
		sudo apt install -y fonts-iosevka fonts-jetbrains-mono fonts-victor-mono fonts-dejavu fonts-cascadia-code
	else
		sudo pacman -Sy --noconfirm ttf-iosevkaterm-nerd ttf-jetbrains-mono ttf-victor-mono-nerd ttf-dejavu-nerd ttf-cascadia-mono-nerd
	fi
}

install_user_interface_apps() {
	if is_ubuntu; then
		sudo apt install -y vlc wezterm rofi obs-studio
	else
		sudo pacman -Sy --noconfirm vlc wezterm rofi obs-studio peek
	fi

	if ! is_windows; then
		install_VsCode
	fi
}

install_exa() {
	if is_ubuntu; then
		brew install exa
	else
		sudo pacman -Sy --noconfirm exa
	fi
}

install_homebrew() {
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_fd_find() {
	if is_ubuntu; then
		sudo apt install -y fd-find
		mkdir -p ~/.local/bin
		ln -s $(which fdfind) ~/.local/bin/fd
	else
		sudo pacman -Sy --noconfirm fd
	fi
}

install_dependencies() {
  if is_ubuntu; then
    # System dependencies
    sudo apt update
    sudo apt install -y build-essential git curl wget jq git-delta neovim fzf ripgrep bat zoxide git-filter-repo
    sudo snap install lazygit
		# TODO: install peek
		if ! is_windows; then
			sudo apt install -y btop xclip
		fi
  else
    # System dependencies
    sudo pacman -Sy --noconfirm base-devel yay gcc jq git-delta neovim fzf ripgrep bat zoxide git-filter-repo btop xclip
    yay -S --noconfirm --needed lazygit-git
  fi

	install_homebrew

	install_user_interface_apps

	if ! is_windows; then
		install_fonts
	fi

	install_exa

  # Go dependencies
  install_golang
  install_go_dependencies

  # NPM dependencies
  install_nvm
  # install_npm_dependencies
}

main() {
  install_dependencies

  # Custom installation
  install_LazyVim
  install_antigen
  install_espanso
  install_docker
  install_oh_my_zsh
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ -n "$1" ]]; then
    "$@"
  else
    main
  fi
fi
