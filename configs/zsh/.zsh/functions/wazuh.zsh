wzstart() {
  logInfo "Executing Docker containers..."
  docker_table_formatter | grep -v "runner" | grep -E "(osd-dev|dashboard)" | fzf --prompt="$FZF_PREFIX_PROMPT docker exec " --query "'" | awk '{print $2}' | while IFS= read -r sel; do
    echo "clear; docker exec -it $sel yarn start --no-base-path"
  done | anyframe-action-put
}