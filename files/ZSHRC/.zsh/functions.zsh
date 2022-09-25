if command -v rg &>/dev/null && command -v fzf &>/dev/null; then
	fif() {
		if [ ! "$#" -gt 0 ]; then
			echo "Need a string to search for!"
			return 1
		fi
		rg --hidden --files-with-matches --no-messages "$1" | fzf --preview "rg --ignore-case --pretty --context 10 '$1' {}"
	}
fi

function precmd() {
	print -Pn -- '\e]2;%n@%m %~\a'
}

function gdf() {
	local inst=$(git diff --name-only | eval "fzf ${FZF_DEFAULT_OPTS} -m --header='[git:diff]'")

	if [[ $inst ]]; then
		git diff $inst
	fi
}

function gaf() {
	local inst=$(git diff --name-only | eval "fzf ${FZF_DEFAULT_OPTS} -m --header='[git:add]'")

	if [[ $inst ]]; then
		for file in $(echo $inst); do
			git add $file
		done
	fi
}

function grsf() {
	local inst=$(git diff --name-only | eval "fzf ${FZF_DEFAULT_OPTS} -m --header='[git:restore]'")

	if [[ $inst ]]; then
		for file in $(echo $inst); do
			git restore $file
		done
	fi
}

function grstf() {
	local inst=$(git diff --name-only --cached | eval "fzf ${FZF_DEFAULT_OPTS} -m --header='[git:restore]'")

	if [[ $inst ]]; then
		for file in $(echo $inst); do
			git restore --staged $file
		done
	fi
}
