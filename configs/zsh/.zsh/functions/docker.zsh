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

docker_ps() {
  @Dps "$@"
}

@Dps() {
  output="$(printf "$(format_Header_Container_Id)&$(format_Header_Names)&$(format_Header_Status)&$(format_Header_Image)&$(format_Header_Ports)")"
  output+="$BREAK_LINE\n"
  local port_ranges="[0-9]+(-[0-9]+)?"
  local protocol="(tcp|udp)"
  local default_ipv4_address="0.0.0.0"
  local ipv6_address="\[?::\]?:$port_ranges->$port_ranges(/$protocol)?"
  output+="$(docker ps -a --format "$(format_Id)&$(format_Names)&$(format_Status)&$(format_Image)&$(format_Ports) $BREAK_LINE" |
    sed -E "s!$ipv6_address!!g; s!([, ]+)+! !g; s!,\n!!g; s!${default_ipv4_address}:!!g")"
  echo "$output" | column -t -s '&'
}

docker_container_table_formatter() {
  @Dcontainers "$@"
}
@Dcontainers() {
  docker ps -a --format "table $(format_Id)\t$(format_Names)\t$(format_Status)\t$(format_Image)" | tail +2
}

docker_image_table_formatter() {
  @Dimages "$@"
}
@Dimages() {
  docker images --format "table $(format_Id)\t$(format_Repository)\t$(format_Tag)" | tail +2
}

docker_containers_show_ips() { @Dshow-ips "$@"; }
@Dshow-ips() {
  @Dcontainers | fzf --prompt="$FZF_PREFIX_PROMPT docker show ips " | awk '{print $2}' | while IFS= read -r sel; do
    { logInfo "Showing Docker container IPs from $(styleText -c cyan -b "$sel")"; echo } >&2
    docker inspect --format '{{ range $name, $network := .NetworkSettings.Networks }}{{ $name }}: {{ $network.IPAddress }} {{ "\n" }}{{ end }}' "$sel"
  done
}

docker_container_exec_select() { @Dexec "$@"; }
@Dexec() {
  logInfo "Executing Docker containers..."
  @Dcontainers | fzf --prompt="$FZF_PREFIX_PROMPT docker exec '" | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker exec -it $sel "
  done | anyframe-action-put
}

docker_logs_follow() { @Dlogs "$@"; }
@Dlogs() {
  @Dcontainers | fzf --prompt="$FZF_PREFIX_PROMPT docker logs " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker logs "; styleText -c cyan -b "$sel"; echo } >&2
    docker logs -f "$sel" 2>&1
  done
}

docker_containers_start() { @Dstart "$@"; }
@Dstart() {
  logInfo "Starting Docker containers..."
  @Dcontainers | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker start " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker start "; styleText -c cyan -b "$sel"; echo } >&2
    docker start "$sel"
  done
}

docker_containers_restart() { @Drestart "$@"; }
@Drestart() {
  logInfo "Restarting Docker containers..."
  @Dcontainers | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker restart " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker restart "; styleText -c cyan -b "$sel"; echo } >&2
    docker restart "$sel"
  done
}

docker_containers_stop() { @Dstop "$@"; }
@Dstop() {
  logInfo "Stopping Docker containers..."
  @Dcontainers | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker stop " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker stop "; styleText -c cyan -b "$sel"; echo } >&2
    docker stop "$sel"
  done
}

docker_containers_remove() { @Drm "$@"; }
@Drm() {
  logInfo "Removing Docker containers..."
  @Dcontainers | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm " | awk '{print $2}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker rm -f "; styleText -c cyan -b "$sel"; echo } >&2
    docker rm -f "$sel"
  done
}

docker_images_remove() { @Drmi "$@"; }
@Drmi() {
  logInfo "Removing Docker images..."
  docker_image_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm image " | awk '{print $2 ":" $3}' | while IFS= read -r sel; do
    { styleText -c yellow -b -i "docker rmi "; styleText -c cyan -b "$sel"; echo } >&2
    docker rmi "$sel"
  done
}

docker_network_remove() { @Drmn "$@"; }
@Drmn() {
  logInfo "Removing Docker networks..."
  docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" | tail +2 |
    fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm network " | awk '{print $2}' | while IFS= read -r sel; do
      { styleText -c yellow -b -i "docker network rm "; styleText -c cyan -b "$sel"; echo } >&2
      docker network rm "$sel"
    done
}

docker_volumes_remove() { @Drmv "$@"; }
@Drmv() {
  logInfo "Removing Docker volumes..."
  docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | tail +2 |
    fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm volume " | awk '{print $1}' | while IFS= read -r sel; do
      { styleText -c yellow -b -i "docker volume rm "; styleText -c cyan -b "$sel"; echo } >&2
      docker volume rm "$sel"
    done
}

# --- Master selector (@D) ---
__docker_get_descriptions() {
  cat <<'__EOF__'
docker_containers_status_summary|resumen estado de contenedores
docker_ps|tabla docker ps formateada
docker_container_table_formatter|tabla base contenedores (IDs)
docker_image_table_formatter|tabla base imágenes
docker_containers_show_ips|mostrar IPs de contenedores
docker_container_exec_select|preparar comando exec interactivo
docker_logs_follow|seguir logs de un contenedor
docker_containers_start|iniciar contenedores seleccionados
docker_containers_restart|reiniciar contenedores seleccionados
docker_containers_stop|detener contenedores seleccionados
docker_containers_remove|eliminar contenedores seleccionados
docker_images_remove|eliminar imágenes seleccionadas
docker_network_remove|eliminar redes seleccionadas
docker_volumes_remove|eliminar volúmenes seleccionados
__EOF__
}

@D() {
  # Uso: @D -l (lista) | @D (interactivo)
  if [[ "$1" == "-l" ]]; then
    selector_list __docker_get_descriptions
    return 0
  fi
  local func
  func=$(selector_fzf __docker_get_descriptions "DOCKER >") || return 0
  echo "$func" | anyframe-action-put
}
