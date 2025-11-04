__wzstart_exec() {
  local extra_flag="$1"  # e.g. " --no-base-path" o vacío
  logInfo "Executing Docker containers..."
  @Dcontainers | grep -v "runner" | grep -E "(osd(-dev)?-1|dashboard)" | fzf --prompt="$FZF_PREFIX_PROMPT docker exec " --query "'" | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker exec -it $sel yarn start${extra_flag}"
  done | anyframe-action-put
}

@WWstart() { wzstart "$@"; }
wzstart() { __wzstart_exec " --no-base-path"; }

@WWstart-with-base-path() { wzstart-base-path "$@"; }
wzstart-base-path() { __wzstart_exec ""; }

# --- Master selector (@WW) ---
__wazuh_get_descriptions() {
  cat <<'__EOF__'
wzstart|iniciar yarn start en contenedor wazuh/osd seleccionado
wzstart-base-path|iniciar yarn start (con base path) en contenedor wazuh/osd seleccionado
__EOF__
}

@WW() {
  # Uso: @WW -l (lista) | @WW (interactivo)
  if [[ "$1" == "-l" ]]; then
    selector_list __wazuh_get_descriptions
    return 0
  fi
  local func
  func=$(selector_fzf __wazuh_get_descriptions "WAZUH >") || return 0
  eval "$func"
}