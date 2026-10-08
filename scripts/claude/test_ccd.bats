#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export FAKE_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
  export CLAUDE_ARGS_FILE="${BATS_TEST_TMPDIR}/claude-args"
  export CLAUDE_ENV_FILE="${BATS_TEST_TMPDIR}/claude-env"

  mkdir -p "${FAKE_BIN_DIR}"

  cat > "${FAKE_BIN_DIR}/claude" <<'BASH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${CLAUDE_ARGS_FILE}"
{
  printf 'ANTHROPIC_AUTH_TOKEN=%s\n' "${ANTHROPIC_AUTH_TOKEN-}"
  printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL-}"
  printf 'ANTHROPIC_DEFAULT_OPUS_MODEL=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL-}"
  printf 'ANTHROPIC_MODEL=%s\n' "${ANTHROPIC_MODEL-}"
  printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL-}"
  printf 'CLAUDE_CODE_EFFORT_LEVEL=%s\n' "${CLAUDE_CODE_EFFORT_LEVEL-}"
  printf 'CLAUDE_CODE_ATTRIBUTION_HEADER=%s\n' "${CLAUDE_CODE_ATTRIBUTION_HEADER-}"
  printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=%s\n' "${CLAUDE_CODE_AUTO_COMPACT_WINDOW-}"
} > "${CLAUDE_ENV_FILE}"
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
  [ "${claude_args[1]}" = '--chrome' ]
  [ "${claude_args[2]}" = '--model' ]
  [ "${claude_args[3]}" = 'opus' ]
  [ "${claude_args[4]}" = 'prompt con espacios' ]
}

@test "ccg fija envs del proxy, reenvía argumentos y no contamina el shell" {
  run zsh -c '
    clear() { :; }
    unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_MODEL
    unset CLAUDE_CODE_SUBAGENT_MODEL CLAUDE_CODE_ATTRIBUTION_HEADER CLAUDE_CODE_AUTO_COMPACT_WINDOW
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccg --model opus "prompt con espacios"
  '

  [ "$status" -eq 0 ]
  grep -Fx 'ANTHROPIC_AUTH_TOKEN=dummy' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_BASE_URL=http://localhost:4141' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_DEFAULT_OPUS_MODEL=gpt-6-luna[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_MODEL=opus' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=gpt-6-luna[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_EFFORT_LEVEL=max' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_ATTRIBUTION_HEADER=0' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=850000' "${CLAUDE_ENV_FILE}"
  claude_args=()
  while IFS= read -r claude_arg; do
    claude_args+=("$claude_arg")
  done < "${CLAUDE_ARGS_FILE}"
  [ "${claude_args[0]}" = '--dangerously-skip-permissions' ]
  [ "${claude_args[1]}" = '--chrome' ]
  [ "${claude_args[2]}" = '--model' ]
  [ "${claude_args[3]}" = 'opus' ]
  [ "${claude_args[4]}" = 'prompt con espacios' ]
}

@test "ccm fija envs del proxy y selecciona GLM" {
  run zsh -c '
    clear() { :; }
    unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_MODEL CLAUDE_CODE_SUBAGENT_MODEL
    unset ANTHROPIC_DEFAULT_OPUS_MODEL CLAUDE_CODE_AUTO_COMPACT_WINDOW
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccm --model opus "prompt con espacios"
  '

  [ "$status" -eq 0 ]
  grep -q '^ANTHROPIC_AUTH_TOKEN=.' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_BASE_URL=http://127.0.0.1:22630' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_MODEL=opus' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=anthropic/open-source/glm-5.3-flash[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_DEFAULT_OPUS_MODEL=anthropic/open-source/glm-5.3-flash[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=850000' "${CLAUDE_ENV_FILE}"
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
