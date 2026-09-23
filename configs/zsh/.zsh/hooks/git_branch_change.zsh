# Auto ejecutar acciones al cambiar de rama de git
source $ZSH_HOME/hooks/load_nvmrc.zsh
autoload -U add-zsh-hook

# Variable global para almacenar la rama anterior
typeset -g PREVIOUS_GIT_BRANCH=""

git_branch_changed() {
  local current_branch
  if (( $+functions[_murilasso_refresh_git] )); then
    # El tema murilasso ya consultó git en este prompt (un solo proceso)
    current_branch="$_MURILASSO_GIT_BRANCH"
    [[ "$current_branch" == "HEAD" ]] && current_branch=""
  else
    current_branch=$(git branch --show-current 2>/dev/null)
  fi

  if [[ -n "$current_branch" ]]; then

    # Si la rama actual es diferente a la anterior
    if [[ -n "$current_branch" && "$current_branch" != "$PREVIOUS_GIT_BRANCH" ]]; then
      # echo "🔄 Cambiando de rama » $(logCyan -i -u $current_branch)"

      # Aquí puedes agregar más acciones personalizadas:
      # - Instalar dependencias específicas de la rama
      # - Ejecutar scripts de configuración
      # - Mostrar información relevante de la rama

      # Actualizar la variable con la rama actual
      PREVIOUS_GIT_BRANCH="$current_branch"

      load_nvmrc
    fi
  fi
}

# Solo en precmd: corre después de cada cd y de cada comando, antes del prompt.
# Engancharlo también a chpwd lo ejecutaba dos veces por cada cd.
add-zsh-hook precmd git_branch_changed
