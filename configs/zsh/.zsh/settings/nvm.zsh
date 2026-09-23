export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

# Resuelve un pedido de versión (24, v24.17.0, lts/iron, default...) a un directorio
# instalado en $NVM_DIR/versions/node sin cargar NVM. Deja el resultado en REPLY.
# Sigue la cadena de aliases (ej. lts/* → lts/iron → v20.18.3) y, ante varias
# versiones que matchean el prefijo, elige la más alta.
_nvm_resolve_installed_dir() {
  REPLY=""
  local requested="${1//[[:space:]]/}"
  [[ -n "$requested" ]] || return 1

  local alias_hops=0
  while [[ -f "$NVM_DIR/alias/$requested" ]] && (( alias_hops < 10 )); do
    requested=$(< "$NVM_DIR/alias/$requested")
    requested="${requested//[[:space:]]/}"
    alias_hops=$((alias_hops + 1))
  done
  requested="${requested#v}"
  [[ "$requested" == [0-9]* ]] || return 1

  local versions_dir="$NVM_DIR/versions/node"
  if [[ -d "$versions_dir/v$requested" ]]; then
    REPLY="$versions_dir/v$requested"
    return 0
  fi

  # Prefijo por componentes completos: "24" matchea v24.x.y pero no v240.
  local -a matching_dirs=("$versions_dir"/v${requested}.*(N/n))
  (( ${#matching_dirs} )) || return 1
  REPLY="${matching_dirs[-1]}"
}

# Activa una versión instalada reemplazando la entrada de NVM en PATH.
_nvm_activate_dir() {
  local node_dir="$1"
  path=("${node_dir}/bin" ${path:#$NVM_DIR/versions/node/*/bin})
  export NVM_BIN="${node_dir}/bin"
  export NVM_INC="${node_dir}/include/node"
  rehash
}

# Busca .nvmrc subiendo desde PWD, igual que `nvm use` sin argumentos.
_nvm_find_nvmrc_version() {
  REPLY=""
  local directory="$PWD"
  while true; do
    if [[ -f "$directory/.nvmrc" ]]; then
      REPLY=$(< "$directory/.nvmrc")
      return 0
    fi
    [[ -z "$directory" || "$directory" == "/" ]] && return 1
    directory="${directory%/*}"
  done
}

# Vía rápida para `nvm use [--silent] [versión]`: si la versión está instalada, cambia
# PATH en ~1ms en lugar de cargar nvm.sh (~1-3s). Devuelve 1 para delegar en NVM
# ante cualquier caso que no sepa resolver (versión no instalada, flags extra, etc.).
_nvm_fast_use() {
  local silent="false" requested=""
  local argument
  for argument in "$@"; do
    case "$argument" in
      --silent) silent="true" ;;
      -*) return 1 ;;
      *) [[ -n "$requested" ]] && return 1; requested="$argument" ;;
    esac
  done

  if [[ -z "$requested" ]]; then
    _nvm_find_nvmrc_version || return 1
    requested="$REPLY"
  fi

  _nvm_resolve_installed_dir "$requested" || return 1
  local node_dir="$REPLY"
  _nvm_activate_dir "$node_dir"
  [[ "$silent" == "true" ]] || print -r -- "Now using node ${node_dir:t}"
  return 0
}

# Fast PATH: agrega el binario de la versión default sin cargar NVM (~1ms vs ~1500ms)
() {
  local default_file="$NVM_DIR/alias/default"
  [[ -s "$default_file" ]] || return

  local version
  version=$(< "$default_file")

  # Sigue la cadena de aliases (ej. lts/* → lts/iron → v20.18.3)
  while [[ -f "$NVM_DIR/alias/${version}" ]]; do
    version=$(< "$NVM_DIR/alias/${version}")
  done
  version="${version#v}"

  local node_dir="$NVM_DIR/versions/node/v${version}"
  [[ -d "$node_dir" ]] || return

  export PATH="${node_dir}/bin:${PATH}"
  export NVM_BIN="${node_dir}/bin"
  export NVM_INC="${node_dir}/include/node"
}

# Lazy load: carga NVM completo la primera vez que se invoca el comando nvm,
# salvo `nvm use` con una versión ya instalada, que resuelve _nvm_fast_use.
nvm() {
  if [[ "$1" == "use" ]] && _nvm_fast_use "${@:2}"; then
    return 0
  fi
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
  nvm "$@"
}
