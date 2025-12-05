### General
alias rg="rg --glob \"!.git/*\""
alias so=source
alias gt=grt

if command -v nvim >/dev/null 2>&1; then
	alias v=nvim
fi

if command -v fzf >/dev/null 2>&1; then
	alias f=fzf
fi

if command -v kubectl >/dev/null 2>&1; then
	alias k=kubectl
fi

if command -v batcat >/dev/null 2>&1; then
	alias bat=batcat
fi

if command -v python3 >/dev/null 2>&1; then
	alias py=python3
fi

if command -v curlie >/dev/null 2>&1; then
	alias curl=curlie
fi

### exa
if command -v exa >/dev/null 2>&1; then
	alias exa='exa --group-directories-first --icons'
	alias ll='exa --long --header --group'
	alias la='ll --all'
	alias lt='exa --tree --all'
fi

