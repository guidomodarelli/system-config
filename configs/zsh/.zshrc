# See https://smarttech101.com/zsh-highlighting-autosuggestion-themes-binding-alias-fzf/
ZSH_HOME="$HOME/.zsh"
ZSH_THEME="murilasso"
ZSH="$HOME/.oh-my-zsh"

# Load Python tooling early so python3 resolves through pyenv shims.
if [ -f "$ZSH_HOME/settings/python.zsh" ]; then
  source "$ZSH_HOME/settings/python.zsh"
fi

# ---- Early startup optimizations (must run before plugin manager) ----
# Cache and compdump paths used by Oh My Zsh's completion init
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-$HOST-$ZSH_VERSION"
export ZSH_DISABLE_COMPFIX=true

# Load completion styles and fpath BEFORE oh-my-zsh runs compinit
if [ -f "$ZSH_HOME/completions.zsh" ]; then
  source "$ZSH_HOME/completions.zsh"
fi

# ---- Oh My Zsh plugins (debe declararse antes de source oh-my-zsh.sh) ----
# Se reemplazó antigen por plugins=() nativos de omz + source directos en plugins.zsh.
# Ganancia: ~1295ms de startup eliminados.
#
# Trade-offs:
# - nvm y zoxide se excluyen aquí porque tienen lazy load / cache propios en settings/.
#   Si se agregan de vuelta, desactivar esos archivos para evitar doble inicialización.
# - Agregar un plugin omz nuevo requiere editar esta lista y reiniciar la terminal.
# - Los plugins de terceros van en plugins.zsh (sourced después de omz).
plugins=(
  git
  docker
  docker-compose
  node
  npm
  aliases
  fzf
  pip
  python
)

source $ZSH/oh-my-zsh.sh

# ---- Load the rest of user config ----
# Source all .zsh files from ~/.zsh except the early-loaded completions.zsh y python.zsh
if [ -d "$ZSH_HOME" ]; then
  while read file; do
    case "$(basename "$file")" in
      completions.zsh|python.zsh)
        continue
        ;;
    esac
    fullpath=$(cd "$ZSH_HOME" && realpath "$file")

    source "$fullpath"
  done < <(cd "$ZSH_HOME" && find . -type f -name "*.zsh" -print | sort)
fi
