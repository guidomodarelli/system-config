alias gfp="git fetch --force --prune --prune-tags --tags --jobs=8"
alias gcnvm="git commit --no-verify -m"

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
  git ls-files -v | grep '^[a-z]' | sed 's/^[a-z] //g'
}

@Gskip_worktree_list() { git_skip_worktree_list "$@"; }
git_skip_worktree_list() {
  git ls-files -v | grep '^S' | sed 's/^S //g'
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

# === GG master selector ===
# Lista funciones git helper con descripción, permite elegir y ejecutar una.
# Uso: GG  (Enter para ejecutar la función seleccionada)
# Paso opcional: GG -l  (solo lista en stdout, sin fzf)
typeset -A __GG_DESC=(
  [git_history_purge]="elimina completamente un archivo/directorio del historial de Git"
  [git_rebase_sign_all]="rebase interactivo firmando todos los commits con GPG"
  [git_deleted_files_restore]="restaura todos los archivos eliminados desde HEAD"
  [git_files_select]="selector interactivo de archivos Git con filtros de estado"
  [git_diff]="visualiza diferencias de archivos modificados/eliminados"
  [git_diff_index]="visualiza diferencias de archivos en staging area"
  [git_add_select]="añade archivos seleccionados al staging area"
  [git_restore_select]="descarta cambios de archivos seleccionados"
  [git_untracked_remove]="elimina archivos no rastreados del sistema de archivos"
  [git_unstage]="quita archivos del staging area (unstage)"
  [git_assume_unchanged_list]="lista archivos marcados como assume-unchanged"
  [git_skip_worktree_list]="lista archivos marcados como skip-worktree"
  [git_patch_create]="genera archivo patch desde diferencias seleccionadas"
)

@G() {
  if [[ "$1" == "-l" ]]; then
    {
      for k in ${(ok)__GG_DESC}; do
        echo "$(logCyan $k)" "| $(logGray "# ${__GG_DESC[$k]}")"
      done
    } | column -t -s '|'
    return 0
  fi

  # Generar listado coloreado para fzf (con soporte ANSI)
  local selected
  selected=$({
    for k in ${(ok)__GG_DESC}; do
      echo "$(logCyan $k)" "| $(logGray "# ${__GG_DESC[$k]}")"
    done
  } | column -t -s '|' | fzf --ansi --prompt "${FZF_PREFIX_PROMPT:-} GG > " --header 'Selecciona función (Enter ejecuta, ESC cancela)' --query="'" | awk '{print $1}')
  [[ -z "$selected" ]] && return 0

  # Quitar códigos ANSI y extraer nombre (columna 1 antes de tab)
  local clean=$(echo "$selected" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
  local func=${clean%%$'\t'*}

  if typeset -f "$func" >/dev/null; then
    echo "# Ejecutando: $func"
    "$func"
  else
    echo "Función no encontrada: $func" >&2
    return 1
  fi
}
