# emacs key bindings
bindkey -e

if command -v fzf &>/dev/null; then
  # Most used commands
  bindkey '^b' anyframe-widget-git-checkout-branch
  bindkey '^x^w' anyframe-widget-cd-repository-work
  bindkey '^x^p' anyframe-widget-cd-repository-projects
  bindkey '^x^g' anyframe-widget-cd-repository-ghq

  # Less used commands
  bindkey '^h' anyframe-widget-put-history
  bindkey '^t' anyframe-widget-git-checkout-tag
  bindkey '^gc' anyframe-widget-git-checkout-commit
  bindkey '^xk' anyframe-widget-process-kill-user
  bindkey '^xkr' anyframe-widget-process-kill-root
  bindkey '^xp' anyframe-widget-process-copy-id

  # List all widgets
  bindkey '^xx' anyframe-widget-select-widget

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
