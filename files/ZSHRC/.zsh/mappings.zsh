# emacs key bindings
bindkey -e

if command -v fzf &>/dev/null; then
	bindkey '^b' anyframe-widget-checkout-git-branch
	bindkey '^r' anyframe-widget-execute-history
	bindkey '^g' anyframe-widget-cd-ghq-repository
	bindkey '^k' anyframe-widget-kill
	zstyle ':anyframe:selector:' use fzf
fi

# Change the keybindings
bindkey '^[[8~' end-of-line       # end key;
bindkey '^[[7~' beginning-of-line # Home key
bindkey '^[n' down-line-or-history
bindkey '^[p' up-line-or-history
bindkey '^N' history-search-forward  # or you can bind it to the down key '^[[B'
bindkey '^P' history-search-backward # or you can bind it to Up key '^[[A'

# autosuggest keybindings
bindkey '^X' autosuggest-execute
bindkey '^E' autosuggest-accept

# Edit line in vim with alt-e
autoload edit-command-line
zle -N edit-command-line
bindkey '^[e' edit-command-line
