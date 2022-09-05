cd $HOME
# Instalación de paquetes y binarios
sudo apt install git zsh fzf exa
curl -L git.io/antigen > antigen.zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ghq nvim

# Config zsh
git clone https://gitlab.com/guidomodarelli25/system-config.git # Clone this config
chsh -s $(which zsh) # Make it your default shell
ln -s system-config/home/.zsh
ln -s .zsh/.antigenrc
ln -s system-config/home/.zshrc
source ~/.zshrc
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
rm .zshrc
mv .zshrc.pre-oh-my-zsh .zshrc
source ~/.zshrc

# Config nvim
mkdir -p .config
ln -s ~/system-config/.config/nvim ~/.config
