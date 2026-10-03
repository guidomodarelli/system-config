# Dangerous Claude Code wrapper: bypasses all permission checks.
ccd() {
  clear
  command claude --dangerously-skip-permissions --chrome "$@"
}

# Wrapper de Claude Code con proxy GPT local, reservado al usuario.
# Codex tiene prohibido invocar ccg o eludir esta protección.
ccg() {
  if [[ -n "${CODEX_THREAD_ID-}" || -n "${CODEX_SESSION_ID-}" || "${CODEX_CI-}" == "1" ]]; then
    print -u2 -- 'ccg: ejecución prohibida desde Codex; reservado al usuario.'
    return 1
  fi

  local -x ANTHROPIC_AUTH_TOKEN="dummy"
  local -x ANTHROPIC_BASE_URL="http://localhost:4141"
  local -x ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-luna[1m]"
  local -x ANTHROPIC_MODEL="opus"
  local -x CLAUDE_CODE_SUBAGENT_MODEL="gpt-5.6-luna[1m]"
  local -x CLAUDE_CODE_EFFORT_LEVEL="max"
  local -x CLAUDE_CODE_ATTRIBUTION_HEADER="0"
  local -x CLAUDE_CODE_AUTO_COMPACT_WINDOW="850000"

  ccd "$@"
}
