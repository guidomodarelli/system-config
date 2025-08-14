alias gfp="git fetch --force --prune --prune-tags --tags --jobs=8"

git_purge_history() {
  if [ -z "$1" ]; then
    echo "Usage: git_purge_history <path>"
    return 1
  fi
  git filter-repo --path "$1" --invert-paths --force
}

git_rebase_with_gpg_sign() {
  if [ -z "$1" ]; then
    echo "Usage: git_rebase_with_gpg_sign <base-commit>"
    return 1
  fi
  git rebase -i --exec "git commit --amend --no-edit --gpg-sign" "$1"
}

git_restore_deleted_files() {
	git restore --source=HEAD --staged --worktree -- $(git ls-files -d)
}

choose_git_file() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: choose_git_file <status_filter> <prompt_text>"
    return 1
  fi
  anyframe-source-git-status "$1" |
    fzf_multi --prompt "$FZF_PREFIX_PROMPT $2 " |
    awk '{print $2}'
}

gg-diff() {
	choose_git_file ".[MD]" "Git diff" |
    xargs -I{} git diff -- "{}"
}

gg-diff-cached() {
  choose_git_file "[MDRA]" "Git diff (CACHED)" |
    xargs -I{} git diff --cached -- "{}"
}

gg-add() {
  choose_git_file ".[MD?]" "Git add" |
    xargs -I{} git add -- "{}"
}

gg-restore() {
  choose_git_file ".[MD]" "Git restore" |
    xargs -I{} git restore -- "{}"
}

gg-rm() {
  choose_git_file ".[?]" "Git remove" |
    xargs -I{} rm -rf -- "{}"
}

gg-restore-staged() {
  choose_git_file "[MDRA]" "Git restore (STAGED)" |
    xargs -I{} git restore --staged -- "{}"
}

gg-ls-assume-unchanged-files() {
  git ls-files -v | grep '^[a-z]' | sed 's/^[a-z] //g'
}

gg-ls-skip-worktree-files() {
  git ls-files -v | grep '^S' | sed 's/^S //g'
}

gg-patch() {
  local patch_file="$1"

  while [ -z "$patch_file" ]; do
    printf "$(logCyan -b $POINTER) Enter patch file name: $(logGray -i "(e.g. patch-file)") "
    read -r patch_file
  done
  patch_file="${patch_file}.patch"

  local add_txt=""
  printf "$(logCyan -b $POINTER) Add .txt extension for GitHub? [y/N] "
  read -r add_txt
  if [[ "$add_txt" =~ ^[Yy]$ ]]; then
    patch_file="${patch_file}.txt"
  fi

  choose_git_file ".[MD]" "Git create patch" |
    xargs -I{} git diff -- "{}" > "$patch_file"

  logInfo "Patch file created: $(logGreen -b "$patch_file")"
}
