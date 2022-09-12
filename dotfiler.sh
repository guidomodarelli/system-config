#!/bin/bash

get_list_of_files () {
  local src="$1"

  echo "$(ls -a "$src" | grep -vE "^\.+$")"
}

create_symbolic_links () {
  local src="$1"
  local dest="$2"

  local list=$(get_list_of_files "$src")

  for path in "${list[@]}"; do
    rm "$dest"/"$path"
    ln -s "$(realpath ./"$src"/"$path")" "$dest"
  done
}

create_symbolic_links "home" "$HOME"

create_symbolic_links ".config" "$HOME/.config"
