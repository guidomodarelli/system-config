cx() {
  if [[ "$1" == "update" ]]; then
    npm install -g @openai/codex@latest
  else
    codex -m gpt-5-codex -c model_reasoning_effort="high" --sandbox workspace-write --ask-for-approval on-failure --search "$@"
  fi
}

# Dangerous alias for codex (bypass approvals & sandbox)
cxd() {
  codex -m gpt-5-codex -c model_reasoning_effort="medium" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write --search "$@"
}

# Dangerous alias for codex with high reasoning (bypass approvals & sandbox)
cxhd() {
  codex -m gpt-5-codex -c model_reasoning_effort="high" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write --search "$@"
}
