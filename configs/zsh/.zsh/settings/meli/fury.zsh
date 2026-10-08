export FURY_BIN_LOCATION="$HOME/.fury/fury_venv/bin"
export PATH="$PATH:$FURY_BIN_LOCATION"

# Crea y selecciona una release desde HEAD con el siguiente minor de Fury.
# Usa la última versión FINISHED cuya rama sea release/* o tenga tags.productive=true.
# Requiere que no haya PRs abiertos desde ramas release/* ni backport/*.
# Ignora sufijos prerelease como -alpha, -beta.2 o -rc.1.
# Ejemplo: 1.9.4-rc.1 -> release/1.10.0.
alias frc='fury_release_create'
fury_release_create() {
  emulate -L zsh

  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print 'Uso: fury_release_create'
    print 'Crea release/<major>.<minor+1>.0 desde HEAD usando la última versión FINISHED de Fury de una rama release/* o con tags.productive=true.'
    print 'Antes de crear la rama, deben mergearse los PRs abiertos desde release/* o backport/*.'
    return 0
  fi
  if (( $# != 0 )); then
    print -u2 'fury_release_create: no acepta argumentos. Usa --help para ver el uso.'
    return 1
  fi

  local dependency
  for dependency in git fury jq gh; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      print -u2 "fury_release_create: falta el comando $dependency."
      return 1
    fi
  done
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    print -u2 'fury_release_create: ejecuta esta función dentro de un repositorio Git.'
    return 1
  fi

  local blocking_pull_requests
  if ! blocking_pull_requests=$(GH_REPO= gh api 'repos/{owner}/{repo}/pulls?state=open&per_page=100' --paginate --jq '
    .[]
    | select(.head.ref | startswith("release/") or startswith("backport/"))
    | "\(.number)\t\(.head.ref)\t\(.html_url)"
  '); then
    print -u2 'fury_release_create: falló la consulta de PRs abiertos de GitHub; no se creará la release.'
    return 1
  fi
  if [[ -n "$blocking_pull_requests" ]]; then
    local use_color=false
    [[ -t 2 && -z "${NO_COLOR:-}" && "$TERM" != dumb ]] && use_color=true
    print -u2
    if $use_color; then
      print -Pu2 '%B%F{red}Release bloqueada%f%b'
    else
      print -u2 'Release bloqueada'
    fi
    print -u2 'Primero deben mergearse estos PRs abiertos:'

    local pull_request_number pull_request_branch pull_request_url
    while IFS=$'\t' read -r pull_request_number pull_request_branch pull_request_url; do
      print -u2
      if $use_color; then
        printf '\033[1;33m  #%s\033[0m  %s\n' "$pull_request_number" "$pull_request_branch" >&2
        # OSC 8 conserva el enlace clicable aunque la terminal corte la URL.
        printf '  \033[36m\033]8;;%s\033\\%s\033]8;;\033\\\033[0m\n' "$pull_request_url" "$pull_request_url" >&2
      else
        printf '  #%s  %s\n  %s\n' "$pull_request_number" "$pull_request_branch" "$pull_request_url" >&2
      fi
    done <<< "$blocking_pull_requests"
    print -u2
    print -u2 'Mergeá los PRs pendientes y volvé a ejecutar frc.'
    print -u2
    return 1
  fi

  local versions_json next_version
  if ! versions_json=$(fury versions list --status FINISHED --output json); then
    print -u2 'fury_release_create: falló la consulta de la última versión FINISHED de Fury.'
    return 1
  fi
  if ! next_version=$(jq -er '
    map(select(
      (.branch | startswith("release/"))
      or (.tags.productive == true or .tags.productive == "true")
    ))
    | .[0].version
    | capture("^(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.[0-9]+(?:-[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$")
    | "\(.major).\((.minor | tonumber) + 1).0"
  ' <<< "$versions_json" 2>/dev/null); then
    print -u2 'fury_release_create: no se encontró una versión FINISHED válida de una rama release/* o con tags.productive=true.'
    return 1
  fi

  git switch --quiet -c "release/$next_version" || return $?
  print "Branch creada y seleccionada: release/$next_version"
}
