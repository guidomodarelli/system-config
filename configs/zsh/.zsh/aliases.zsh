### General
alias rg="rg -p --glob \"!.git/*\""
alias so=source
alias gt=grt

if command -v nvim >/dev/null 2>&1; then
	alias v=nvim
fi

if command -v fzf >/dev/null 2>&1; then
	alias f=fzf
fi

if command -v batcat >/dev/null 2>&1; then
	alias bat=batcat
fi

if command -v python3 >/dev/null 2>&1; then
	alias py=python3
fi

### eza
if command -v eza >/dev/null 2>&1; then
	alias eza='eza --group-directories-first --icons'
	alias ll='eza --long --header --group'
	alias la='ll --all'
	alias lt='eza --tree --all'
fi
