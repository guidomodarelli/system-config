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

# Prepend local completions; let OMZ handle compinit once
typeset -a discovered_completion_dirs
discovered_completion_dirs=("${(@f)$(discover_completion_dirs)}")
typeset -U fpath
fpath=(/usr/local/share/zsh-completions $ZSH_COMPLETION $discovered_completion_dirs $fpath)

# If this file is sourced manually in an active shell, refresh completion cache.
if (( ${+_comps} )); then
  autoload -Uz compinit
  compinit -i -d "${ZSH_COMPDUMP:-${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}/zcompdump-$HOST-$ZSH_VERSION}" >/dev/null 2>&1
fi

# Styles must be defined before compinit (OMZ will run it)
zstyle :compinstall filename "${ZDOTDIR:-$HOME}/.zshrc"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"
zstyle ':completion:*' rehash true

# Do not call compinit here; Oh My Zsh/Antigen will initialize it once using
# $ZSH_COMPDUMP and $ZSH_CACHE_DIR configured in .zshrc.
