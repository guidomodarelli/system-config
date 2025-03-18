#!/bin/bash

ROOT_DIR="$(git rev-parse --show-toplevel)"
ROOT_CONFIGS="files"
LISTFILES="listfiles.yml"
source "$ROOT_DIR/$ROOT_CONFIGS/zsh/.zsh/functions/styleText.zsh"
source "$ROOT_DIR/$ROOT_CONFIGS/zsh/.zsh/constants.zsh"
source "$ROOT_DIR/$ROOT_CONFIGS/zsh/.zsh/functions/check_command.zsh"

# Create a temporary PowerShell script
TMP_SCRIPT=$(mktemp -p /tmp wsl_symlink_XXXXXX.ps1)
# Remove the temporary script when the script exits
trap 'rm -f "$TMP_SCRIPT"' EXIT

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

is_wsl() {
  if [ -n "$(grep -i microsoft /proc/version 2>/dev/null)" ] || [ -n "$(grep -i WSL /proc/version 2>/dev/null)" ]; then
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

create_backup() {
  local path="$1"

  $SUDO mv "${path}"{,.bak} 2>/dev/null

  printf "[ $(printGreen "BACK") ] Created $(printPath "${path//\\/\\\\}.bak")\n"
}

remove_old_symlink() {
  local target="$1"

  $SUDO rm "$target"
  printf "[ $(printGreen "DEL") ] Removed old symlink $(printPath "$target")\n"
}

# Get the current WSL distribution name
get_wsl_distro_name() {
  if is_wsl; then
    grep -oP '(?<=^NAME=").*(?=")' /etc/os-release | tr -d '\r\n'
  fi
}

# Format path for Windows when in WSL
format_wsl_windows_path() {
  local path="$1"
  local distro_name=$(get_wsl_distro_name)

  # Add WSL prefix and replace forward slashes with backslashes
  path="\\\\wsl\$\\$distro_name$path"
  path="${path//\//\\}"

  echo "$path"
}

# This function creates a symbolic link from the source path to the target location
# It handles existing files by creating backups and removes old symlinks if they exist
make_symlink() {
  local path="$1"
  local target="$2"

  local SUDO=''
  local target_dir=$(dirname "$target")

  # Check if we need sudo permissions (if directory is not writable or doesn't exist)
  if [[ ! "$target" =~ "$HOME" ]] || [[ -d "$target_dir" && ! -w "$target_dir" ]] || [[ ! -d "$target_dir" && ! -w "$(dirname "$target_dir")" ]]; then
    SUDO='sudo'
    printf "[ $(printYellow "NOTE") ] Using elevated permissions for $(printPath "$target")\n"
  fi

  # Remove any existing backup of the target if it's a symlink
  if [ -L "${target}.bak" ]; then
    remove_old_symlink "${target}.bak"
  fi

  # Remove old symlink if target already exists as a symbolic link
  if [ -L "$target" ]; then
    remove_old_symlink "$target"
  elif [ -e "$target" ]; then
    # Backup the existing file/directory before creating symlink
    create_backup "$target"
  fi

  # Create parent directory for target if it doesn't exist
  $SUDO mkdir -p $(dirname "$target")

  # Create symbolic link
  if [[ $path =~ "\\\\wsl\$" ]]; then
    printInfo "Creating symlink for WSL: $(printPath "${path//\\/\\\\}")\n"

    # Convert the target path to Windows format
    local win_target=$(wslpath -w "$target" 2>/dev/null)

    # Create a PowerShell script to create the symbolic link
    echo "New-Item -ItemType SymbolicLink -Path '$win_target' -Target '$path' -Force" >> "$TMP_SCRIPT"
  else
    $SUDO ln -s "$path" "$target"
  fi


  printInfo "$(printPath "$target") $(printBlue -b -- $POINTER) $(printPath "${path//\\/\\\\}")\n"
}

first_letter() {
  echo "${1:0:1}"
}

run_elevated_powershell_script() {
  local tmp_script="$1"

  cat "$tmp_script"

  # Convert the path to Windows format
  win_tmp_script=$(wslpath -w "$tmp_script")

  # Run the script with elevated privileges and wait for it to complete
  # Use PowerShell with elevated privileges
  # Start-Process powershell: Starts a new PowerShell instance. This is useful when you want to run commands with elevated privileges.
  # -WindowStyle Hidden: Makes the PowerShell window not visible while the command runs.
  # -Verb RunAs: Runs the process with elevated privileges (as administrator).
  # -NoProfile: Prevents loading the PowerShell profile (default configuration files).
  # -ExecutionPolicy Bypass: Allows running scripts without any restrictions.
  powershell.exe -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"$win_tmp_script\"' -Verb RunAs -Wait -WindowStyle Hidden"
}

# Get Windows username when in WSL
get_windows_username() {
  if is_wsl; then
    # Try to get Windows username using several methods
    if [ -f /mnt/c/Windows/System32/cmd.exe ]; then
      # Use cmd.exe if available
      /mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n'
    elif command -v powershell.exe >/dev/null 2>&1; then
      # Use PowerShell if available
      powershell.exe -Command '$env:USERNAME' 2>/dev/null | tr -d '\r'
    elif [ -n "$WSLENV" ] && [ -n "$USERNAME" ]; then
      # Use WSL environment variable if available
      echo "$USERNAME"
    else
      # Fallback to current user
      echo "$USER"
    fi
  else
    # Not in WSL, return current user
    echo "$USER"
  fi
}

build_path_obj() {
  local path="$1"
  local target="$2"
  # Build a JSON object using jq
  json=$(jq -n --arg path "$path" --arg target "$target" '{path: $path, target: $target}')
  echo "$json"
}

get_abs_path() {
  local path="$1"

  if [ "$(first_letter "$path")" != "/" ] && [ "$(first_letter "$path")" != "~" ]; then
    path="$ROOT_CONFIGS/$path"
  fi

  realpath "$path"
}

# Expand environment variables in a path string
expand_env_vars() {
  local path="$1"

  # Replace $HOME with the actual home directory
  path="${path//'$HOME'/$HOME}"
  path="${path//\~/$HOME}"

  # Replace $USER with the appropriate username
  if [[ "$path" == /mnt/c/* ]] || [[ "$path" == WSL://* ]]; then
    # For WSL paths, use Windows username
    path="${path//'$USER'/$USERNAME}"
  else
    # For regular paths, use Linux username
    path="${path//'$USER'/$USER}"
  fi

  echo "$path"
}

add_path_to_output() {
  local path="$1"
  local target="$2"
  local output="$3"
  local is_wildcard="$4"

  # Only append basename if not a wildcard path
  if [ "$is_wildcard" != "true" ]; then
    target="$target"/"$(basename "$path")"
  fi

  path=$(get_abs_path "$path")
  if [[ "$target" == WSL://* ]]; then
    # Convert WSL:// prefix to Windows path
    target=${target//WSL:\/\//}
    target="/mnt/c/Users/$USERNAME/$target"
    # WSL paths should use Windows username
    target=$(expand_env_vars "$target")
    path=$(format_wsl_windows_path "$path")
  fi

  local path_obj=$(build_path_obj "$path" "$target")
  echo "$output" | jq -c ". + [$path_obj]"
}

process_path_entry() {
  local line="$1"
  local selector_override="$2"

  local path=$(echo "$line" | jq -r '.path')
  local override_target=$(echo "$line" | jq -r ".overrides[]? | select($selector_override) | .target")
  # Si hay override, úsalo; si no, usa el target normal
  local target=${override_target:-$(echo "$line" | jq -r '.target')}

  if [ "$target" = "null" ]; then
    target="$HOME"
  elif [[ "$target" == WSL://* ]]; then
    target="${target/WSL:\/\//WSL:\/\/}"
  elif [ "$(first_letter "$target")" != "/" ] && [ "$(first_letter "$target")" != "~" ]; then
    target="$HOME"/"$target"
  fi

  # Expand environment variables in target path
  target=$(expand_env_vars "$target")

  if is_debug; then
    echo "Path: $(printPath "${path//\\/\\\\}")"
    echo "Target: $(printPath $target)"
    echo "-----------"
  fi

  local output="[]"
  if [[ "$path" == *"*" ]]; then
    # Get the directory path without the asterisk
    local dir_path="${path%/*}"
    local abs_dir_path=$(get_abs_path "$dir_path")

    # Find all files and directories in the specified directory (first level only)
    if [ -d "$abs_dir_path" ]; then
      while IFS= read -r item; do
        # For each item, create a symlink to the target directory
        output=$(add_path_to_output "$item" "$target" "$output" "true")
      done < <(find "$abs_dir_path" -maxdepth 1 -mindepth 1)
    else
      printWarning "Directory not found: $abs_dir_path"
    fi
  else
    output=$(add_path_to_output "$path" "$target" "$output" "false")
  fi

  echo "$output"
}

get_paths() {
  local selector="$1"
  local selector_override="$2"
  local output="[]"

  while read -r line; do
    output=$(echo "$output" | jq -c ". + $(process_path_entry "$line" "$selector_override")")
  done < <(yq ".paths[] | select($selector)" $LISTFILES | jq -c '.')


  echo "$output"
}

get_linux_paths() {
  local current_distro=$(get_linux_distro)
  local is_wsl_env=$(is_wsl && echo "true" || echo "false")
  local selector='(
    .excludeFor == null or (
      .excludeFor[].platform != "linux" or (
        .excludeFor[].platform == "linux" and (
          (.excludeFor[].linuxDistro != null and .excludeFor[].linuxDistro != "'$current_distro'") or
          (.excludeFor[].wsl != null and .excludeFor[].wsl != '$is_wsl_env')
        )
      )
    )
  ) and (
    .onlyFor == null or (
      .onlyFor[].platform == "linux" and (
        (.onlyFor[].linuxDistro == null or .onlyFor[].linuxDistro == "'$current_distro'") and
        (.onlyFor[].wsl == null or .onlyFor[].wsl == '$is_wsl_env')
      )
    )
  )'
  local selector_override='.platform == "linux" and (
    (.linuxDistro == null or .linuxDistro == "'$current_distro'") and
    (.wsl == null or .wsl == '$is_wsl_env')
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
  local files="$(get_linux_paths)"
  if is_darwin; then
    files="$(get_darwin_paths)"
  fi

  echo "$files" | jq -c '.[]' | while read -r line; do
    path=$(echo "$line" | jq -r '.path')
    target=$(echo "$line" | jq -r '.target')
    make_symlink "$path" "$target"
  done
}

if [ "$EUID" = 0 ]; then
  printError "Don't run as root!"
  exit 1
fi

check_commands yq jq
USERNAME=$(get_windows_username)
main

run_elevated_powershell_script $TMP_SCRIPT

echo "Done!"
