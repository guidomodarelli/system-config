# Unified implementation: cx handles both safe and yolo modes.
cx() {
  # Added flag parsing: -m <model>, -re <reasoning_effort>, -c/--commit
  local model="gpt-5.4"
  local reasoning="medium"
  local yolo=""         # empty -> safe mode; set -> yolo mode
  local commit=""
  local rest=()
  local commit_prompt
  commit_prompt=$(cat <<'EOF'
create a commit with: Generate commit messages in conventional commit style, but omit the type prefix. Example: instead of 'feat: add new feature', write 'add new feature'. Do not include issue numbers. Use imperative mood (e.g., 'add feature', 'fix bug', 'update docs'). When mentioning functions or variables, wrap their names in «». Example: 'update function «myFunction» to handle edge cases'. If a variable starts with $, escape it with a backslash. Example: 'fix issue with \$var when it is null'. Replace backticks (`...`) with «...» formatting. Always include a detailed description after the commit title, separated by a blank line. The description should explain the reasoning behind the changes, any important implementation details, and potential impacts
EOF
)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      update)
        brew upgrade codex
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
      -c|--commit)
        commit=1
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

  if [[ -n "$commit" ]]; then
    yolo=1
    rest=("$commit_prompt")
  fi

  local cmd=(codex -m "$model" -c model_reasoning_effort="$reasoning")
  if [[ -n "$yolo" ]]; then
    cmd+=(--yolo)
  else
    cmd+=(--sandbox workspace-write --ask-for-approval on-failure)
  fi
  cmd+=(--search "${rest[@]}")
  echo "Running: ${cmd[*]}"
  "${cmd[@]}"
}

# Dangerous alias for codex (bypass approvals & sandbox)
cxd() {
  cx --yolo "$@"
}

# Completions: reuse same completion function for both.
compdef _cx cx cxd
