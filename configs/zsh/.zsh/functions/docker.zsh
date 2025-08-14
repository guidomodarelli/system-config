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

dd-ps() {
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

docker_table_formatter() {
  docker ps -a --format "table $(format_Id)\t$(format_Names)\t$(format_Status)\t$(format_Image)" | tail +2
}

docker_images_table_formatter() {
  docker images --format "table $(format_Id)\t$(format_Repository)\t$(format_Tag)" | tail +2
}

dd-show-ips() {
  logInfo "Showing Docker container IPs..."
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker show ips " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker inspect $sel"
    docker inspect --format '{{ range $name, $network := .NetworkSettings.Networks }}{{ $name }}: {{ $network.IPAddress }} {{ "\n" }}{{ end }}' "$sel"
  done
}

dd-exec() {
  logInfo "Executing Docker containers..."
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker exec " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker exec -it $sel "
  done | anyframe-action-put
}

dd-logs() {
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker logs " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker logs $sel"
    docker logs -f "$sel" 2>&1
  done
}

dd-start() {
  logInfo "Starting Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker start " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker start $sel"
    docker start "$sel"
  done
}

dd-restart() {
  logInfo "Restarting Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker restart " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker restart $sel"
    docker restart "$sel"
  done
}

dd-stop() {
  logInfo "Stopping Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker stop " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker stop $sel"
    docker stop "$sel"
  done
}

dd-rm() {
  logInfo "Removing Docker containers..."
  docker_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm " | awk '{print $2}' | while IFS= read -r sel; do
    echo "docker rm -f $sel"
    docker rm -f "$sel"
  done
}

dd-rmi() {
  logInfo "Removing Docker images..."
  docker_images_table_formatter | fzf_multi --prompt="$FZF_PREFIX_PROMPT docker rm image " | awk '{print $3}' | while IFS= read -r sel; do
    echo "docker rmi $sel"
    docker rmi "$sel"
  done
}
