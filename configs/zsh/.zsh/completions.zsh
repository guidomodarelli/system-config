ZSH_COMPLETION="$HOME/.zsh/completions"
: "${ZSH_COMPLETION_SEARCH_ROOTS:=${ZDOTDIR:-$HOME}/.zsh}"

discover_completion_dirs() {
  local -a roots
  local -aU completion_dirs
  local root file

  roots=("${(@s/:/)ZSH_COMPLETION_SEARCH_ROOTS}")

  for root in "${roots[@]}"; do
    [ -d "$root" ] || continue

    while IFS= read -r file; do
      if grep -qEm1 '^[[:space:]]*(#compdef|compdef[[:space:]])' "$file"; then
        completion_dirs+=("${file:h}")
      fi
    done < <(
      find -L "$root" -type f -name '_*' 2>/dev/null
    )
  done

  printf '%s\n' "${completion_dirs[@]}"
}

# Generate simple completions for local scripts only if needed
generate_completions() {
  local script_name="$1"
  local script_file="$2"
  local safe_script_name="${script_name//[^a-zA-Z0-9]/_}"
  local completions_dir="$ZSH_COMPLETION"
  local completions_file="$completions_dir/_${script_name}"

  mkdir -p "$completions_dir"

  # Regenerate only if the script is newer than the completion or missing
  if [ ! -f "$completions_file" ] || [ "$script_file" -nt "$completions_file" ]; then
    {
      echo "#compdef ${script_name}"
      echo
      echo "_${safe_script_name}_completions() {"
      echo "  local -a commands";
      echo "  commands=("
      grep -oP '^\\w+(?=\\(\\))' "$script_file" | while read -r cmd; do
        printf '    "%s:%s"\n' "$cmd" "$cmd"
      done
      echo "  )"
      echo "  _describe 'command' commands"
      echo "}"
      echo
      echo "compdef _${safe_script_name}_completions ${script_name}"
    } >"$completions_file"
  fi
}

# Defer generation to background to avoid blocking startup
(
  generate_completions "setup.sh" "$HOME/system-config/scripts/setup/setup.sh" 2>/dev/null
  generate_completions "setup.py" "$HOME/system-config/scripts/setup/setup.sh" 2>/dev/null
) &!

# discover_completion_dirs hace find+grep en cada startup (~390ms).
# Se cachea el resultado y se regenera automáticamente si:
#   - el cache no existe (primera vez)
#   - se agrega un archivo _* nuevo (mtime del archivo > mtime del cache)
#   - se modifica un archivo _* existente (idem, modificar cambia el mtime)
# find -newer sale al primer match → ~1ms cuando no hay cambios.
# Para forzar regeneración manual: rm "$_COMPLETIONS_DIRS_CACHE"
_COMPLETIONS_DIRS_CACHE="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}/.custom_completion_dirs"

_completion_dirs_cache_stale() {
  [[ ! -f "$_COMPLETIONS_DIRS_CACHE" ]] && return 0
  local root
  for root in "${(@s/:/)ZSH_COMPLETION_SEARCH_ROOTS}"; do
    [[ -n "$(find -L "$root" -name '_*' -newer "$_COMPLETIONS_DIRS_CACHE" -print -quit 2>/dev/null)" ]] && return 0
  done
  return 1
}

if _completion_dirs_cache_stale; then
  discover_completion_dirs > "$_COMPLETIONS_DIRS_CACHE"
fi

# Prepend local completions; let OMZ handle compinit once
typeset -a discovered_completion_dirs
discovered_completion_dirs=("${(@f)$(< "$_COMPLETIONS_DIRS_CACHE")}")
typeset -U fpath
fpath=(/usr/local/share/zsh-completions "$HOME/system-config/third-party/zsh-completions/src" $ZSH_COMPLETION $discovered_completion_dirs $fpath)

# compinit lo corre omz/antigen una sola vez. No repetir aquí — causaba double-compinit
# (~400ms extra) porque _comps ya estaba seteado cuando este archivo se sourceable.
# Para recargar completions manualmente en una sesión activa usar: zsh_reload_completions
zsh_reload_completions() {
  rm -f "$_COMPLETIONS_DIRS_CACHE"
  autoload -Uz compinit
  compinit -i -d "${ZSH_COMPDUMP:-${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}/zcompdump-$HOST-$ZSH_VERSION}" >/dev/null 2>&1
  echo "Completions reloaded."
}

# Styles must be defined before compinit (OMZ will run it)
zstyle :compinstall filename "${ZDOTDIR:-$HOME}/.zshrc"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"
zstyle ':completion:*' rehash true

# Do not call compinit here; Oh My Zsh/Antigen will initialize it once using
# $ZSH_COMPDUMP and $ZSH_CACHE_DIR configured in .zshrc.
