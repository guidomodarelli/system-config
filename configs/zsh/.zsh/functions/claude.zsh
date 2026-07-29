# Dangerous Claude Code wrapper: bypasses all permission checks.
ccd() {
  clear
  command claude --dangerously-skip-permissions "$@"
}
