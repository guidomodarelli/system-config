if command -v rg &>/dev/null && command -v fzf &>/dev/null; then
	fif() {
		if [ ! "$#" -gt 0 ]; then
			echo "Need a string to search for!"
			return 1
		fi
		rg --hidden --files-with-matches --no-messages "$1" | fzf --preview "rg --ignore-case --pretty --context 10 '$1' {}"
	}
fi
