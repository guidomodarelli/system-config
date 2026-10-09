#!/bin/sh
# Relinks the dotfiler hard links that a git operation detached by recreating
# their source files under configs/. Shared by the post-checkout, post-merge
# and post-rewrite hooks; it never fails the git operation that triggered it.
#
# Usage: relink-hard-links.sh [<previous-ref> <new-ref>]
#   With both refs it only runs when configs/ differs between them; without
#   refs it always runs.

CONFIGS_PATHSPEC="configs"
HOOK_LOG_PREFIX="[git hook]"

log_hook_warning() {
  printf "%s Aviso: %s\n" "$HOOK_LOG_PREFIX" "$1" >&2
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Linked worktrees share core.hooksPath: relinking from one of them would point
# the home destinations at files of a worktree that may be removed later.
git_dir=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null) || exit 0
git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$git_dir" = "$git_common_dir" ] || exit 0

if [ $# -eq 2 ] && git -C "$repo_root" diff --quiet "$1" "$2" -- "$CONFIGS_PATHSPEC" 2>/dev/null; then
  exit 0
fi

# The hook environment points git at this repository; dotfiler resolves it on
# its own from the working directory.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
cd "$repo_root" || exit 0

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
  if command -v pwsh >/dev/null 2>&1; then
    powershell_command="pwsh"
  else
    powershell_command="powershell.exe"
  fi
  "$powershell_command" -NoProfile -ExecutionPolicy Bypass \
    -File "$repo_root/scripts/dotfiler/dotfiler.ps1" --hard-links-only --quiet
  ;;
*)
  bash "$repo_root/scripts/dotfiler/dotfiler.sh" --hard-links-only --quiet
  ;;
esac
dotfiler_status=$?

if [ "$dotfiler_status" -ne 0 ]; then
  log_hook_warning "dotfiler no pudo reenlazar los hard links (exit $dotfiler_status). Ejecutalo a mano con --hard-links-only para ver el detalle."
fi
exit 0
