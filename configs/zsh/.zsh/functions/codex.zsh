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
  local server_name plugin_id config_key
  local mcp_list_json=""
  typeset -A seen_config_keys

  mcp_list_json="$(command codex mcp list --json 2>/dev/null)"

  while IFS=$'\t' read -r server_name plugin_id; do
    [[ -z "$server_name" ]] && continue

    if [[ -n "$plugin_id" ]]; then
      config_key="plugins.\"${plugin_id}\".enabled=false"
    else
      config_key="mcp_servers.${server_name}.enabled=false"
    fi

    if [[ -z "${seen_config_keys[$config_key]}" ]]; then
      disable_args+=(-c "$config_key")
      seen_config_keys[$config_key]=1
    fi
  done < <(
    if [[ -n "$mcp_list_json" ]] && command -v jq >/dev/null 2>&1; then
      print -r -- "$mcp_list_json" \
        | command jq -r '
            .[]
            | select(.name != null and (.enabled != false))
            | (.transport.cwd // "") as $transport_cwd
            | ($transport_cwd | split("/")) as $cwd_parts
            | ($cwd_parts | index("cache")) as $cache_index
            | (
                if ($cache_index != null) and (($cwd_parts | length) > ($cache_index + 2))
                then ($cwd_parts[$cache_index + 2] + "@" + $cwd_parts[$cache_index + 1])
                else ""
                end
              ) as $plugin_id
            | [
                .name,
                $plugin_id
              ]
            | @tsv
          ' 2>/dev/null \
        | awk -F'\t' '!seen[$1]++'
    elif [[ -n "$mcp_list_json" ]] && command -v node >/dev/null 2>&1; then
      print -r -- "$mcp_list_json" \
        | command node -e '
            const fs = require("fs");
            const raw = fs.readFileSync(0, "utf8").trim();
            if (!raw) process.exit(0);
            let parsed;
            try {
              parsed = JSON.parse(raw);
            } catch {
              process.exit(0);
            }
            const servers = Array.isArray(parsed) ? parsed : [];
            const seen = new Set();
            const pluginPattern = /\/plugins\/cache\/([^/]+)\/([^/]+)\//;
            for (const server of servers) {
              if (!server || !server.name || server.enabled === false) continue;
              const cwd = String(server?.transport?.cwd ?? "").replace(/\\/g, "/");
              let pluginId = "";
              const match = cwd.match(pluginPattern);
              if (match) {
                pluginId = `${match[2]}@${match[1]}`;
              }
              const dedupeKey = `${server.name}\t${pluginId}`;
              if (seen.has(dedupeKey)) continue;
              seen.add(dedupeKey);
              process.stdout.write(`${server.name}\t${pluginId}\n`);
            }
          ' 2>/dev/null
    else
      command codex mcp list 2>/dev/null | awk '
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*Name[[:space:]]+/ { next }
        /^[[:space:]]*-+[[:space:]]*$/ { next }
        /^[[:space:]]*No[[:space:]]+MCP[[:space:]]+servers?.*$/ { next }
        {
          server_name = $1
          if (server_name == "" || server_name == "Name") {
            next
          }

          plugin_id = ""
          if (index($0, "/plugins/cache/") > 0) {
            split($0, path_split, "/plugins/cache/")
            tail_path = path_split[2]
            split(tail_path, plugin_parts, "/")
            if (plugin_parts[1] != "" && plugin_parts[2] != "") {
              plugin_id = plugin_parts[2] "@" plugin_parts[1]
            }
          }

          dedupe_key = server_name "\t" plugin_id
          if (!seen[dedupe_key]++) {
            print dedupe_key
          }
        }
      '
    fi
  )

  printf '%s\n' "${disable_args[@]}"
}

# Unified implementation: cx handles both safe and yolo modes.
cx() {
  clear

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
