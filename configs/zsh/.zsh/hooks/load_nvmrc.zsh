# Auto usar nvm al entrar a un directorio con .nvmrc (silencioso y perezoso)
autoload -U add-zsh-hook

load_nvmrc() {
  [[ -f .nvmrc ]] || return 0
  # Defer a los stubs de nvm: se cargará solo cuando se invoque
  local current required
  required=$(< .nvmrc)
  required=${required#v}
  # Si nvm aún no está cargado, la primera llamada lo inicializa
  current=$(nvm version 2>/dev/null)
  if [[ "$current" != "$(nvm version "$required" 2>/dev/null)" ]]; then
    echo "🚀 Cargando Node.js $(logGreen -i v$required)..."
    nvm use --silent >/dev/null 2>&1 || nvm install --silent >/dev/null 2>&1 || true
  fi
}

add-zsh-hook chpwd load_nvmrc  # Para Zsh
