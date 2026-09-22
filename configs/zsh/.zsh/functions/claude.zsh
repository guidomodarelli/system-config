# Dangerous Claude Code wrapper: bypasses all permission checks.
ccd() {
  clear
  command claude --dangerously-skip-permissions --chrome "$@"
}

# Claude Code wrapper using the local GPT proxy configuration.
ccdg() {
  local -x ANTHROPIC_AUTH_TOKEN="dummy"
  local -x ANTHROPIC_BASE_URL="http://localhost:4141"
  local -x ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-luna[1m]"
  local -x ANTHROPIC_MODEL="opus"
  local -x CLAUDE_CODE_SUBAGENT_MODEL="gpt-5.6-luna[1m]"
  local -x CLAUDE_CODE_AUTO_COMPACT_WINDOW="850000"

  ccd "$@"
}

# Claude Code wrapper using the local GLM proxy configuration.
ccm() {
  local -x ANTHROPIC_AUTH_TOKEN="fc902628f1b98e9b0807f9a49cebee8460fed345b03a761c11349ca506083c7c"
  local -x ANTHROPIC_BASE_URL="http://127.0.0.1:22630"
  local -x ANTHROPIC_MODEL="opus"
  local -x CLAUDE_CODE_SUBAGENT_MODEL="anthropic/open-source/glm-5.3-flash[1m]"
  local -x ANTHROPIC_DEFAULT_OPUS_MODEL="anthropic/open-source/glm-5.3-flash[1m]"
  local -x CLAUDE_CODE_AUTO_COMPACT_WINDOW="850000"

  ccd "$@"
}
