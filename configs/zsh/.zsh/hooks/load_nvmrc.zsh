# Auto usar nvm al entrar a un directorio con .nvmrc (silencioso y perezoso)
autoload -U add-zsh-hook

typeset -g _LOAD_NVMRC_LAST_DIR=""
typeset -g _LOAD_NVMRC_LAST_VERSION=""

# Versión de node activa sin lanzar `node -v` en cada cd: con NVM activo sale del
# path del binario; si no, reusa la resolución cacheada del tema murilasso.
_load_nvmrc_running_version() {
  local node_bin="${NVM_BIN:+${NVM_BIN}/node}"
  [[ -z "$node_bin" ]] && node_bin="${commands[node]}"
  REPLY=""
  [[ -n "$node_bin" ]] || return 0

  if (( $+functions[_murilasso_resolve_node_version] )); then
    _murilasso_resolve_node_version "$node_bin"
  else
    REPLY=$("$node_bin" -v 2>/dev/null)
  fi
}

load_nvmrc() {
  [[ -f .nvmrc ]] || return 0

  local required
  required=$(< .nvmrc)
  required=${required#v}

  # Evita doble ejecución cuando chpwd y git_branch_changed la invocan en el mismo cd
  # Se re-ejecuta si cambia la versión requerida (ej. branch con .nvmrc distinto)
  [[ "$PWD" == "$_LOAD_NVMRC_LAST_DIR" && "$required" == "$_LOAD_NVMRC_LAST_VERSION" ]] && return 0
  _LOAD_NVMRC_LAST_DIR="$PWD"
  _LOAD_NVMRC_LAST_VERSION="$required"

  local running
  _load_nvmrc_running_version
  running="${REPLY#v}"

  # Si la versión activa ya satisface lo que pide .nvmrc, no hacer nada
  [[ "$running" == "$required"* ]] && return 0

  local from_part=""
  [[ -n "$running" ]] && from_part="$(logGray -i v${running}) → "
  echo "⬡ Node.js: ${from_part}$(logGreen -i v${required})"
  nvm use --silent 2>/dev/null || nvm install --silent 2>/dev/null || true
}

add-zsh-hook chpwd load_nvmrc
