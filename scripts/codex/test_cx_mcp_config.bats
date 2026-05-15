#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export CODEX_HOME="${BATS_TEST_TMPDIR}/codex-home"
  export FAKE_BIN_DIR="${BATS_TEST_TMPDIR}/bin"

  mkdir -p "${FAKE_BIN_DIR}"
  mkdir -p "${CODEX_HOME}/plugins/cache/tech-plugins-marketplace/meli-claude-memory/1.1.0/.codex-plugin"
  mkdir -p "${CODEX_HOME}/plugins/cache/tech-plugins-marketplace/meli-claude-memory/1.1.0/codex"

  cat > "${CODEX_HOME}/plugins/cache/tech-plugins-marketplace/meli-claude-memory/1.1.0/.codex-plugin/plugin.json" <<'JSON'
{
  "name": "meli-claude-memory",
  "version": "1.1.0",
  "mcpServers": "./codex/.mcp.json"
}
JSON

  cat > "${CODEX_HOME}/plugins/cache/tech-plugins-marketplace/meli-claude-memory/1.1.0/codex/.mcp.json" <<'JSON'
{
  "mcpServers": {
    "mcmemory-mcp": {
      "command": "mcp-remote-proxy",
      "args": ["https://km-dev-mcp.melioffice.com/mcp", "--transport", "http"]
    }
  }
}
JSON

  cat > "${FAKE_BIN_DIR}/codex" <<'BASH'
#!/usr/bin/env bash
if [[ "$1" == "mcp" && "$2" == "list" && "$3" == "--json" ]]; then
  cat <<'JSON'
[
  {
    "name": "backend",
    "enabled": true,
    "transport": {
      "type": "stdio",
      "command": "mcp-remote-proxy",
      "args": ["https://mcp.melioffice.com/namespaces/backend/mcp", "--transport", "http"],
      "cwd": null
    }
  },
  {
    "name": "mcmemory-mcp",
    "enabled": true,
    "transport": {
      "type": "stdio",
      "command": "mcp-remote-proxy",
      "args": ["https://km-dev-mcp.melioffice.com/mcp", "--transport", "http"],
      "cwd": null
    }
  }
]
JSON
  exit 0
fi

exit 1
BASH
  chmod +x "${FAKE_BIN_DIR}/codex"

  export PATH="${FAKE_BIN_DIR}:${PATH}"
}

@test "deshabilita el plugin cuando un MCP de plugin no expone cwd" {
  run zsh -c '
    compdef() { :; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/codex.zsh"
    _cx_disable_mcp_config_args
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *'plugins."meli-claude-memory@tech-plugins-marketplace".enabled=false'* ]]
  [[ "$output" != *'mcp_servers.mcmemory-mcp.enabled=false'* ]]
}

@test "mantiene overrides mcp_servers para MCPs definidos en config.toml" {
  run zsh -c '
    compdef() { :; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/codex.zsh"
    _cx_disable_mcp_config_args
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *'mcp_servers.backend.enabled=false'* ]]
}
