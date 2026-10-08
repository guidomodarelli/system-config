#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export RELEASE_TEST_REPO="${BATS_TEST_TMPDIR}/repo"
  export FURY_TEST_CALLS="${BATS_TEST_TMPDIR}/fury-calls"
  export FURY_TEST_JSON='[{"branch":"release/previous","version":"1.9.4"}]'
  export FURY_TEST_STATUS=0
  export GH_TEST_CALLS="${BATS_TEST_TMPDIR}/gh-calls"
  export GH_TEST_JSON='[]'
  export GH_TEST_STATUS=0
  export GH_TEST_PARTIAL_OUTPUT=''
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  # Fury requiere autenticación y una app real. Stub acotado al proceso externo;
  # Git y jq reales ejercen creación de rama y cálculo de versión.
  cat > "${BATS_TEST_TMPDIR}/bin/fury" <<'BASH'
#!/bin/bash
printf '%s\n' "$*" >> "$FURY_TEST_CALLS"
printf '%s\n' "$FURY_TEST_JSON"
exit "$FURY_TEST_STATUS"
BASH
  # GitHub requiere red y autenticación. Stub del CLI con filtro jq real
  # sobre páginas de respuesta; no consulta ni modifica PRs remotos.
  cat > "${BATS_TEST_TMPDIR}/bin/gh" <<'BASH'
#!/bin/bash
printf '%s\n' "$*" >> "$GH_TEST_CALLS"
if [ "$GH_TEST_STATUS" -ne 0 ]; then
  printf '%s\n' "$GH_TEST_PARTIAL_OUTPUT"
  exit "$GH_TEST_STATUS"
fi
[ "$1" = api ] || exit 2
[ "$2" = 'repos/{owner}/{repo}/pulls?state=open&per_page=100' ] || exit 2
[ "$3" = --paginate ] || exit 2
[ "$4" = --jq ] || exit 2
[ -z "$GH_REPO" ] || exit 2
jq -r "$5" <<< "$GH_TEST_JSON"
BASH
  chmod +x "${BATS_TEST_TMPDIR}/bin/fury" "${BATS_TEST_TMPDIR}/bin/gh"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  git init -q "$RELEASE_TEST_REPO"
  git -C "$RELEASE_TEST_REPO" config core.hooksPath /dev/null
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
  [ "$(cat "$FURY_TEST_CALLS")" = 'versions list --status FINISHED --output json' ]
}

@test "ignora rc y reinicia patch mediante alias" {
  export FURY_TEST_JSON='[{"branch":"release/previous","version":"2.3.7-rc.1"}]'
  run create_release eval frc
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/2.4.0' ]
}

@test "ignora otros valores rc y conserva major" {
  export FURY_TEST_JSON='[{"branch":"release/previous","version":"10.0.0-rc.12"}]'
  run create_release fury_release_create
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/10.1.0' ]
}

@test "ignora alpha y beta sin numero" {
  for prerelease in alpha beta; do
    export FURY_TEST_JSON="[{\"branch\":\"release/previous\",\"version\":\"3.5.8-$prerelease\"}]"
    run create_release fury_release_create
    [ "$status" -eq 0 ]
    [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/3.6.0' ]
    git -C "$RELEASE_TEST_REPO" switch -q "$RELEASE_TEST_BRANCH"
    git -C "$RELEASE_TEST_REPO" branch -D release/3.6.0
  done
}

@test "crea release 6.20.0 para version Fury 6.19.0-rc-1" {
  export FURY_TEST_JSON='[{"repositoryName":"fury_kraken-role-management-fe","version":"6.19.0-rc-1","branch":"enhancement/deps","status":"FINISHED","disabled":false,"tags":{"productive":true,"release_tag_name":"6.19.0-rc-1"},"evaluations":[],"ci":""}]'
  run create_release eval frc
  [ "$status" -eq 0 ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/6.20.0' ]
  [ "$(git -C "$RELEASE_TEST_REPO" rev-parse HEAD)" = "$RELEASE_TEST_HEAD" ]
}

@test "ignora prereleases numerados y nombres personalizados" {
  for prerelease in alpha.1 beta.2 preview-next.3; do
    export FURY_TEST_JSON="[{\"branch\":\"release/previous\",\"version\":\"4.9.7-$prerelease\"}]"
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
  for response in '' '[]' 'null' '[{"branch":"release/previous","version":null}]' '[{"branch":"release/previous","version":"incorrecta"}]' 'no-json' '[{"branch":"release/previous","version":"1.2.3-rc.1\nfeature/otra"}]'; do
    export FURY_TEST_JSON="$response"
    run create_release fury_release_create
    [ "$status" -ne 0 ]
    [[ "$output" == *'no se encontró una versión FINISHED válida'* ]]
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
  [ ! -e "$GH_TEST_CALLS" ]
}

@test "ayuda y argumentos inesperados no consultan Fury ni crean ramas" {
  run create_release fury_release_create --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Uso: fury_release_create'* ]]
  run create_release fury_release_create otra-rama
  [ "$status" -ne 0 ]
  [ ! -e "$FURY_TEST_CALLS" ]
  [ ! -e "$GH_TEST_CALLS" ]
  assert_original_branch
}

@test "bloquea release cuando existe PR abierto release o backport" {
  for branch in release/1.8.0 backport/1.7.2; do
    export GH_TEST_JSON="[{\"number\":42,\"head\":{\"ref\":\"$branch\"},\"html_url\":\"https://github.com/test/repo/pull/42\"}]"
    run create_release fury_release_create
    [ "$status" -ne 0 ]
    [[ "$output" == *'Primero deben mergearse'* ]]
    [[ "$output" == *"#42  $branch"* ]]
    [[ "$output" == *$'\n  https://github.com/test/repo/pull/42'* ]]
    [[ "$output" == *'Release bloqueada'* ]]
    [[ "$output" == *'volvé a ejecutar frc'* ]]
    [[ "$output" != *$'\033'* ]]
    [ ! -e "$FURY_TEST_CALLS" ]
    assert_original_branch
  done
}

@test "informa todos los PRs bloqueantes incluso en paginas posteriores" {
  export GH_TEST_JSON='[{"number":1,"head":{"ref":"feature/release/tool"},"html_url":"https://github.com/test/repo/pull/1"}]
[{"number":42,"head":{"ref":"release/1.8.0"},"html_url":"https://github.com/test/repo/pull/42"},{"number":43,"head":{"ref":"backport/1.7.2"},"html_url":"https://github.com/test/repo/pull/43"}]'
  run create_release fury_release_create
  [ "$status" -ne 0 ]
  [[ "$output" == *'#42  release/1.8.0'* ]]
  [[ "$output" == *'#43  backport/1.7.2'* ]]
  [[ "$output" != *'#1 feature/'* ]]
  [ ! -e "$FURY_TEST_CALLS" ]
  assert_original_branch
}

@test "permite PRs abiertos de otras ramas y usa repositorio actual" {
  export GH_REPO=otro/repositorio
  export GH_TEST_JSON='[{"number":1,"head":{"ref":"feature/release/tool"},"html_url":"https://github.com/test/repo/pull/1"},{"number":2,"head":{"ref":"backport-tools"},"html_url":"https://github.com/test/repo/pull/2"}]'
  run create_release fury_release_create
  [ "$status" -eq 0 ]
  [ -s "$GH_TEST_CALLS" ]
  [ "$(git -C "$RELEASE_TEST_REPO" branch --show-current)" = 'release/1.10.0' ]
}

@test "aborta si GitHub falla incluso tras respuesta parcial" {
  export GH_TEST_STATUS=7
  export GH_TEST_PARTIAL_OUTPUT='#42 release/1.8.0 https://github.com/test/repo/pull/42'
  run create_release fury_release_create
  [ "$status" -ne 0 ]
  [[ "$output" == *'falló la consulta de PRs abiertos de GitHub'* ]]
  [ ! -e "$FURY_TEST_CALLS" ]
  assert_original_branch
}

@test "muestra colores y enlace clicable en terminal" {
  export TERM=xterm-256color
  unset NO_COLOR
  export GH_TEST_JSON='[{"number":42,"head":{"ref":"release/1.8.0"},"html_url":"https://github.com/test/repo/pull/42"}]'
  run script -q /dev/null zsh -f -c '
    source "$TEST_REPO_ROOT/configs/zsh/.zsh/settings/meli/fury.zsh"
    cd "$RELEASE_TEST_REPO"
    fury_release_create
  '
  [[ "$output" == *$'\033[1;33m  #42'* ]]
  [[ "$output" == *$'\033]8;;https://github.com/test/repo/pull/42\033\\'* ]]
  [[ "$output" == *'Release bloqueada'* ]]
  [ ! -e "$FURY_TEST_CALLS" ]
  assert_original_branch
}

@test "respeta NO_COLOR en terminal y conserva URL visible" {
  export TERM=xterm-256color
  export NO_COLOR=1
  export GH_TEST_JSON='[{"number":42,"head":{"ref":"release/1.8.0"},"html_url":"https://github.com/test/repo/pull/42"}]'
  run script -q /dev/null zsh -f -c '
    source "$TEST_REPO_ROOT/configs/zsh/.zsh/settings/meli/fury.zsh"
    cd "$RELEASE_TEST_REPO"
    fury_release_create
  '
  [[ "$output" != *$'\033'* ]]
  [[ "$output" == *'https://github.com/test/repo/pull/42'* ]]
  assert_original_branch
}
