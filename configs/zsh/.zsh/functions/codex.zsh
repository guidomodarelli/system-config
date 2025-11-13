# Unified implementation: cx handles both safe and yolo modes.
cx() {
  # Added flag parsing: -m <model>, -re <reasoning_effort>
  local model="gpt-5-codex-mini"
  local reasoning="high"
  local yolo=""         # empty -> safe mode; set -> yolo mode
  local rest=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      update)
        npm install -g @openai/codex@latest
        return
        ;;
      -m)
        shift
        [[ -n "$1" ]] && model="$1"
        shift
        ;;
      -re)
        shift
        [[ -n "$1" ]] && reasoning="$1"
        shift
        ;;
      --yolo)          # internal flag used by cxd
        yolo=1
        shift
        ;;
      --)
        shift
        rest+=("$@")
        break
        ;;
      *)
        rest+=("$1")
        shift
        ;;
    esac
  done

  local cmd=(codex -m "$model" -c model_reasoning_effort="$reasoning")
  if [[ -n "$yolo" ]]; then
    cmd+=(--yolo)
  else
    cmd+=(--sandbox workspace-write --ask-for-approval on-failure)
  fi
  cmd+=(--enable web_search_request "${rest[@]}")
  "${cmd[@]}"
}

# Dangerous alias for codex (bypass approvals & sandbox)
cxd() {
  cx --yolo "$@"
}

# Completions: reuse same completion function for both.
compdef _cx cx cxd
