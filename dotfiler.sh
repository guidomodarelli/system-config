#!/bin/bash

create_symbolic_link() {
	local paths="$1"
	local dst_folder="$2"

	for path in ${paths[@]}; do
		local abs_path="$(realpath "$path")"
		local dest_abs_path="$dst_folder"/"$(basename "$abs_path")"

		rm -rf "$dest_abs_path" 2>/dev/null
		ln -s "$abs_path" "$dest_abs_path"
	done
}

main() {
	local files="$(cat listfiles)"

	while IFS='=' read src dest; do
		if [[ -z "$dest" ]]; then
			dest="$HOME"
		else
			dest="$HOME"/"$dest"
		fi
		local paths="$(find ./files/"$src" 2>/dev/null)"
		if [[ -n "$(echo "$src" | grep "*")" ]]; then
			src="$(echo "$src" | cut -d'*' -f1)"
			paths="$(find ./files/"$src" -maxdepth 1 -mindepth 1)"
		fi

		create_symbolic_link "$paths" "$dest"
	done <<<"$files"
}

main
