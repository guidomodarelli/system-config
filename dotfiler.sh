#!/bin/bash

ROOT_DIR="$(git rev-parse --show-toplevel)"
source "$ROOT_DIR/files/zsh/.zsh/functions/styleText.zsh"
source "$ROOT_DIR/files/zsh/.zsh/constants.zsh"
source "$ROOT_DIR/files/zsh/.zsh/functions/check_command.zsh"

is_darwin() {
  if [ "$(uname)" = "Darwin" ]; then
    return 0 # true
  fi
  return 1 # false
}

printPath() {
  local path="$1"
  echo "$(printCyan -u -- $path)"
}

createBak() {
  local path="$1"

    # Remove .bak
  if [[ -e "${path}.bak" ]]; then
    $SUDO rm -r "${path}.bak"
  fi

  $SUDO mv "${path}"{,.bak} 2>/dev/null

  # This code is checking if a file or directory exists at the given path
  if [[ ! -e "${path}.bak" ]]; then
    return 1
  fi

  printf "[ $(printGreen "BACK") ] Created $(printPath "$(ls -1 -d "${path}.bak")")\n"
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

    # Create .bak
    createBak "$dest_abs_path"
    echo

    # Create symbolic link
    $SUDO ln -s "$abs_path" "$dest_abs_path"
    printInfo "$(printPath "$abs_path") $(printBlue -b -- $POINTER) $(printPath "$(ls -1 -d "$dest_abs_path")")"

    if [[ $SUDO = '' && ! -d "$dest_abs_path" ]]; then
      mkdir -p $(dirname "$dest_abs_path")
    fi
    echo
  done
}

main() {
  local files="$(cat listfiles)"
  if is_darwin; then
    files="$(cat listfiles.darwin)"
    # https://stackoverflow.com/a/13785716
    sudo chmod -R 755 /usr/local/share
  fi
  files="$(echo "$files" | grep -Ev "^\s*#")"

  while IFS='=' read path target; do
    path=./files/"$path"
    if [[ -z "$target" ]]; then
      target="$HOME"
    elif [[ "${target:0:1}" != "/" ]]; then
      target="$HOME"/"$target"
    fi
    local paths="$path"
    if [[ -n "$(echo "$path" | grep "*")" ]]; then
      path="$(echo "$path" | cut -d'*' -f1)"
      paths="$(find "$path" -maxdepth 1 -mindepth 1)"
    fi

    create_symbolic_link "$paths" "$target"
  done <<<"$files"
}

if [ "$EUID" = 0 ]; then
  printError "Don't run as root!"
  exit 1
fi

check_command yq
main
