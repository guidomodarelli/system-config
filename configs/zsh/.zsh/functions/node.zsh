@prettier:fix() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "Warning: fzf is not installed"
    return 1
  fi

  cd $(git rev-parse --show-toplevel)

  # Try to find prettierd first, fallback to prettier
  BIN_PRETTIER=$(command -v prettierd)
  if [ -z "$BIN_PRETTIER" ]; then
    BIN_PRETTIER=$(find . -type f,l -name "prettier" | sort | grep 'node_modules/.bin/prettier' | head -n 1)
  fi

  if [ -z "$BIN_PRETTIER" ]; then
    echo "Error: Neither prettierd nor prettier found"
    return 1
  fi

  BRANCH=$(git branch | grep -v $(git branch --show-current) | sed -E 's!\\*?[ ]+!!g' | grep -vE '[0-9]+-' | fzf --prompt='Select branch to format against: ')

  FILES=$(git diff --name-status $(git merge-base HEAD $BRANCH) HEAD | grep -vE "^D" | awk '{ if ($1 == "R") print $3; else print $2 }')
  
  if [ -n "$FILES" ]; then
    echo "$FILES" | xargs -I{} $BIN_PRETTIER --write {} --config .prettierrc --ignore-unknown
  fi
}