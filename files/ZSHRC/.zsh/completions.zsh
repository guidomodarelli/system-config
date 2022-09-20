ZSH_COMPLETION=$ZSH/completions

# if [ -d $ZSH_COMPLETION/kubectl.zsh ]; then
# 	source $ZSH/completions/kubectl.zsh
# fi

fpath=(/usr/local/share/zsh-completions $fpath)

zstyle :compinstall filename "${ZDOTDIR:-$HOME}/.zshrc"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

autoload -Uz compinit
compinit
_comp_options+=(globdots)

[ ! -f ~/fzf-tab/fzf-tab.plugin.zsh ] || source ~/fzf-tab/fzf-tab.plugin.zsh
