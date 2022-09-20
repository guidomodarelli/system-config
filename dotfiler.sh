#!/bin/bash

create_symbolic_link() {
	local files="$(cat listfiles)"
	local prefix="$HOME"

	for path in ${files[@]}; do
		local src="$path"
		local filename="$(basename "$src")"
		local dest_fullpath="$(echo "$prefix"/"$filename")"

		if [ -n "$(echo "$path" | grep "=")" ]; then
			src="$(echo "$path" | cut -d'=' -f1)"
			filename="$(basename "$src")"
			dest_parent_folder="$(echo "$path" | cut -d'=' -f2)"
			dest_fullpath="$(echo "$prefix"/"$dest_parent_folder"/"$filename")"
		fi

		rm "$dest_fullpath" 2>/dev/null

		src_fullpath="$(realpath ./files/"$src")"
		ln -s "$src_fullpath" "$dest_fullpath"
	done
}

create_symbolic_link
