export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

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

# Lazy load: carga NVM completo la primera vez que se invoca el comando nvm
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
  nvm "$@"
}
