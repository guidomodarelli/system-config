# Auto usar nvm al entrar a un directorio con .nvmrc
autoload -U add-zsh-hook

load_nvmrc() {
  if [[ -f .nvmrc ]]; then
    echo "🔍 Archivo $(logYellow .nvmrc) encontrado"
    local node_version=$(nvm version) # Obtiene la versión actual de Node
    local nvmrc_version=$(cat .nvmrc)

    echo "📋 Versión requerida: $(logGreen -i $nvmrc_version)"
    echo "🔄 Verificando versión de Node.js..."
    # Si la versión de Node actual no coincide con .nvmrc
    if [[ "$node_version" != "$(nvm version "$nvmrc_version")" ]]; then
      echo "🚀 Cargando Node.js $(logGreen -i v$nvmrc_version)..."
      nvm use || nvm install
    fi
  fi
}

add-zsh-hook chpwd load_nvmrc  # Para Zsh
