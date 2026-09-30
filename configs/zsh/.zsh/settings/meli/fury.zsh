export FURY_BIN_LOCATION="/Users/gmodarelli/.fury/fury_venv/bin"
export PATH="$PATH:$FURY_BIN_LOCATION"

# Crea y selecciona una release desde HEAD con el siguiente minor de Fury.
# Ignora sufijos prerelease como -alpha, -beta.2 o -rc.1.
# Ejemplo: 1.9.4-rc.1 -> release/1.10.0.
alias frc='fury_release_create'
fury_release_create() {
  emulate -L zsh

  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print 'Uso: fury_release_create'
    print 'Crea release/<major>.<minor+1>.0 desde HEAD usando la última versión FINISHED de Fury.'
    return 0
  fi
  if (( $# != 0 )); then
    print -u2 'fury_release_create: no acepta argumentos. Usa --help para ver el uso.'
    return 1
  fi

  local dependency
  for dependency in git fury jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      print -u2 "fury_release_create: falta el comando $dependency."
      return 1
    fi
  done
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    print -u2 'fury_release_create: ejecuta esta función dentro de un repositorio Git.'
    return 1
  fi

  local versions_json next_version
  if ! versions_json=$(fury versions list --status FINISHED --output json --limit 1); then
    print -u2 'fury_release_create: falló la consulta de la última versión FINISHED de Fury.'
    return 1
  fi
  if ! next_version=$(jq -er '
    .[0].version
    | capture("^(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.[0-9]+(?:-[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$")
    | "\(.major).\((.minor | tonumber) + 1).0"
  ' <<< "$versions_json" 2>/dev/null); then
    print -u2 'fury_release_create: no se pudo calcular el siguiente minor; se esperaba una versión major.minor.patch con sufijo prerelease opcional.'
    return 1
  fi

  git switch --quiet -c "release/$next_version" || return $?
  print "Branch creada y seleccionada: release/$next_version"
}
