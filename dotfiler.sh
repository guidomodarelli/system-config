#!/bin/bash

isDarwin() {
	if [ "$(uname)" = "Darwin" ]; then
		return 0 # true
	fi
	return 1 # false
}

printRed() {
	printf "\033[91m%s\033[m\n" "$1"
}

printInfo() {
	printf "\033[96m[INFO] %s\033[m\n" "$1"
}

_ls() {
	local col=7
	if isDarwin; then
		col=10
	fi
	ls -gG "$1" | cut -d' ' -f$col-
}

showCreated() {
	if [[ ! -e "$1" ]]; then
		return 1
	fi
	printInfo "Created $(_ls "$1")"
}

create_symbolic_link() {
	local paths="$1"
	local dst_folder="$2"

	for path in ${paths[@]}; do
		local abs_path="$(realpath "$path")"
		local dest_abs_path="$dst_folder"/"$(basename "$abs_path")"

		local SUDO=''
		if [[ ! "${dst_folder}" =~ "$USER" ]]; then
			SUDO='sudo'
		fi

		# Remove .bak
		if [[ -e "${dest_abs_path}.bak" ]]; then
			printRed "[BAK] ${dest_abs_path}.bak"
			$SUDO rm -r "${dest_abs_path}.bak"
		fi

		# Create .bak
		$SUDO mv "${dest_abs_path}"{,.bak} 2>/dev/null
		showCreated "$dest_abs_path".bak

		# Create symbolic link
		$SUDO ln -s "$abs_path" "$dest_abs_path"
		printInfo "New symbolic link => $(_ls $dest_abs_path)"

		if [[ $SUDO = '' && ! -d "$dest_abs_path" ]]; then
			mkdir -p $(dirname "$dest_abs_path")
		fi
	done
}

main() {
	local files="$(cat listfiles)"
	if isDarwin; then
		files="$(cat listfiles.darwin)"
		# https://stackoverflow.com/a/13785716
		sudo chmod -R 755 /usr/local/share
	fi
	files="$(echo "$files" | grep -Ev "^\s*#")"

	while IFS='=' read src dest; do
		src=./files/"$src"
		if [[ -z "$dest" ]]; then
			dest="$HOME"
		else
			if [[ "${dest:0:1}" != "/" ]]; then
				dest="$HOME"/"$dest"
			fi
		fi
		local paths="$src"
		if [[ -n "$(echo "$src" | grep "*")" ]]; then
			src="$(echo "$src" | cut -d'*' -f1)"
			paths="$(find "$src" -maxdepth 1 -mindepth 1)"
		fi

		create_symbolic_link "$paths" "$dest"
	done <<<"$files"
}

if [[ $EUID = 0 ]]; then
	printRed "[ERROR] Do not run as root"
	exit 1
fi

main
