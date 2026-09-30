#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export RELEASE_TEST_REPO="${BATS_TEST_TMPDIR}/repo"
  export FURY_TEST_CALLS="${BATS_TEST_TMPDIR}/fury-calls"
  export FURY_TEST_JSON='[{"version":"1.9.4"}]'
  export FURY_TEST_STATUS=0
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  # Fury requiere autenticación y una app real. Stub acotado al proceso externo;
  # Git y jq reales ejercen creación de rama y cálculo de versión.
  cat > "${BATS_TEST_TMPDIR}/bin/fury" <<'BASH'
#!/bin/bash
printf '%s\n' "$*" >> "$FURY_TEST_CALLS"
printf '%s\n' "$FURY_TEST_JSON"
exit "$FURY_TEST_STATUS"
BASH
  chmod +x "${BATS_TEST_TMPDIR}/bin/fury"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  git init -q "$RELEASE_TEST_REPO"
  git -C "$RELEASE_TEST_REPO" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -qm 'Inicio' --allow-empty
  export RELEASE_TEST_HEAD
  RELEASE_TEST_HEAD=$(git -C "$RELEASE_TEST_REPO" rev-parse HEAD)
  export RELEASE_TEST_BRANCH
  RELEASE_TEST_BRANCH=$(git -C "$RELEASE_TEST_REPO" branch --show-current)
}

create_release() {
  zsh -f -c '
    source "$TEST_REPO_ROOT/configs/zsh/.zsh/settings/meli/fury.zsh"
    cd "$RELEASE_TEST_REPO"
    "$@"
  ' release-test "$@"
}

assert_original_branch() {
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = "$RELEASE_TEST_BRANCH" ]
  [ "$(git -C "$RELEASE_TEST_REPO" for-each-ref --format='%(refname:short)' refs/heads)" = "$RELEASE_TEST_BRANCH" ]
}

@test "crea siguiente minor y selecciona release desde HEAD actual" {
  run create_release fury_release_create
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/1.10.0' ]
  [ "$(git -C "$RELEASE_TEST_REPO" rev-parse HEAD)" = "$RELEASE_TEST_HEAD" ]
  [ "$(cat "$FURY_TEST_CALLS")" = 'versions list --status FINISHED --output json --limit 1' ]
}

@test "ignora rc y reinicia patch mediante alias" {
  export FURY_TEST_JSON='[{"version":"2.3.7-rc.1"}]'
  run create_release eval frc
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/2.4.0' ]
}

@test "ignora otros valores rc y conserva major" {
  export FURY_TEST_JSON='[{"version":"10.0.0-rc.12"}]'
  run create_release fury_release_create
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/10.1.0' ]
}

@test "ignora alpha y beta sin numero" {
  for prerelease in alpha beta; do
    export FURY_TEST_JSON="[{\"version\":\"3.5.8-$prerelease\"}]"
    run create_release fury_release_create
    [ "$status" -eq 0 ]
    [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/3.6.0' ]
    git -C "$RELEASE_TEST_REPO" switch -q "$RELEASE_TEST_BRANCH"
    git -C "$RELEASE_TEST_REPO" branch -D release/3.6.0
  done
}

@test "crea release 6.20.0 para version Fury 6.19.0-rc-1" {
  export FURY_TEST_JSON='[{"repositoryName":"fury_kraken-role-management-fe","version":"6.19.0-rc-1","branch":"enhancement/deps","status":"FINISHED","disabled":false,"tags":{"release_tag_name":"6.19.0-rc-1"},"evaluations":[],"ci":""}]'
  run create_release eval frc
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/6.20.0' ]
  [ "$(git -C "$RELEASE_TEST_REPO" rev-parse HEAD)" = "$RELEASE_TEST_HEAD" ]
}

@test "ignora prereleases numerados y nombres personalizados" {
  for prerelease in alpha.1 beta.2 preview-next.3; do
    export FURY_TEST_JSON="[{\"version\":\"4.9.7-$prerelease\"}]"
    run create_release eval frc
    [ "$status" -eq 0 ]
    [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/4.10.0' ]
    git -C "$RELEASE_TEST_REPO" switch -q "$RELEASE_TEST_BRANCH"
    git -C "$RELEASE_TEST_REPO" branch -D release/4.10.0
  done
}

@test "no crea rama cuando Fury falla aunque devuelva JSON" {
  export FURY_TEST_STATUS=7
  run create_release fury_release_create
  [ "$status" -ne 0 ]
  [[ "$output" == *'falló la consulta'* ]]
  assert_original_branch
}

@test "no crea rama si faltan datos o falla lectura de version" {
  for response in '' '[]' 'null' '[{"version":null}]' '[{"version":"incorrecta"}]' 'no-json' '[{"version":"1.2.3-rc.1\nfeature/otra"}]'; do
    export FURY_TEST_JSON="$response"
    run create_release fury_release_create
    [ "$status" -ne 0 ]
    [[ "$output" == *'no se pudo calcular'* ]]
    assert_original_branch
  done
}

@test "no sobrescribe rama release existente" {
  git -C "$RELEASE_TEST_REPO" branch release/1.10.0
  run create_release fury_release_create
  [ "$status" -ne 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = "$RELEASE_TEST_BRANCH" ]
  [ "$(git -C "$RELEASE_TEST_REPO" rev-parse release/1.10.0)" = "$RELEASE_TEST_HEAD" ]
}

@test "fuera de repositorio falla antes de consultar Fury" {
  export RELEASE_TEST_REPO="$BATS_TEST_TMPDIR"
  run create_release fury_release_create
  [ "$status" -ne 0 ]
  [[ "$output" == *'dentro de un repositorio Git'* ]]
  [ ! -e "$FURY_TEST_CALLS" ]
}

@test "ayuda y argumentos inesperados no consultan Fury ni crean ramas" {
  run create_release fury_release_create --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Uso: fury_release_create'* ]]
  run create_release fury_release_create otra-rama
  [ "$status" -ne 0 ]
  [ ! -e "$FURY_TEST_CALLS" ]
  assert_original_branch
}
