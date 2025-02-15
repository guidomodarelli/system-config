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
    if [[ "$ID" == *"ubuntu"* ]]; then
      return 0  # true
    fi
  fi
  return 1  # false
}

is_arch() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == *"arch"* ]]; then
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
  elif is_arch; then
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
  install_aicommits
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

install_go_dependencies() {
  install_ghq
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
		curl -Lo exa.zip "https://github.com/ogham/exa/releases/latest/download/exa-linux-x86_64-v${EXA_VERSION}.zip"
		sudo unzip -q exa.zip bin/exa -d /usr/local
		rm -rf exa.zip
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
		sudo apt install -y build-essential gcc curl wget unzip python3.12-venv
	elif is_arch; then
		sudo pacman -Sy --noconfirm yay base-devel gcc curl wget unzip
	fi
}

install_utilities() {
  if is_ubuntu; then
    sudo apt update
    sudo apt install -y jq neovim fzf ripgrep bat zoxide
  elif is_arch; then
    sudo pacman -Sy --noconfirm jq neovim fzf ripgrep bat zoxide
  fi
}

main() {
	if is_ubuntu; then
		sudo apt update
	fi

	install_essencials
	install_utilities

	# install_homebrew

	install_user_interface_apps
	install_fonts
	install_btop
	install_xclip
	install_exa
	install_fd_find
	install_lazygit
	install_git_dependencies
	install_LazyVim
  install_antigen
  install_docker
	install_zsh
  install_oh_my_zsh

  # Go dependencies
  install_golang
  install_go_dependencies

  # NPM dependencies
  install_nvm
  # install_npm_dependencies
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
