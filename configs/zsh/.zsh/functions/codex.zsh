cx() {
  if [[ "$1" == "update" ]]; then
    npm install -g @openai/codex@latest
  else
    codex -m gpt-5-codex -c model_reasoning_effort="high" --search "$@"
  fi
}