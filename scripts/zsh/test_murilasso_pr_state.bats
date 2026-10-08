#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export FAKE_BIN_DIR="${BATS_TEST_TMPDIR}/bin"

  mkdir -p "${FAKE_BIN_DIR}"
  cat > "${FAKE_BIN_DIR}/gh" <<'BASH'
#!/usr/bin/env bash

arguments="$*"
if [[ "$arguments" == *"pr list"* ]]; then
  exit 0
fi

if [[ "$arguments" == *"pr view"* ]]; then
  if [[ "$arguments" == *'select(.state == "OPEN")'* ]] && [[ "${GH_PR_STATE:-}" != "OPEN" ]]; then
    exit 0
  fi
  printf '%s\n%s\n' "${GH_PR_URL:-https://github.com/example/repo/pull/42}" "${GH_PR_STATE:-CLOSED}"
fi
BASH
  chmod +x "${FAKE_BIN_DIR}/gh"
  export PATH="${FAKE_BIN_DIR}:${PATH}"
}

@test "filtra PR cerrado en ramas base" {
  export GH_PR_STATE='CLOSED'

  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.oh-my-zsh/themes/murilasso.zsh-theme"
    cache_file=$(mktemp)
    _murilasso_fetch_pr main "$cache_file"
    [[ -z "$(cat "$cache_file")" ]]
  '

  [ "$status" -eq 0 ]
}

@test "muestra PR abierto en ramas base" {
  export GH_PR_STATE='OPEN'

  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.oh-my-zsh/themes/murilasso.zsh-theme"
    cache_file=$(mktemp)
    _murilasso_fetch_pr develop "$cache_file"
    [[ "$(sed -n "1p" "$cache_file")" == "https://github.com/example/repo/pull/42" ]]
    [[ "$(sed -n "2p" "$cache_file")" == "OPEN" ]]
  '

  [ "$status" -eq 0 ]
}

@test "conserva PR cerrado visible en rama de feature" {
  export GH_PR_STATE='CLOSED'

  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.oh-my-zsh/themes/murilasso.zsh-theme"
    cache_file=$(mktemp)
    _murilasso_fetch_pr feature/example "$cache_file"
    [[ "$(sed -n "2p" "$cache_file")" == "CLOSED" ]]
  '

  [ "$status" -eq 0 ]
}

@test "descarta cache cerrado al leer rama base" {
  run zsh -c '
    source "${TEST_REPO_ROOT}/configs/zsh/.oh-my-zsh/themes/murilasso.zsh-theme"
    cache_file=$(mktemp)
    printf "%s\\n%s\\n" "https://github.com/example/repo/pull/42" "MERGED" > "$cache_file"
    _murilasso_read_pr_cache "$cache_file" main
    [[ -z "$_MURILASSO_PR_URL" && -z "$_MURILASSO_PR_STATE" ]]
  '

  [ "$status" -eq 0 ]
}
