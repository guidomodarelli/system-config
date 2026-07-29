# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Third-party plugins                                                          │
# └──────────────────────────────────────────────────────────────────────────────┘
# Sourced después de oh-my-zsh via el config loader (~0ms overhead vs ~1295ms de antigen).
# Los plugins de omz (git, docker, etc.) se declaran en plugins=() en .zshrc.
#
# Se reemplazó antigen por source directos. Trade-offs y desventajas:
#
# - Sin gestión automática de plugins: agregar o quitar un plugin requiere editar
#   este archivo (terceros) o plugins=() en .zshrc (omz). Antigen lo centralizaba.
# - Sin `antigen update`: actualizar plugins es manual (git pull en third-party/).
# - Sin manejo de errores: si un plugin falla al sourcear, zsh no lo reporta
#   claramente. Antigen mostraba avisos por plugin fallido.
# - Los plugins deben mantenerse actualizados manualmente en third-party/.
#
# IMPORTANTE: zsh-syntax-highlighting debe ser el último ya que envuelve los
# widgets existentes. Agregar plugins nuevos antes de esa línea.

_THIRD_PARTY="$HOME/system-config/third-party"

source "$_THIRD_PARTY/fzf-tab/fzf-tab.plugin.zsh"
zic_custom_binding='^X^I'
source "$_THIRD_PARTY/zsh-interactive-cd/zsh-interactive-cd.plugin.zsh"
source "$_THIRD_PARTY/anyframe/anyframe.plugin.zsh"
source "$_THIRD_PARTY/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
source "$_THIRD_PARTY/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"

unset _THIRD_PARTY
