@prettier:fix() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "Warning: fzf is not installed"
    return 1
  fi

  pushd $(git rev-parse --show-toplevel)

    BIN_PRETTIER=$(find . -type f,l -name "prettier" | sort | grep 'node_modules/.bin/prettier' | head -n 1)

    BRANCH=$(git branch | grep -v $(git branch --show-current) | sed -E 's!\\*?[ ]+!!g' | grep -vE '[0-9]+-' | fzf --prompt='Select branch to format against: ')

    git diff --name-only $(git merge-base HEAD $BRANCH) HEAD | xargs -I{} $BIN_PRETTIER --write {} --config .prettierrc

  popd
}