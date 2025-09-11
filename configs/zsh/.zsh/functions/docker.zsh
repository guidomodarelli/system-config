format_Header() {
  styleText -u -b -i "$@"
}

# Function-based approach for column colors
function column_color() {
  case "$1" in
  "ID") echo "yellow" ;;
  "NAMES") echo "blue" ;;
  "REPOSITORY") echo "blue" ;;
  "TAG") echo "cyan" ;;
  "STATUS") echo "green" ;;
  "IMAGE") echo "cyan" ;;
  "PORTS") echo "gray" ;;
  *) echo "" ;;
  esac
}

# Function-based approach for status colors
function status_color() {
  case "$1" in
  "RUNNING") echo "green" ;;
  "EXITED") echo "red" ;;
  "PAUSED") echo "gray" ;;
  "RESTARTING") echo "yellow" ;;
  "DEAD") echo "magenta" ;;
  *) echo "" ;;
  esac
}

format_Header_Container_Id() {
  format_Header -c $(column_color "ID") 'CONTAINER ID'
}

format_Id() {
  styleText -c $(column_color "ID") '{{.ID}}'
}

format_Header_Names() {
  format_Header -c $(column_color "NAMES") 'NAMES'
}

format_Names() {
  styleText -c $(column_color "NAMES") '{{.Names}}'
}

format_Repository() {
  styleText -c $(column_color "REPOSITORY") '{{.Repository}}'
}

format_Tag() {
  styleText -c $(column_color "TAG") -b -i '{{.Tag}}'
}

format_Header_Image() {
  format_Header -c $(column_color "IMAGE") 'IMAGE'
}

format_Image() {
  styleText -c $(column_color "IMAGE") -b '{{.Image}}'
}

format_Header_Status() {
  format_Header -c $(column_color "STATUS") 'STATUS'
}

format_Status() {
  styleText -c $(column_color "STATUS") '{{.Status}}'
}

format_Header_Ports() {
  format_Header -c $(column_color "PORTS") 'PORTS'
}

format_Ports() {
  styleText -c $(column_color "PORTS") '{{.Ports}}'
}

# --- Renamed Docker helper functions (descriptive) ---

docker_containers_status_summary() {
  list_docker_containers_status "$@"  # manter lógica previa (renombrada más abajo)
}
# Re-define original with new name logic (inline move)
# Old definition body moved here:
# (Original list_docker_containers_status body)

# Replace original list_docker_containers_status with wrapper (backwards compatibility)
list_docker_containers_status() {
  styleText -u -i "Docker Containers Status"
  echo
  {
    echo "$(styleText -c $(status_color "RUNNING") -i Running): $(logCyan -b "$(docker ps -q | wc -l)")"
    echo "$(styleText -c $(status_color "EXITED") -i Exited): $(logCyan -b "$(docker ps -q -f status=exited | wc -l)")"
    echo "$(styleText -c $(status_color "PAUSED") -i Paused): $(logCyan -b "$(docker ps -q -f status=paused | wc -l)")"
    echo "$(styleText -c $(status_color "RESTARTING") -i Restarting): $(logCyan -b "$(docker ps -q -f status=restarting | wc -l)")"
    echo "$(styleText -c $(status_color "DEAD") -i Dead): $(logCyan -b "$(docker ps -q -f status=dead | wc -l)")"
    echo "$(styleText -i Total): $(logCyan -b "$(docker ps -q -a | wc -l)")"
  } | column -t -s ':'
}

docker_ps_table() {
  DDps "$@"
}

# Provide actual body (moved from DDps)
DDps() {
  output="$(printf "$(format_Header_Container_Id)@$(format_Header_Names)@$(format_Header_Status)@$(format_Header_Image)@$(format_Header_Ports)")"
  output+="$BREAK_LINE\n"
  local port_ranges="[0-9]+(-[0-9]+)?"
  local protocol="(tcp|udp)"
  local default_ipv4_address="0.0.0.0"
  local ipv6_address="\[?::\]?:$port_ranges->$port_ranges(/$protocol)?"
  output+="$(docker ps -a --format "$(format_Id)@$(format_Names)@$(format_Status)@$(format_Image)@$(format_Ports) $BREAK_LINE" |
    sed -E "s@$ipv6_address@@g; s@([, ]+)+@ @g; s@,\n@@g; s@${default_ipv4_address}:@@g")"
  echo "$output" | column -t -s '@'
}

docker_container_table_formatter() {
  docker_table_formatter "$@"
}
# Actual body (moved from docker_table_formatter)
docker_table_formatter() {
  docker ps -a --format "table $(format_Id)\t$(format_Names)\t$(format_Status)\t$(format_Image)" | tail +2
}

docker_image_table_formatter() {
  docker_images_table_formatter "$@"
}
# Actual body (moved from docker_images_table_formatter)
docker_images_table_formatter() {
  docker images --format "table $(format_Id)\t$(format_Repository)\t$(format_Tag)" | tail +2
}

docker_containers_show_ips() { DDshow-ips "$@"; }
DDshow-ips() {
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker show ips " | awk '{print $2}' | while IFS= read -r sel; do
    { logInfo "Showing Docker container IPs from $(styleText -c cyan -b "$sel")"; echo } >&2
    docker inspect --format '{{ range $name, $network := .NetworkSettings.Networks }}{{ $name }}: {{ $network.IPAddress }} {{ "\n" }}{{ end }}' "$sel"
  done
}

docker_container_exec_select() { DDexec "$@"; }
DDexec() {
  logInfo "Executing Docker containers..."
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker exec '" | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker exec -it $sel "
  done | anyframe-action-put
}

docker_logs_follow() { DDlogs "$@"; }
DDlogs() {
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker logs " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker logs "; styleText -c cyan -b "$sel"; echo } >&2
    docker logs -f "$sel" 2>&1
  done
}

docker_containers_start() { DDstart "$@"; }
DDstart() {
  logInfo "Starting Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker start " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker start "; styleText -c cyan -b "$sel"; echo } >&2
    docker start "$sel"
  done
}

docker_containers_restart() { DDrestart "$@"; }
DDrestart() {
  logInfo "Restarting Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker restart " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker restart "; styleText -c cyan -b "$sel"; echo } >&2
    docker restart "$sel"
  done
}

docker_containers_stop() { DDstop "$@"; }
DDstop() {
  logInfo "Stopping Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker stop " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker stop "; styleText -c cyan -b "$sel"; echo } >&2
    docker stop "$sel"
  done
}

docker_containers_remove() { DDrm "$@"; }
DDrm() {
  logInfo "Removing Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker rm -f "; styleText -c cyan -b "$sel"; echo } >&2
    docker rm -f "$sel"
  done
}

docker_images_remove() { DDrmi "$@"; }
DDrmi() {
  logInfo "Removing Docker images..."
  docker_images_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm image " | awk '{print $2 ":" $3}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker rmi "; styleText -c cyan -b "$sel"; echo } >&2
    docker rmi "$sel"
  done
}

# --- Master selector (@dd) ---
unset __DD_DESC
typeset -A __DD_DESC=(
  [docker_containers_status_summary]="resumen estado de contenedores"
  [docker_ps_table]="tabla docker ps formateada"
  [docker_container_table_formatter]="tabla base contenedores (IDs)"
  [docker_image_table_formatter]="tabla base imágenes"
  [docker_containers_show_ips]="mostrar IPs de contenedores"
  [docker_container_exec_select]="preparar comando exec interactivo"
  [docker_logs_follow]="seguir logs de un contenedor"
  [docker_containers_start]="iniciar contenedores seleccionados"
  [docker_containers_restart]="reiniciar contenedores seleccionados"
  [docker_containers_stop]="detener contenedores seleccionados"
  [docker_containers_remove]="eliminar contenedores seleccionados"
  [docker_images_remove]="eliminar imágenes seleccionadas"
)

@dd() {
  if [[ "$1" == "-l" ]]; then
    {
      for k in ${(ok)__DD_DESC}; do
        echo "$(logCyan $k)" "| $(logGray "# ${__DD_DESC[$k]}")"
      done
    } | column -t -s '|'
    return 0
  fi
  local selected
  selected=$({
    for k in ${(ok)__DD_DESC}; do
      echo "$(logCyan $k)" "| $(logGray "# ${__DD_DESC[$k]}")"
    done
  } | column -t -s '|' | fzf --ansi --prompt "${FZF_PREFIX_PROMPT:-} DOCKER > " --header 'Selecciona función (Enter ejecuta, ESC cancela)' --query="'" | awk '{print $1}')
  [[ -z "$selected" ]] && return 0
  local clean=$(echo "$selected" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
  local func=${clean%%$'\t'*}
  if typeset -f "$func" >/dev/null; then
    echo "# Ejecutando: $func"
    "$func"
  else
    echo "Función no encontrada: $func" >&2
    return 1
  fi
}
