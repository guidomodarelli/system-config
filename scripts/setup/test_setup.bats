#!/usr/bin/env bats

setup() {
  SETUP_SCRIPT="$BATS_TEST_DIRNAME/setup.sh"
}

@test "install_codex_external_repos installs prerequisites before executing installer" {
  run bash -lc '
    set -euo pipefail
    source "$1"

    call_order=()

    install_git() { call_order+=("install_git"); }
    install_homebrew() { call_order+=("install_homebrew"); }
    install_yq() { call_order+=("install_yq"); }
    run_codex_external_repos_install() { call_order+=("run_codex_external_repos_install"); }

    install_codex_external_repos

    printf "%s\n" "${call_order[@]}"
  ' _ "$SETUP_SCRIPT"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "install_git" ]
  [ "${lines[1]}" = "install_homebrew" ]
  [ "${lines[2]}" = "install_yq" ]
  [ "${lines[3]}" = "run_codex_external_repos_install" ]
  [ "${#lines[@]}" -eq 4 ]
}
