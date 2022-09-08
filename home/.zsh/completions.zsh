ZSH_COMPLETION=$ZSH/completion

if [ -d $ZSH_COMPLETION/kubectl.zsh ]; then
	source $ZSH/completions/kubectl.zsh
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
fpath=(/usr/local/share/zsh-completions $fpath)
