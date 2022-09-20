# General
if command -v nvim &>/dev/null; then
	alias v=nvim
fi

if command -v fzf &>/dev/null; then
	alias f=fzf
fi

if command -v kubectl &>/dev/null; then
	alias k=kubectl
fi

if command -v batcat &>/dev/null; then
	alias b=batcat
fi

if command -v python3 &>/dev/null; then
	alias p=python3
fi

if command -v curlie &>/dev/null; then
	alias c=curlie
fi

alias so=source

# exa
if command -v exa &>/dev/null; then
	alias exa='exa --group-directories-first --icons --color-scale --git-ignore'
	alias ll='exa --long --classify --header --group --no-time --no-filesize'
	alias la='ll --all'
	alias lt='exa --tree'
fi
