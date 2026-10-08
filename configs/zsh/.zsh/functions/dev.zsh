--build() {
  npm run build
}

--dev() {
  local repo_root

  repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not inside a Git repository" >&2
    return 1
  }

  if git -C "$repo_root" grep -q -E '"start-dev"[[:space:]]*:' HEAD -- package.json; then
    npm run start-dev
  elif git -C "$repo_root" grep -q -E '"dev"[[:space:]]*:' HEAD -- package.json; then
    npm run dev
  else
    echo "Neither start-dev nor dev exists in package.json" >&2
    return 1
  fi
}
