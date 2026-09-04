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
if [[ -d "$ZSH_HOME" ]]; then
  # Glob nativo de zsh (ordenado, sin fork de find/sort) + basename via ${cfg:t}
  # y source directo (sin subshell cd+realpath por archivo). source sigue symlinks
  # igual, así que realpath no aportaba nada. Anon function para no leakear $cfg.
  () {
    local cfg
    for cfg in "$ZSH_HOME"/**/*.zsh(N); do
      case "${cfg:t}" in
        completions.zsh|python.zsh) continue ;;
      esac
      source "$cfg"
    done
  }
fi

############### MELI ###############

# Internal Python Registry
export PIP_INDEX_URL='https://pypi.artifacts.furycloud.io/simple'
export UV_INDEX_URL='https://pypi.artifacts.furycloud.io/simple'

# >>> es-wrapper initialize >>>
# Agregado automáticamente por el instalador de es-wrapper
# Para desinstalar, ejecuta: ~/.es-wrapper/uninstall.sh
export PATH="$HOME/.es-wrapper/bin:$PATH"

unalias source 2>/dev/null
unalias . 2>/dev/null
source() {
    builtin source "$@"
    local ret=$?
    if [[ -n "$VIRTUAL_ENV" ]]; then
        export PATH="$HOME/.es-wrapper/bin:$PATH"
    fi
    return $ret
}
alias .='source'

_es_wrapper_guard() {
    case ":$PATH:" in
        *":$HOME/.es-wrapper/bin:"*)
            if [[ "$PATH" != "$HOME/.es-wrapper/bin:"* ]]; then
                local _eswrap_p="${PATH//$HOME\/.es-wrapper\/bin:/}"
                _eswrap_p="${_eswrap_p//:$HOME\/.es-wrapper\/bin/}"
                export PATH="$HOME/.es-wrapper/bin:$_eswrap_p"
            fi
            ;;
        *)
            export PATH="$HOME/.es-wrapper/bin:$PATH"
            ;;
    esac
}
precmd_functions+=(_es_wrapper_guard)

_es_wrapper_vm_hook() {
    [[ -f .nvmrc || -f .node-version ]] && type nvm &>/dev/null && nvm use --silent 2>/dev/null
    [[ -f .python-version ]] && command -v pyenv &>/dev/null && pyenv local 2>/dev/null
}
if [[ -n "$ZSH_VERSION" ]]; then
    autoload -U add-zsh-hook 2>/dev/null
    add-zsh-hook chpwd _es_wrapper_vm_hook
    _es_wrapper_vm_hook
fi
# <<< es-wrapper initialize <<<

fury() {
  PYTHONWARNINGS='ignore:unknown terminal capability:UserWarning:inquirer.themes' command fury "$@"
}

# bun completions
[ -s "/Users/gmodarelli/.bun/_bun" ] && source "/Users/gmodarelli/.bun/_bun"

# Added by Fury CLI installation process
export PATH="$HOME/.fury/fury_venv/bin:$PATH"

# Added by git-ai installer on Mon Aug 10 10:01:57 -03 2026
export PATH="/Users/gmodarelli/.git-ai/bin:$PATH"

# Added by Swarm CLI installer
export PATH="/Users/gmodarelli/.swarm/bin:$PATH"

export GROOT_QUEUE_AUTORUN=true

