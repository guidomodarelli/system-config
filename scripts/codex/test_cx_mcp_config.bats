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
    "mcmemory-mcp": {}
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
      "cwd": null
    }
  },
  {
    "name": "mcmemory-mcp",
    "enabled": true,
    "transport": {
      "type": "stdio",
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

@test "cx usa gpt-6.1-sol con esfuerzo medium por defecto" {
  run zsh -c '
    compdef() { :; }
    clear() { :; }
    codex() { printf "%s\n" "$@"; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/codex.zsh"
    cx
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *$'-m\ngpt-6.1-sol\n-c\nmodel_reasoning_effort=medium'* ]]
}

@test "cx --commit usa gpt-6-luna con esfuerzo max por defecto" {
  run zsh -c '
    compdef() { :; }
    clear() { :; }
    codex() { printf "%s\n" "$@"; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/codex.zsh"
    cx --commit
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *$'-m\ngpt-6-luna\n-c\nmodel_reasoning_effort=max'* ]]
}

@test "cxd usa gpt-6.1-sol con esfuerzo medium por defecto" {
  run zsh -c '
    compdef() { :; }
    clear() { :; }
    codex() { printf "%s\n" "$@"; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/codex.zsh"
    cxd
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *$'-m\ngpt-6.1-sol\n-c\nmodel_reasoning_effort=medium'* ]]
}
