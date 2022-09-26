#!/bin/bash
CWD="$(cd "$(dirname "$0")"/.. && pwd)"
SHUNIT2="${CWD}/test/shunit2/shunit2"

if [[ ! -e "$SHUNIT2" ]]; then
	pushd "$CWD/test"
	git clone https://github.com/kward/shunit2
	popd
	echo $'\n'
fi

oneTimeSetUp() {
	source "${CWD}/dotfiler.sh"
}

testSymLinks() {
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

		for path in ${paths[@]}; do
			local abs_path="$(realpath "$path")"
			local dest_abs_path="$dest"/"$(basename "$abs_path")"

			assertEquals "$(readlink -f "$dest_abs_path")" "$abs_path"
		done
	done <<<"$files"
}

source "$SHUNIT2"
