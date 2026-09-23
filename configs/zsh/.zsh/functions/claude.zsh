# Dangerous Claude Code wrapper: bypasses all permission checks.
ccd() {
  clear
  command claude --dangerously-skip-permissions --chrome "$@"
}

# Claude Code wrapper using the local GPT proxy configuration.
ccg() {
  local -x ANTHROPIC_AUTH_TOKEN="dummy"
  local -x ANTHROPIC_BASE_URL="http://localhost:4141"
  local -x ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-6-luna[1m]"
  local -x ANTHROPIC_MODEL="opus"
  local -x CLAUDE_CODE_SUBAGENT_MODEL="gpt-6-luna[1m]"
  local -x CLAUDE_CODE_ATTRIBUTION_HEADER="0"
  local -x CLAUDE_CODE_AUTO_COMPACT_WINDOW="850000"

  ccd "$@"
}
