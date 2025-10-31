# Generic selector utilities (shared by git/docker/wazuh selectors)
# Dependencias asumidas: logCyan, logGray, styleText, fzf, column
# API:
# selector_list <descriptions_fn>
#   Llama a la función <descriptions_fn> que debe emitir lineas 'func|descripcion'
#   Produce tabla coloreada.
# selector_fzf <descriptions_fn> <prompt> <header>
#   Devuelve el nombre limpio de la función seleccionada (stdout) o vacío si cancelado.

selector_list() {
  local desc_fn="$1"
  if ! typeset -f "$desc_fn" >/dev/null; then
    echo "# descriptor function not found: $desc_fn" >&2
    return 1
  fi
  "$desc_fn" | while IFS='|' read -r func desc; do
    echo "$(logCyan $func)" "| $(logGray "# $desc")"
  done | column -t -s '|'
}

selector_fzf() {
  local desc_fn="$1" prompt="$2" header="$3"
  local default_header='Selecciona función (Enter ejecuta, ESC cancela)'
  [[ -z "$header" ]] && header="$default_header"
  # Si el prompt ya trae el prefijo no lo duplicamos
  local prefix="${FZF_PREFIX_PROMPT:-}"
  if [[ "$prompt" != ${prefix}* ]]; then
    prompt="${prefix} ${prompt}"
  fi
  local list
  list=$(selector_list "$desc_fn") || return 0
  local selected
  selected=$(echo "$list" | fzf --ansi --prompt "${prompt} " --header "$header" --query="'")
  [[ -z "$selected" ]] && return 0
  echo "$selected" | awk '{print $1}' | sed -E 's!\x1B\[[0-9;]*[A-Za-z]!!g'
}
