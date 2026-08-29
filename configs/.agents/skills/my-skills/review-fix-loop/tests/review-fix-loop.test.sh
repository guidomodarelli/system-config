#!/usr/bin/env bash
set -euo pipefail

HELPER=${HELPER:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/review-fix-loop"}
failures=0
tests_run=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  return 1
}

assert_contains() {
  local file=$1
  local expected=$2
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local file=$1
  local unexpected=$2
  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}

assert_calls() {
  local expected=$1
  local actual
  actual=$(paste -sd ' ' "$CALL_LOG")
  [[ "$actual" == "$expected" ]] || fail "expected calls '$expected', got '$actual'"
}

setup_fixture() {
  TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/review-fix-loop-test.XXXXXX")
  REPOSITORY="$TEST_ROOT/repository"
  FAKE_BIN="$TEST_ROOT/bin"
  CALL_LOG="$TEST_ROOT/calls.log"
  STDOUT_FILE="$TEST_ROOT/stdout"
  STDERR_FILE="$TEST_ROOT/stderr"

  mkdir -p "$REPOSITORY" "$FAKE_BIN"
  : > "$CALL_LOG"

  git -C "$REPOSITORY" init -q -b main
  git -C "$REPOSITORY" config user.name 'Code Review Test'
  git -C "$REPOSITORY" config user.email 'code-review-test@example.com'
  printf 'base\n' > "$REPOSITORY/file.txt"
  git -C "$REPOSITORY" add file.txt
  git -C "$REPOSITORY" commit -qm 'base'
  git -C "$REPOSITORY" checkout -qb feature/test
  printf 'dirty\n' >> "$REPOSITORY/file.txt"

  cat > "$FAKE_BIN/provider" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
provider_name=$(basename "$0")
printf '%s\n' "$provider_name" >> "$CALL_LOG"
printf '%s\n' "$*" >> "$CALL_LOG.args"
printf 'ANTHROPIC_MODEL=%s\n' "${ANTHROPIC_MODEL:-}" >> "$CALL_LOG.args"
printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}" >> "$CALL_LOG.args"
printf 'ANTHROPIC_AUTH_TOKEN_SET=%s\n' "${ANTHROPIC_AUTH_TOKEN:+1}" >> "$CALL_LOG.args"
printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL:-}" >> "$CALL_LOG.args"
printf 'ANTHROPIC_DEFAULT_OPUS_MODEL=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" >> "$CALL_LOG.args"
printf 'ANTHROPIC_DEFAULT_SONNET_MODEL=%s\n' "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" >> "$CALL_LOG.args"
printf 'CLAUDE_CODE_USE_VERTEX=%s\n' "${CLAUDE_CODE_USE_VERTEX:-}" >> "$CALL_LOG.args"
printf 'CLAUDE_CODE_USE_BEDROCK=%s\n' "${CLAUDE_CODE_USE_BEDROCK:-}" >> "$CALL_LOG.args"
printf 'MCP_CONNECT_TIMEOUT_MS=%s\n' "${MCP_CONNECT_TIMEOUT_MS:-}" >> "$CALL_LOG.args"
case "$provider_name" in
  claude)
    sleep "${FAKE_CLAUDE_SLEEP_SECONDS:-0}"
    printf '%s\n' "${FAKE_CLAUDE_OUTPUT:-No actionable findings.}"
    exit "${FAKE_CLAUDE_STATUS:-0}"
    ;;
  codex)
    sleep "${FAKE_CODEX_SLEEP_SECONDS:-0}"
    printf '%s\n' "${FAKE_CODEX_OUTPUT:-No actionable findings.}"
    exit "${FAKE_CODEX_STATUS:-0}"
    ;;
esac
EOF
  chmod 700 "$FAKE_BIN/provider"
  ln -s provider "$FAKE_BIN/claude"
  ln -s provider "$FAKE_BIN/codex"

  export TEST_ROOT REPOSITORY FAKE_BIN CALL_LOG STDOUT_FILE STDERR_FILE
  export FAKE_CLAUDE_STATUS=0 FAKE_CODEX_STATUS=0
  export FAKE_CLAUDE_SLEEP_SECONDS=0 FAKE_CODEX_SLEEP_SECONDS=0
  export FAKE_CLAUDE_OUTPUT='No actionable findings.'
  export FAKE_CODEX_OUTPUT='No actionable findings.'
  export ANTHROPIC_BASE_URL='http://inherited-config.test'
  export ANTHROPIC_AUTH_TOKEN='inherited-token'
  export ANTHROPIC_MODEL='inherited-model'
}

teardown_fixture() {
  rm -rf -- "$TEST_ROOT"
}

run_helper() {
  local status
  set +e
  (
    cd "$REPOSITORY"
    "$HELPER" \
      --mode local \
      --claude-bin "$FAKE_BIN/claude" \
      --codex-bin "$FAKE_BIN/codex" \
      "$@"
  ) > "$STDOUT_FILE" 2> "$STDERR_FILE"
  status=$?
  set -e
  return "$status"
}

test_auto_stops_after_claude_success() {
  setup_fixture
  trap teardown_fixture EXIT

  run_helper --provider auto
  assert_calls 'claude'
  assert_contains "$STDOUT_FILE" 'provider order: claude-copilot -> claude -> codex'
  assert_contains "$STDOUT_FILE" 'code-review completed by provider: claude'
}

test_claude_copilot_uses_configured_profile() {
  setup_fixture
  trap teardown_fixture EXIT
  run_helper -p claude-copilot
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_MODEL=gpt-5.6-terra[1m]'
  assert_contains "$CALL_LOG.args" 'CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-terra[1m]'
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_BASE_URL=http://localhost:4141'
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_AUTH_TOKEN_SET=1'
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_DEFAULT_OPUS_MODEL=gpt-5.6-terra[1m]'
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_DEFAULT_SONNET_MODEL=gpt-5.6-terra[1m]'
  assert_contains "$CALL_LOG.args" 'CLAUDE_CODE_USE_VERTEX=0'
  assert_contains "$CALL_LOG.args" 'CLAUDE_CODE_USE_BEDROCK=0'
  assert_contains "$CALL_LOG.args" 'MCP_CONNECT_TIMEOUT_MS=20000'
  assert_not_contains "$CALL_LOG.args" '--model'
  assert_not_contains "$CALL_LOG.args" '--effort'
  assert_not_contains "$CALL_LOG.args" 'ANTHROPIC_BASE_URL=http://inherited-config.test'
}

test_claude_direct_bypasses_copilot_api() {
  setup_fixture
  trap teardown_fixture EXIT

  run_helper -p claude
  assert_contains "$CALL_LOG.args" '--setting-sources project,local'
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_BASE_URL='
  assert_contains "$CALL_LOG.args" 'ANTHROPIC_AUTH_TOKEN_SET='
  assert_contains "$CALL_LOG.args" 'CLAUDE_CODE_SUBAGENT_MODEL='
  assert_not_contains "$CALL_LOG.args" 'ANTHROPIC_BASE_URL=http://inherited-config.test'
  assert_not_contains "$CALL_LOG.args" 'ANTHROPIC_AUTH_TOKEN_SET=1'
}

test_short_provider_selects_codex_only() {
  setup_fixture
  trap teardown_fixture EXIT

  run_helper -p codex
  assert_calls 'codex'
  assert_contains "$STDOUT_FILE" 'provider: codex'
}

test_quota_failure_falls_back_to_codex() {
  setup_fixture
  trap teardown_fixture EXIT
  export FAKE_CLAUDE_STATUS=1
  export FAKE_CLAUDE_OUTPUT='You hit your spend cap set by the owner of your workspace.'

  run_helper
  assert_calls 'claude claude codex'
  assert_contains "$STDERR_FILE" 'quota_exceeded'
  assert_contains "$STDOUT_FILE" 'code-review completed by provider: codex'
}

test_timeout_falls_back_to_codex() {
  setup_fixture
  trap teardown_fixture EXIT
  export FAKE_CLAUDE_SLEEP_SECONDS=2

  run_helper --timeout-seconds 1
  assert_calls 'claude claude codex'
  assert_contains "$STDERR_FILE" 'infrastructure_error'
  assert_contains "$STDOUT_FILE" 'code-review completed by provider: codex'
}

test_missing_claude_falls_back_to_codex() {
  setup_fixture
  trap teardown_fixture EXIT

  set +e
  (
    cd "$REPOSITORY"
    "$HELPER" --mode local \
      --claude-bin "$FAKE_BIN/missing-claude" \
      --codex-bin "$FAKE_BIN/codex"
  ) > "$STDOUT_FILE" 2> "$STDERR_FILE"
  status=$?
  set -e

  [[ "$status" -eq 0 ]] || fail "expected fallback success, got exit $status"
  assert_calls 'codex'
  assert_contains "$STDERR_FILE" 'provider_unavailable'
}

test_auth_failure_reaches_codex() {
  setup_fixture
  trap teardown_fixture EXIT
  export FAKE_CLAUDE_STATUS=1
  export FAKE_CLAUDE_OUTPUT='Authentication required. Run login.'

  run_helper
  assert_calls 'claude claude codex'
  assert_contains "$STDERR_FILE" 'not_authenticated'
  assert_contains "$STDOUT_FILE" 'code-review completed by provider: codex'
}

test_explicit_provider_never_falls_back() {
  setup_fixture
  trap teardown_fixture EXIT
  export FAKE_CLAUDE_STATUS=1
  export FAKE_CLAUDE_OUTPUT='You hit your spend cap.'

  if run_helper -p claude; then
    fail 'expected explicit Claude failure'
  fi
  assert_calls 'claude'
  assert_not_contains "$CALL_LOG" 'codex'
}

test_unknown_failure_never_falls_back() {
  setup_fixture
  trap teardown_fixture EXIT
  export FAKE_CLAUDE_STATUS=1
  export FAKE_CLAUDE_OUTPUT='Unexpected adapter response.'

  if run_helper; then
    fail 'expected unknown provider failure'
  fi
  assert_calls 'claude'
  assert_contains "$STDERR_FILE" 'unknown_provider_error'
}

test_completed_review_with_findings_never_falls_back() {
  setup_fixture
  trap teardown_fixture EXIT
  export FAKE_CLAUDE_OUTPUT='Finding: file.txt:1 produces incorrect behavior.'

  run_helper
  assert_calls 'claude'
  assert_contains "$STDOUT_FILE" 'Finding: file.txt:1'
  assert_contains "$STDOUT_FILE" 'code-review completed by provider: claude'
}

test_failed_parallel_tests_do_not_trigger_fallback() {
  setup_fixture
  trap teardown_fixture EXIT

  if run_helper --parallel-tests false; then
    fail 'expected failed tests to fail closeout'
  fi
  assert_calls 'claude'
  assert_contains "$STDOUT_FILE" 'tests exit: 1'
}

test_dry_run_does_not_invoke_providers() {
  setup_fixture
  trap teardown_fixture EXIT

  run_helper --dry-run
  [[ ! -s "$CALL_LOG" ]] || fail 'dry-run invoked a provider'
  assert_contains "$STDOUT_FILE" 'review[claude-copilot]:'
  assert_contains "$STDOUT_FILE" 'review[claude]:'
  assert_contains "$STDOUT_FILE" 'review[codex]:'
}

test_output_captures_provider_result() {
  setup_fixture
  trap teardown_fixture EXIT
  local saved_output="$TEST_ROOT/review.log"

  run_helper -p codex --output "$saved_output"
  assert_contains "$saved_output" '--- codex review output ---'
  assert_contains "$saved_output" 'No actionable findings.'
}

test_invalid_provider_returns_usage_error() {
  setup_fixture
  trap teardown_fixture EXIT

  set +e
  run_helper -p invalid
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "expected exit 2, got $status"
  [[ ! -s "$CALL_LOG" ]] || fail 'invalid provider invoked a binary'
  assert_contains "$STDERR_FILE" 'invalid --provider: invalid'
}

test_invalid_timeout_returns_usage_error() {
  setup_fixture
  trap teardown_fixture EXIT

  set +e
  run_helper --timeout-seconds invalid
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "expected exit 2, got $status"
  assert_contains "$STDERR_FILE" 'invalid --timeout-seconds: invalid'
}

run_test() {
  local name=$1
  local test_function=$2
  tests_run=$((tests_run + 1))
  if ("$test_function"); then
    printf 'ok %d - %s\n' "$tests_run" "$name"
  else
    failures=$((failures + 1))
    printf 'not ok %d - %s\n' "$tests_run" "$name"
  fi
}

run_test 'auto stops after Claude success' test_auto_stops_after_claude_success
run_test 'Claude Copilot uses configured profile' test_claude_copilot_uses_configured_profile
run_test 'Claude direct bypasses Copilot API' test_claude_direct_bypasses_copilot_api
run_test 'short provider flag selects Codex only' test_short_provider_selects_codex_only
run_test 'quota failure falls back to Codex' test_quota_failure_falls_back_to_codex
run_test 'timeout falls back to Codex' test_timeout_falls_back_to_codex
run_test 'missing Claude falls back to Codex' test_missing_claude_falls_back_to_codex
run_test 'auth failure reaches Codex' test_auth_failure_reaches_codex
run_test 'explicit provider never falls back' test_explicit_provider_never_falls_back
run_test 'unknown failure never falls back' test_unknown_failure_never_falls_back
run_test 'completed review with findings never falls back' test_completed_review_with_findings_never_falls_back
run_test 'failed parallel tests do not trigger fallback' test_failed_parallel_tests_do_not_trigger_fallback
run_test 'dry-run does not invoke providers' test_dry_run_does_not_invoke_providers
run_test 'output captures provider result' test_output_captures_provider_result
run_test 'invalid provider returns usage error' test_invalid_provider_returns_usage_error
run_test 'invalid timeout returns usage error' test_invalid_timeout_returns_usage_error

if [[ "$failures" -ne 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests_run" >&2
  exit 1
fi

printf '%d tests passed\n' "$tests_run"
