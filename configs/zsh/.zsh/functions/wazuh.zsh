wzstart() {
  logInfo "Executing Docker containers..."
  docker_table_formatter | fzf --prompt="$FZF_PREFIX_PROMPT docker exec '" | awk '{print $2}' | while IFS= read -r sel; do
    echo "clear; docker exec -it $sel yarn start --no-base-path"
  done | anyframe-action-put
}