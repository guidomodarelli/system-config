alias gfp="git fetch --force --prune --prune-tags --tags --jobs=8"
alias gcnvm="git commit --no-verify -m"

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

GGdiff() {
	choose_git_file ".[MD]" "Git diff" |
    xargs -I{} git diff -- "{}"
}

GGdiff-cached() {
  choose_git_file "[MDRA]" "Git diff (CACHED)" |
    xargs -I{} git diff --cached -- "{}"
}

GGadd() {
  choose_git_file ".[MD?]" "Git add" |
    xargs -I{} git add -- "{}"
}

GGrestore() {
  choose_git_file ".[MD]" "Git restore" |
    xargs -I{} git restore -- "{}"
}

GGrm() {
  choose_git_file ".[?]" "Git remove" |
    xargs -I{} rm -rf -- "{}"
}

GGrestore-staged() {
  choose_git_file "[MDRA]" "Git restore (STAGED)" |
    xargs -I{} git restore --staged -- "{}"
}

GGls-assume-unchanged-files() {
  git ls-files -v | grep '^[a-z]' | sed 's/^[a-z] //g'
}

GGls-skip-worktree-files() {
  git ls-files -v | grep '^S' | sed 's/^S //g'
}

GGpatch() {
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

  choose_git_file ".[MD]" "Git create patch" |
    xargs -I{} git diff -- "{}" > "$patch_file"

  logInfo "Patch file created: $(logGreen -b "$patch_file")"
}

# === GG master selector ===
# Lista funciones git helper con descripción, permite elegir y ejecutar una.
# Uso: GG  (Enter para ejecutar la función seleccionada)
# Paso opcional: GG -l  (solo lista en stdout, sin fzf)
typeset -A __GG_DESC=(
  [git_purge_history]="purga historial de un path"
  [git_rebase_with_gpg_sign]="rebase interactivo firmando commits"
  [git_restore_deleted_files]="restaura archivos borrados (HEAD)"
  [choose_git_file]="helper selector de archivos git"
  [GGdiff]="git diff archivos mod/borr"
  [GGdiff-cached]="git diff --cached"
  [GGadd]="git add archivos"
  [GGrestore]="git restore archivos"
  [GGrm]="rm archivos untracked"
  [GGrestore-staged]="unstage cambios"
  [GGls-assume-unchanged-files]="lista assume-unchanged"
  [GGls-skip-worktree-files]="lista skip-worktree"
  [GGpatch]="crear patch"
)

GG() {
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
  } | column -t -s '|' | fzf --ansi --prompt "${FZF_PREFIX_PROMPT:-}GG > " --header 'Selecciona función (Enter ejecuta, ESC cancela)' | awk '{print $1}')
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
