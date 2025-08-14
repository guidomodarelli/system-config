# Auto ejecutar acciones al cambiar de rama de git
autoload -U add-zsh-hook

# Variable global para almacenar la rama anterior
typeset -g PREVIOUS_GIT_BRANCH=""

git_branch_changed() {
  # Verificar si estamos en un repositorio git
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    # Si la rama actual es diferente a la anterior
    if [[ -n "$current_branch" && "$current_branch" != "$PREVIOUS_GIT_BRANCH" ]]; then
      echo "🔄 Cambiando de rama » $(logCyan -i -u $current_branch)"

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

add-zsh-hook chpwd git_branch_changed
add-zsh-hook precmd git_branch_changed  # También verificar antes de cada comando
