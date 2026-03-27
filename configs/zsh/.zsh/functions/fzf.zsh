export FZF_HEADER_MULTI_SELECT_PROMPT='(Multi-select) Move with TAB/Shift+TAB, mark with SPACE, ENTER to confirm'
export FZF_HEADER_SINGLE_SELECT_PROMPT='(Single-select) Move with TAB/Shift+TAB and confirm with ENTER'
export FZF_PREFIX_PROMPT='🔍'
export FZF_DEFAULT_BIND='tab:down,btab:up,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all,ctrl-x:toggle'
export FZF_COLOR_MOLOKAI='bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672'

# color=tomasr/molokai
export FZF_DEFAULT_OPTS="--color=\"${FZF_COLOR_MOLOKAI}\" --ansi --cycle --border=rounded --prompt=\"${FZF_PREFIX_PROMPT} \" --pointer=${POINTER} --marker=${MARKER} --header=\"${FZF_HEADER_SINGLE_SELECT_PROMPT}\" --multi=0 --bind=\"${FZF_DEFAULT_BIND}\""

fzf_multi() {
  fzf --header="$FZF_HEADER_MULTI_SELECT_PROMPT" --multi "$@"
}

# Navega a un subdirectorio utilizando fzf para la selección interactiva.
fcd() {
  local dir="${1:-.}"

  cdf "$dir"
}

cdf() {
  local base_dir="${1:-.}"

  if ! command -v fzf >/dev/null 2>&1; then
    logError "fzf no está instalado en el PATH"
    return 1
  fi

  if ! command -v fd >/dev/null 2>&1; then
    logError "Esta función requiere 'fd'. Instálalo para continuar"
    return 1
  fi

  if [[ ! -d "$base_dir" ]]; then
    logError "Directorio inválido: $base_dir"
    return 1
  fi

  local resolved_base
  resolved_base=$(cd "$base_dir" 2>/dev/null && pwd) || {
    logError "No se pudo resolver el directorio base"
    return 1
  }

  local prompt header
  if [[ -n "${FZF_PREFIX_PROMPT:-}" ]]; then
    prompt="${FZF_PREFIX_PROMPT} cd "
  else
    prompt="cd "
  fi
  header="${FZF_HEADER_SINGLE_SELECT_PROMPT:-Selecciona un directorio y confirma con ENTER}"

  local selection
  selection=$(
    cd "$resolved_base" || return 1
    fd --type d --min-depth 1 --strip-cwd-prefix --color=never --exclude Cache --exclude Containers \
      | sort \
      | fzf --prompt "$prompt" --header "$header" \
            --preview 'ls -a --color=always -- {}' \
            --preview-window 'right,50%,border-rounded'
  ) || return 0

  [[ -z "$selection" ]] && return 0

  local target="$resolved_base/${selection}"

  cd "$target" || return 1
}
