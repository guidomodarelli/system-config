@prettier:fix() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "Warning: fzf is not installed"
    return 1
  fi

  cd $(git rev-parse --show-toplevel)

  BIN_PRETTIER=$(find . -type f,l -name "prettier" | sort | grep 'node_modules/.bin/prettier' | head -n 1)

  BRANCH=$(git branch | grep -v $(git branch --show-current) | sed -E 's!\\*?[ ]+!!g' | grep -vE '[0-9]+-' | fzf --prompt='Select branch to format against: ')

  git diff --name-status $(git merge-base HEAD $BRANCH) HEAD | grep -vE "^(D|R)" | awk '{ print $2 }' | xargs -I{} $BIN_PRETTIER --write {} --config .prettierrc
  git diff --name-status $(git merge-base HEAD $BRANCH) HEAD | grep -E "^R" | awk '{ print $3 }' | xargs -I{} $BIN_PRETTIER --write {} --config .prettierrc
}