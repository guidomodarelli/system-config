cd $HOME
sudo apt-get update
curl https://rclone.org/install.sh | sudo bash
# Instalación de paquetes y binarios
sudo apt-get install git zsh fzf build-essential
curl -L git.io/antigen > antigen.zsh
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ghq nvim rg fd exa git-delta zoxide

# Config zsh
git clone https://gitlab.com/guidomodarelli25/system-config.git # Clone this config
chsh -s $(which zsh) # Make it your default shell
ln -s system-config/home/.zsh
ln -s .zsh/.antigenrc
ln -s system-config/home/.zshrc
source ~/.zshrc
# Install Oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
rm .zshrc
mv .zshrc.pre-oh-my-zsh .zshrc
source ~/.zshrc

# Config nvim
mkdir -p .config
ln -s ~/system-config/.config/nvim ~/.config

# Config git
ln -s ~/system-config/home/.gitconfig

# Install Docker: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

# Generate an SSH Key
ssh-keygen -b 2048 -t rsa
