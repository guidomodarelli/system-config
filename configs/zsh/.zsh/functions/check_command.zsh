check_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    logError "Command '$cmd' not found"
    exit 1
  fi
}

check_commands() {
  for cmd in "$@"; do
    check_command "$cmd"
  done
}
