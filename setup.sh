install_obs_studio() {
	flatpak install flathub com.obsproject.Studio -y
}

install_vscode() {
	# Install Visual Studio Code
	git clone https://aur.archlinux.org/visual-studio-code-bin.git $HOME/visual-studio-code-bin
	cd $HOME/visual-studio-code-bin
	makepkg -si
}

install_homebrew() {
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
	sudo pacman -Sy --noconfirm docker docker-compose
	sudo systemctl start docker.service
	sudo systemctl enable docker.service
	sudo usermod -aG docker $USER
	# NOTE: reboot
}

install_antigen() {
	curl -L git.io/antigen > $HOME/antigen.zsh
}

install_nvm() {
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
	nvm install lts/iron
}

install_aicommits() {
	# https://github.com/Nutlope/aicommits
	npm install -g aicommits
	# NOTE: aicommits config set OPENAI_KEY=<your token>
	aicommits config set generate=3
}

install_npm_dependencies() {
	npm i -g pnpm yarn @nestjs/cli

	install_aicommits
}

install_sdkman() {
	curl -s "https://get.sdkman.io" | bash
}

install_font_IosevkaTermCurly() {
	# https://github.com/be5invis/Iosevka/releases

	local folderName="IosevkaTermCurly"
	local zipName="${folderName}.zip"
	curl -Lo $zipName https://github.com/be5invis/Iosevka/releases/download/v30.1.2/PkgTTF-IosevkaTermCurly-30.1.2.zip
	unzip $zipName
	cd $folderName
	mkdir -p $HOME/.fonts
	mv *.ttf $HOME/.fonts/
	fc-cache -fv
}

install_espanso() {
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
	local GO_VERSION="1.22.3"
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

install_asdf() {
	brew install asdf
}

install_homebrew_dependencies() {
	install_asdf
}

install_dependencies() {
	# System dependencies
	sudo pacman -Sy --noconfirm yay base-devel gcc vlc git-delta neovim fzf ripgrep fd bat kubectl curlie exa zoxide ranger wezterm rofi git-filter-repo btop ttf-iosevkaterm-nerd ttf-jetbrains-mono ttf-victor-mono-nerd ttf-dejavu-nerd ttf-cascadia-mono-nerd awesome

	# Go dependencies
	install_golang
	install_go_dependencies

	# Homebrew dependencies
	install_homebrew
	install_homebrew_dependencies

	# NPM dependencies
	install_nvm
	install_npm_dependencies
}

main() {
	install_dependencies

	# Custom installation
	install_vscode
	install_LazyVim
	install_oh_my_zsh
	install_docker
	install_antigen
	install_sdkman
	install_espanso
}

main
