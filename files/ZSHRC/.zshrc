# See https://smarttech101.com/zsh-highlighting-autosuggestion-themes-binding-alias-fzf/
ZSH_HOME=$HOME/.zsh
ZSH_THEME="dst"
ZSH=$HOME/.oh-my-zsh

source $HOME/.antigenrc
source $ZSH/oh-my-zsh.sh

files="$(cd "$ZSH_HOME" && find . -type f | grep "\.zsh")"

while read file; do
	fullpath="$(cd "$ZSH_HOME" && realpath "$file")"
	source "$fullpath"
done <<<"$files"
