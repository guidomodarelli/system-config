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

function __fzf() {
	local header
	local fzf_default_opts=("--height=50%" "--min-height=15" "--reverse" "-m")

	if [ $# -ne 0 ]; then
		header=$1
		fzf_default_opts+=("--header=\"[$header]\"")
	fi

	echo $(eval "fzf ${fzf_default_opts}")
}

function fgd() {
	local inst=$(git diff --name-only | __fzf "git:diff")

	if [[ $inst ]]; then
		git diff $inst
	fi
}

function fga() {
	local inst=$(git diff --name-only | __fzf "git:add")

	if [[ $inst ]]; then
		for file in $(echo $inst); do
			git add $file
		done
	fi
}

function fgrs() {
	local inst=$(git diff --name-only | __fzf "git:restore")

	if [[ $inst ]]; then
		for file in $(echo $inst); do
			git restore $file
		done
	fi
}

function fgrst() {
	local inst=$(git diff --name-only --cached | __fzf "git:restore:staged")

	if [[ $inst ]]; then
		for file in $(echo $inst); do
			git restore --staged $file
		done
	fi
}
