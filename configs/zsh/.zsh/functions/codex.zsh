# Returns the built-in prompt used by `cx --commit`.
_cx_commit_prompt() {
  local script_dir prompt_file
  script_dir="${${(%):-%x}:A:h}"
  prompt_file="${script_dir}/../../../.codex/commit_prompt.md"
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
  done < <(
    if command -v jq >/dev/null 2>&1; then
      command codex mcp list --json 2>/dev/null \
        | command jq -r '.[] | select(.name != null and (.enabled != false)) | .name' 2>/dev/null \
        | awk '!seen[$0]++'
    else
      command codex mcp list 2>/dev/null | awk '
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*Name[[:space:]]+/ { next }
        /^[[:space:]]*-+[[:space:]]*$/ { next }
        !seen[$1]++ { print $1 }
      '
    fi
  )

  printf '%s\n' "${disable_args[@]}"
}

# Unified implementation: cx handles both safe and yolo modes.
cx() {
  # Added flag parsing: -m <model>, -re <reasoning_effort>, -c/--commit, --no-mcps
  local model="gpt-5.3-codex"
  local reasoning="medium"
  local yolo=""         # empty -> safe mode; set -> yolo mode
  local commit=""
  local no_mcps=""
  local rest=()
  local mcp_config_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      upgrade)
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
      --no-mcps)
        no_mcps=1
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
    local disable_mcp_config_output
    commit_prompt="$(_cx_commit_prompt)" || return 1
    disable_mcp_config_output="$(_cx_disable_mcp_config_args)"
    yolo=1
    rest=("$commit_prompt")
    if [[ -n "$disable_mcp_config_output" ]]; then
      mcp_config_args=("${(@f)disable_mcp_config_output}")
    else
      mcp_config_args=()
    fi
  elif [[ -n "$no_mcps" ]]; then
    local disable_mcp_config_output
    disable_mcp_config_output="$(_cx_disable_mcp_config_args)"
    if [[ -n "$disable_mcp_config_output" ]]; then
      mcp_config_args=("${(@f)disable_mcp_config_output}")
    else
      mcp_config_args=()
    fi
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
