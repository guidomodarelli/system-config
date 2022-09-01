source $ZSH/completions/et.zsh
source $ZSH/completions/kubectl.zsh

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
fpath=(/usr/local/share/zsh-completions $fpath)
