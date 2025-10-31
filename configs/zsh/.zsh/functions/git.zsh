alias gfp="git fetch --force --prune --prune-tags --tags --jobs=8"
alias gcnvm="git commit --no-verify -m"

__git_branch_suggestions() {
  local current
  local -a branches

  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  branches=($(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | grep -v "^$current$"))

  _describe -t branches 'local branches' branches
}

@Ghistory_purge() { git_history_purge "$@"; }
git_history_purge() {
  if [ -z "$1" ]; then
    echo "Usage: git_history_purge <path>"
    return 1
  fi
  git filter-repo --path "$1" --invert-paths --force
}

@Grebase_sign_all() { git_rebase_sign_all "$@"; }
git_rebase_sign_all() {
  if [ -z "$1" ]; then
    echo "Usage: git_rebase_sign_all <base-commit>"
    return 1
  fi
  git rebase -i --exec "git commit --amend --no-edit --gpg-sign" "$1"
}

@Gdeleted_files_restore() { git_deleted_files_restore "$@"; }
git_deleted_files_restore() {
  git restore --source=HEAD --staged --worktree -- $(git ls-files -d)
}

git_files_select() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: git_files_select <status_filter> <prompt_text>"
    return 1
  fi
  anyframe-source-git-status "$1" |
    fzf_multi --prompt "$FZF_PREFIX_PROMPT $2 " |
    awk '{print $2}'
}

@Gdiff() { git_diff "$@"; }
git_diff() {
  git_files_select ".[MD]" "Git diff" |
    xargs -I{} git diff -- "{}"
}

@Gdiff_index() { git_diff_index "$@"; }
git_diff_index() {
  git_files_select "[MDRA]" "Git diff (INDEX)" |
    xargs -I{} git diff --cached -- "{}"
}

@Gadd_select() { git_add_select "$@"; }
git_add_select() {
  git_files_select ".[MD?]" "Git add" |
    xargs -I{} git add -- "{}"
}

@Grestore_select() { git_restore_select "$@"; }
git_restore_select() {
  git_files_select ".[MD]" "Git restore" |
    xargs -I{} git restore -- "{}"
}

@Guntracked_remove() { git_untracked_remove "$@"; }
git_untracked_remove() {
  git_files_select ".[?]" "Git remove" |
    xargs -I{} rm -rf -- "{}"
}

@Gunstage() { git_unstage "$@"; }
git_unstage() {
  git_files_select "[MDRA]" "Git unstage" |
    xargs -I{} git restore --staged -- "{}"
}

@Gassume_unchanged_list() { git_assume_unchanged_list "$@"; }
git_assume_unchanged_list() {
  git ls-files -v | grep '^[a-z]' | sed 's¦^[a-z] ¦¦g'
}

@Gskip_worktree_list() { git_skip_worktree_list "$@"; }
git_skip_worktree_list() {
  git ls-files -v | grep '^S' | sed 's¦^S ¦¦g'
}

@Gpatch_create() { git_patch_create "$@"; }
git_patch_create() {
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
    patch_file="${patch_file}.patch.txt"
  fi
  git_files_select ".[MD]" "Git create patch" |
    xargs -I{} git diff -- "{}" >"$patch_file"
  logInfo "Patch file created: $(logGreen -b "$patch_file")"
}

@Gbranch_delete_local_remote() { git_branch_delete_local_remote "$@"; }
git_branch_delete_local_remote() {
  local force=0
  while [[ "$1" == -* ]]; do
    case "$1" in
      -f|--force) force=1 ;;
      -h|--help)
        echo "Uso: git_branch_delete_local_remote [-f|--force] [branch]"
        echo "Sin 'branch' abre selector interactivo."
        return 0
        ;;
      *) echo "Flag desconocido: $1" ; return 1 ;;
    esac
    shift
  done

  local branch="$1"
  if [ -z "$branch" ]; then
    local current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    branch="$(git branch --format='%(refname:short)' | grep -v "^${current}$" | fzf --prompt 'Borrar branch > ' 2>/dev/null)"
  fi
  [ -z "$branch" ] && { echo "Cancelado."; return 1; }

  local current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ "$branch" = "$current" ]; then
    echo "No se puede borrar la branch actual: $branch"
    return 1
  fi

  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    if [ $force -eq 0 ]; then
      echo "Branch protegida ($branch). Use --force para eliminar."
      return 1
    fi
  fi

  if [ $force -eq 1 ]; then
    git branch -D "$branch" || return 1
  else
    git branch -d "$branch" || return 1
  fi

  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "${branch}@{upstream}" 2>/dev/null)"
  if [ -n "$upstream" ]; then
    local remote="${upstream%%/*}"
    local remotebranch="${upstream#*/}"
    git push "$remote" --delete "$remotebranch" 2>/dev/null && \
      logInfo "Remota eliminada: $(logGreen -b "$remote/$remotebranch")"
  else
    if git ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1; then
      git push origin --delete "$branch" 2>/dev/null && \
        logInfo "Remota eliminada: $(logGreen -b "origin/$branch")"
    fi
  fi

  logInfo "Branch local eliminada: $(logGreen -b "$branch")"
}

_git_branch_delete_local_remote_completions() {
  _arguments -C \
    '(-f --force)'{-f,--force}'[force deletion (also protected branches)]' \
    '(-h --help)'{-h,--help}'[show help]' \
    '1:branch:->branch' \
    '*:args:->args' && return 0

  __git_branch_suggestions
}

compdef _git_branch_delete_local_remote_completions git_branch_delete_local_remote
compdef _git_branch_delete_local_remote_completions @Gbranch_delete_local_remote

# === GG master selector ===
__git_get_descriptions() {
  cat <<'__EOF__'
git_history_purge|elimina completamente un archivo/directorio del historial de Git
git_rebase_sign_all|rebase interactivo firmando todos los commits con GPG
git_deleted_files_restore|restaura todos los archivos eliminados desde HEAD
git_files_select|selector interactivo de archivos Git con filtros de estado
git_diff|visualiza diferencias de archivos modificados/eliminados
git_diff_index|visualiza diferencias de archivos en staging area
git_add_select|añade archivos seleccionados al staging area
git_restore_select|descarta cambios de archivos seleccionados
git_untracked_remove|elimina archivos no rastreados del sistema de archivos
git_unstage|quita archivos del staging area (unstage)
git_assume_unchanged_list|lista archivos marcados como assume-unchanged
git_skip_worktree_list|lista archivos marcados como skip-worktree
git_patch_create|genera archivo patch desde diferencias seleccionadas
git_branch_delete_local_remote|elimina una branch local y su remota asociada (usa --force para main/master)
__EOF__
}

@G() {
  # Uso: @G -l (lista) | @G (interactivo)
  if [[ "$1" == "-l" ]]; then
    selector_list __git_get_descriptions
    return 0
  fi
  local func
  func=$(selector_fzf __git_get_descriptions "GIT >") || return 0
  echo "$func" | anyframe-action-put
}
