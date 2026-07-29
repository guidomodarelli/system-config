#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export FAKE_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
  export CLAUDE_ARGS_FILE="${BATS_TEST_TMPDIR}/claude-args"

  mkdir -p "${FAKE_BIN_DIR}"

  cat > "${FAKE_BIN_DIR}/claude" <<'BASH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${CLAUDE_ARGS_FILE}"
exit "${CLAUDE_EXIT_STATUS:-0}"
BASH
  chmod +x "${FAKE_BIN_DIR}/claude"

  export PATH="${FAKE_BIN_DIR}:${PATH}"
}

@test "activa bypass de permisos y reenvía argumentos sin alterarlos" {
  run zsh -c '
    clear() { :; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccd --model opus "prompt con espacios"
  '

  [ "$status" -eq 0 ]
  claude_args=()
  while IFS= read -r claude_arg; do
    claude_args+=("$claude_arg")
  done < "${CLAUDE_ARGS_FILE}"
  [ "${claude_args[0]}" = '--dangerously-skip-permissions' ]
  [ "${claude_args[1]}" = '--model' ]
  [ "${claude_args[2]}" = 'opus' ]
  [ "${claude_args[3]}" = 'prompt con espacios' ]
}

@test "propaga estado de salida de Claude Code" {
  export CLAUDE_EXIT_STATUS=23

  run zsh -c '
    clear() { :; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccd
  '

  [ "$status" -eq 23 ]
}
