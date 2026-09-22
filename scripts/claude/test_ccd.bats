#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export FAKE_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
  export CLAUDE_ARGS_FILE="${BATS_TEST_TMPDIR}/claude-args"
  export CLAUDE_ENV_FILE="${BATS_TEST_TMPDIR}/claude-env"
  export CCDG_POST_ENV_FILE="${BATS_TEST_TMPDIR}/ccdg-post-env"
  export CCM_POST_ENV_FILE="${BATS_TEST_TMPDIR}/ccm-post-env"

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

@test "ccdg fija envs del proxy, reenvía argumentos y no contamina el shell" {
  run zsh -c '
    clear() { :; }
    unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_MODEL
    unset CLAUDE_CODE_SUBAGENT_MODEL CLAUDE_CODE_ATTRIBUTION_HEADER CLAUDE_CODE_AUTO_COMPACT_WINDOW
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccdg --model opus "prompt con espacios"
    printf "%s\\n" "${ANTHROPIC_AUTH_TOKEN-unset}" > "${CCDG_POST_ENV_FILE}"
  '

  [ "$status" -eq 0 ]
  grep -Fx 'ANTHROPIC_AUTH_TOKEN=dummy' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_BASE_URL=http://localhost:4141' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_DEFAULT_OPUS_MODEL=gpt-5.6-luna[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_MODEL=opus' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-luna[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_ATTRIBUTION_HEADER=0' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=850000' "${CLAUDE_ENV_FILE}"
  [ "$(<"${CCDG_POST_ENV_FILE}")" = 'unset' ]

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

@test "ccm fija envs del proxy y conserva el token provisto por el entorno" {
  export ANTHROPIC_AUTH_TOKEN='test-token'

  run zsh -c '
    clear() { :; }
    unset ANTHROPIC_BASE_URL ANTHROPIC_MODEL CLAUDE_CODE_SUBAGENT_MODEL
    unset ANTHROPIC_DEFAULT_OPUS_MODEL CLAUDE_CODE_AUTO_COMPACT_WINDOW
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccm --model opus "prompt con espacios"
    printf "%s\\n" "${ANTHROPIC_AUTH_TOKEN-unset}" > "${CCM_POST_ENV_FILE}"
  '

  [ "$status" -eq 0 ]
  grep -Fx 'ANTHROPIC_AUTH_TOKEN=test-token' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_BASE_URL=http://127.0.0.1:22630' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_MODEL=opus' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=anthropic/open-source/glm-5.3-flash[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'ANTHROPIC_DEFAULT_OPUS_MODEL=anthropic/open-source/glm-5.3-flash[1m]' "${CLAUDE_ENV_FILE}"
  grep -Fx 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=850000' "${CLAUDE_ENV_FILE}"
  [ "$(<"${CCM_POST_ENV_FILE}")" = 'test-token' ]
}

@test "ccm falla de forma explícita cuando falta el token" {
  run zsh -c '
    clear() { :; }
    unset ANTHROPIC_AUTH_TOKEN
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccm
  '

  [ "$status" -eq 1 ]
  [[ "$output" == *"falta ANTHROPIC_AUTH_TOKEN"* ]]
  [ ! -e "${CLAUDE_ENV_FILE}" ]
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
