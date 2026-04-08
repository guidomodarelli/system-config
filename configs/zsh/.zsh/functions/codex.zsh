# Returns the built-in prompt used by `cx --commit`.
_cx_commit_prompt() {
  local script_dir prompt_file
  script_dir="${${(%):-%x}:A:h}"
  prompt_file="${script_dir}/../../../.codex/commit_prompt.txt"
  prompt_file="${prompt_file:A}"

  if [[ -r "$prompt_file" ]]; then
    cat "$prompt_file"
  else
    echo "Error: commit prompt file not found: $prompt_file" >&2
    return 1
  fi
}

# Returns `-c` overrides to disable all configured MCP servers for the current run.
_cx_disable_mcp_config_args() {
  local -a disable_args
  local server_name

  while IFS= read -r server_name; do
    [[ -z "$server_name" ]] && continue
    disable_args+=(-c "mcp_servers.${server_name}.enabled=false")
  done < <(command codex mcp list 2>/dev/null | awk 'NF && $1 != "Name" { print $1 }')

  printf '%s\n' "${disable_args[@]}"
}

# Unified implementation: cx handles both safe and yolo modes.
cx() {
  # Added flag parsing: -m <model>, -re <reasoning_effort>, -c/--commit
  local model="gpt-5.3-codex"
  local reasoning="medium"
  local yolo=""         # empty -> safe mode; set -> yolo mode
  local commit=""
  local rest=()
  local mcp_config_args=()

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
    # `--commit` has priority over any user-provided query tokens.
    local commit_prompt
    commit_prompt="$(_cx_commit_prompt)" || return 1
    yolo=1
    rest=("$commit_prompt")
    mcp_config_args=("${(@f)$(_cx_disable_mcp_config_args)}")
  fi

  local cmd=(codex -m "$model" -c model_reasoning_effort="$reasoning")
  if (( ${#mcp_config_args[@]} > 0 )); then
    cmd+=("${mcp_config_args[@]}")
  fi
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
