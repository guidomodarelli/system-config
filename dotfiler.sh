#!/bin/bash
home="/home/$USER"

isDarwin() {
	if [[ uname = "Darwin" ]]; then
		return 0
	fi
	return 1
}

create_symbolic_link() {
	local paths="$1"
	local dst_folder="$2"

	for path in ${paths[@]}; do
		local abs_path="$(realpath "$path")"
		local dest_abs_path="$dst_folder"/"$(basename "$abs_path")"

		local mv='mv "${dest_abs_path}"{,.bak} 2>/dev/null'
		local ln='ln -s "$abs_path" "$dest_abs_path"'
		local rm_bak='rm -r "${dest_abs_path}.bak"'
		if [[ ! "${dst_folder}" =~ "$home" ]]; then
			if [[ -d "${dest_abs_path}.bak" ]]; then
				eval "sudo $rm_bak"
			fi
			eval "sudo $mv"
			eval "sudo $ln"
		else
			if [[ -d "${dest_abs_path}.bak" ]]; then
				eval "$rm_bak"
			fi
			eval "$mv"
			if [[ ! -d "$dest_abs_path" ]]; then
				mkdir -p $(dirname "$dest_abs_path")
			fi
			eval "$ln"
		fi
	done
}

main() {
	local files="$(cat listfiles)"
	if [[ isDarwin ]]; then
		home="/Users/$USER"
		files="$(cat listfiles.darwin)"
	fi

	while IFS='=' read src dest; do
		src=./files/"$src"
		if [[ -z "$dest" ]]; then
			dest="$home"
		else
			if [[ "${dest:0:1}" != "/" ]]; then
				dest="$home"/"$dest"
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

main
