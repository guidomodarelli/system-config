install_vscode() {
	# Install Visual Studio Code
	git clone https://aur.archlinux.org/visual-studio-code-bin.git $HOME/visual-studio-code-bin
	cd $HOME/visual-studio-code-bin
	makepkg -si
	cd $HOME
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
	cd $HOME
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_docker() {
	sudo pacman -Sy --noconfirm docker docker-compose
	sudo systemctl start docker.service
	sudo systemctl enable docker.service
	sudo usermod -aG docker $USER
	# reboot
}

install_antigen() {
	curl -L git.io/antigen > $HOME/antigen.zsh
}

install_nvm() {
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
	# nvm install v...
}

install_aicommits() {
	# https://github.com/Nutlope/aicommits
	npm install -g aicommits
	# aicommits config set OPENAI_KEY=<your token>
	aicommits config set generate=3
}

main() {
	# Install dependendencies
	sudo pacman -Sy --noconfirm base-devel gcc git-delta neovim fzf ripgrep fd bat kubectl curlie exa zoxide

	install_vscode
	install_homebrew
	install_LazyVim
	install_oh_my_zsh
	install_docker
	install_antigen
	install_nvm
	install_aicommits
}

main
