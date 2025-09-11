wzstart() {
  logInfo "Executing Docker containers..."
  docker_table_formatter | grep -v "runner" | grep -E "(osd-dev|dashboard)" | fzf --prompt="$FZF_PREFIX_PROMPT docker exec " --query "'" | awk '{print $2}' | while IFS= read -r sel; do
    echo "clear; docker exec -it $sel yarn start --no-base-path"
  done | anyframe-action-put
}

# --- Master selector (@W) ---
__wazuh_get_descriptions() {
  echo "wzstart|iniciar yarn start en contenedor wazuh/osd seleccionado"
}

__wazuh_list_functions() {
  __wazuh_get_descriptions | while IFS='|' read -r func desc; do
    echo "$(logCyan $func)" "| $(logGray "# $desc")"
  done | column -t -s '|'
}

__wazuh_select_function() {
  local selected
  selected=$(__wazuh_list_functions | fzf --ansi --prompt "${FZF_PREFIX_PROMPT:-} WAZUH > " --header 'Selecciona función (Enter ejecuta, ESC cancela)' --query="'")
  [[ -z "$selected" ]] && return 0

  local func=$(echo "$selected" | awk '{print $1}' | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
  if typeset -f "$func" >/dev/null; then
    echo "# Ejecutando: $func"
    "$func"
  else
    echo "Función no encontrada: $func" >&2
    return 1
  fi
}

@W() {
  # Uso: @W          -> selector interactivo
  #      @W -l       -> solo lista (tabla)
  if [[ "$1" == "-l" ]]; then
    __wazuh_list_functions
    return 0
  fi

  __wazuh_select_function
}