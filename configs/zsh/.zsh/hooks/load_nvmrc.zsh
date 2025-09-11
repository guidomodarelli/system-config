# Auto usar nvm al entrar a un directorio con .nvmrc
autoload -U add-zsh-hook

# Cache global para evitar trabajo repetido
typeset -g __NVM_LAST_NVMRC_PATH __NVM_LAST_WANTED __NVM_LAST_RESOLVED

# 2) Función para encontrar el .nvmrc más cercano hacia arriba
find_nvmrc() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/.nvmrc" ]; then
      echo "$d/.nvmrc"
      return
    fi
    d="$(dirname "$d")"
  done
}

load_nvmrc() {
  # Silencioso si nvm no existe
  command -v nvm >/dev/null 2>&1 || return 0

  local nvmrc_path wanted resolved current_node
  nvmrc_path="$(find_nvmrc || true)"

  if [ -n "${nvmrc_path:-}" ]; then
    wanted="$(tr -d ' \t\r\n' < "$nvmrc_path")"
    [ -z "$wanted" ] && return 0
  else
    wanted="default"
  fi

  # Si la intención no cambió y ya tenemos la versión activa, salir rápido
  current_node="$(node -v 2>/dev/null)"  # ej: v18.17.0
  if [ "$wanted" = "${__NVM_LAST_WANTED:-}" ] && [ -n "${__NVM_LAST_RESOLVED:-}" ] && [ "$current_node" = "${__NVM_LAST_RESOLVED:-}" ]; then
    return 0
  fi

  # Resolver sólo si cambió el wanted o no tenemos resolved
  if [ "$wanted" != "${__NVM_LAST_WANTED:-}" ] || [ -z "${__NVM_LAST_RESOLVED:-}" ]; then
    resolved="$(nvm version "$wanted" 2>/dev/null || true)"
  else
    resolved="${__NVM_LAST_RESOLVED}"
  fi

  # Si la versión ya está activa tras resolver
  if [ -n "$resolved" ] && [ "$resolved" != "N/A" ] && [ "$current_node" = "$resolved" ]; then
    __NVM_LAST_WANTED="$wanted"
    __NVM_LAST_RESOLVED="$resolved"
    __NVM_LAST_NVMRC_PATH="$nvmrc_path"
    return 0
  fi

  # Intentar usar directamente (evita una resolución adicional)
  if nvm use "$wanted" >/dev/null 2>&1; then
    __NVM_LAST_WANTED="$wanted"
    __NVM_LAST_RESOLVED="$(node -v 2>/dev/null)"
    __NVM_LAST_NVMRC_PATH="$nvmrc_path"
    return 0
  fi

  # Instalar si no existe
  if nvm install "$wanted" >/dev/null 2>&1; then
    nvm use "$wanted" >/dev/null 2>&1 || return 1
    __NVM_LAST_WANTED="$wanted"
    __NVM_LAST_RESOLVED="$(node -v 2>/dev/null)"
    __NVM_LAST_NVMRC_PATH="$nvmrc_path"
    return 0
  fi

  # Falló instalación/uso
  return 1
}

add-zsh-hook chpwd load_nvmrc  # Para Zsh
