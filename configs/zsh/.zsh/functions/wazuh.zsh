wzstart() {
  logInfo "Executing Docker containers..."
  docker_table_formatter | grep -v "runner" | grep -E "(osd-dev|dashboard)" | fzf --prompt="$FZF_PREFIX_PROMPT docker exec " --query "'" | awk '{print $2}' | while IFS= read -r sel; do
    echo "clear; docker exec -it $sel yarn start --no-base-path"
  done | anyframe-action-put
}

# --- Master selector (@W) ---
__wazuh_get_descriptions() {
  cat <<'__EOF__'
wzstart|iniciar yarn start en contenedor wazuh/osd seleccionado
__EOF__
}
@W() {
  # Uso: @W          -> selector interactivo
  #      @W -l       -> solo lista (tabla)
  if [[ "$1" == "-l" ]]; then
    selector_list __wazuh_get_descriptions
    return 0
  fi
  local func
  func=$(selector_fzf __wazuh_get_descriptions "WAZUH >") || return 0
  [[ -z "$func" ]] && return 0
  if typeset -f "$func" >/dev/null; then
    echo "# Ejecutando: $func"
    "$func"
  else
    echo "Función no encontrada: $func" >&2
    return 1
  fi
}