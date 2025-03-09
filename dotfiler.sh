#!/bin/bash

ROOT_DIR="$(git rev-parse --show-toplevel)"
ROOT_CONFIGS="files"
LISTFILES="listfiles.yml"
source "$ROOT_DIR/$ROOT_CONFIGS/zsh/.zsh/functions/styleText.zsh"
source "$ROOT_DIR/$ROOT_CONFIGS/zsh/.zsh/constants.zsh"
source "$ROOT_DIR/$ROOT_CONFIGS/zsh/.zsh/functions/check_command.zsh"

DEBUG=false
is_debug() {
  if [ "$DEBUG" = true ]; then
    return 0 # true
  fi
  return 1 # false
}

is_darwin() {
  if [ "$(uname)" = "Darwin" ]; then
    return 0 # true
  fi
  return 1 # false
}

get_linux_distro() {
  if [ -f "/etc/arch-release" ]; then
    echo "arch"
  elif [ -f "/etc/debian_version" ]; then
    echo "debian"
  else
    echo "all"
  fi
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

first_letter() {
  echo "${1:0:1}"
}

build_path_obj() {
  local path="$1"
  local target="$2"
  echo "{\"path\":\"$path\",\"target\":\"$target\"}"
}

get_abs_path() {
  local path="$1"

  if [ "$(first_letter "$path")" != "/" ] && [ "$(first_letter "$path")" != "~" ]; then
    path="$ROOT_CONFIGS/$path"
  fi

  realpath "$path"
}

add_path_to_output() {
  local path="$1"
  local target="$2"
  local output="$3"

  target="$target"/"$(basename "$path")"
  path=$(get_abs_path "$path")
  local path_obj=$(build_path_obj "$path" "$target")
  echo "$output" | jq -c ". + [$path_obj]"
}

get_paths() {
  local selector="$1"
  local selector_override="$2"
  local output="[]"

  output="$(yq ".paths[] | select($selector)" $LISTFILES | jq -c '.' | while read -r line; do

    path=$(echo "$line" | jq -r '.path')

    # Busca un override para platform = darwin
    override_target=$(echo "$line" | jq -r ".overrides[]? | select($selector_override) | .target")

    # Si hay override para darwin, úsalo; si no, usa el target normal
    target=${override_target:-$(echo "$line" | jq -r '.target')}

    if [ "$target" = "null" ]; then
      target="$HOME"
    elif [ "$(first_letter "$target")" != "/" ] && [ "$(first_letter "$target")" != "~" ]; then
      target="$HOME"/"$target"
    fi

    if is_debug; then
      echo "Path: $(printPath $path)"
      echo "Target: $(printPath $target)"
      echo "-----------"
    fi

    if [ -n "$(echo "$path" | grep -E "\*$")" ]; then
      path="$(echo "$path" | cut -d'*' -f1)"
      paths="$(find $(get_abs_path "$path") -maxdepth 1 -mindepth 1)"
      while IFS= read -r path; do
        output=$(add_path_to_output "$path" "$target" "$output")
      done <<<"$paths"
    else
      output=$(add_path_to_output "$path" "$target" "$output")
    fi

    echo "$output"
  done)"

  echo "$output" | tail -1
}

get_linux_paths() {
  local current_distro=$(get_linux_distro)
  local selector='(
    .excludeFor == null or (
      .excludeFor[].platform != "linux" or (
        .excludeFor[].platform == "linux" and .excludeFor[].linuxDistro != null
          and .excludeFor[].linuxDistro != "'$current_distro'"
      )
    )
  ) and (
    .onlyFor == null or (
      .onlyFor[].platform == "linux" and (
        .onlyFor[].linuxDistro == null
          or .onlyFor[].linuxDistro == "'$current_distro'"
      )
    )
  )'
  local selector_override='.platform == "linux" and (
    .linuxDistro == null or .linuxDistro == "'$current_distro'"
  )'

  get_paths "$selector" "$selector_override"
}

get_darwin_paths() {
  local selector='(
    .excludeFor == null or .excludeFor[].platform != "darwin"
  ) and (
    .onlyFor == null or .onlyFor[].platform == "darwin"
  )'
  local selector_override='.platform == "darwin"'

  get_paths "$selector" "$selector_override"
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
    path=./$ROOT_CONFIGS/"$path"
    if [[ -z "$target" ]]; then
      target="$HOME"
    elif [ "$(first_letter "$target")" != "/" ]; then
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

check_commands yq jq
main
