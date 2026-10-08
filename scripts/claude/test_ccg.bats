#!/usr/bin/env bats

setup() {
  # Solo el proceso de test simula entornos; nunca ejecuta Claude real.
  unset CODEX_THREAD_ID CODEX_SESSION_ID CODEX_CI
  export CCG_TEST_TMPDIR="$(mktemp -d "${BATS_TMPDIR:-/tmp}/ccg-test.XXXXXX")"
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export CLAUDE_ARGS_FILE="${CCG_TEST_TMPDIR}/claude-args"
  mkdir -p "${CCG_TEST_TMPDIR}/bin"

  # El CLI externo se reemplaza para observar su invocación sin abrir Claude.
  cat > "${CCG_TEST_TMPDIR}/bin/claude" <<'BASH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${CLAUDE_ARGS_FILE}"
exit "${CLAUDE_EXIT_STATUS:-0}"
BASH
  chmod +x "${CCG_TEST_TMPDIR}/bin/claude"
  export PATH="${CCG_TEST_TMPDIR}/bin:${PATH}"
}

teardown() {
  rm -rf "${CCG_TEST_TMPDIR:?}"
}

@test "debería rechazar ccg cuando Codex aporta un thread id" {
  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    CODEX_THREAD_ID=test-thread ccg "prompt de prueba"
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *'ejecución prohibida desde Codex'* ]]
  [ ! -e "${CLAUDE_ARGS_FILE}" ]
}

@test "debería rechazar ccg cuando Codex aporta un session id" {
  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    CODEX_SESSION_ID=test-session ccg "prompt de prueba"
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *'ejecución prohibida desde Codex'* ]]
  [ ! -e "${CLAUDE_ARGS_FILE}" ]
}

@test "debería rechazar ccg cuando Codex activa el modo CI" {
  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    CODEX_CI=1 ccg "prompt de prueba"
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *'ejecución prohibida desde Codex'* ]]
  [ ! -e "${CLAUDE_ARGS_FILE}" ]
}

@test "debería reenviar argumentos y conservar el estado de Claude fuera de Codex" {
  # Simula una sesión del usuario en un proceso aislado con el CLI falso.
  run env -u CODEX_THREAD_ID -u CODEX_SESSION_ID CODEX_CI=0 CLAUDE_EXIT_STATUS=7 zsh -c '
    clear() { :; }
    source "${TEST_REPO_ROOT}/configs/zsh/.zsh/functions/claude.zsh"
    ccg --model opus "prompt con espacios"
  '
  [ "$status" -eq 7 ]
  claude_args=()
  while IFS= read -r claude_arg; do
    claude_args+=("$claude_arg")
  done < "${CLAUDE_ARGS_FILE}"
  [ "${#claude_args[@]}" -eq 5 ]
  [ "${claude_args[0]}" = '--dangerously-skip-permissions' ]
  [ "${claude_args[1]}" = '--chrome' ]
  [ "${claude_args[2]}" = '--model' ]
  [ "${claude_args[3]}" = 'opus' ]
  [ "${claude_args[4]}" = 'prompt con espacios' ]
}
