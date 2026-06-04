# Se cachea la salida de `zoxide init zsh` para evitar un subproceso en cada startup (~53ms).
# El cache se regenera automáticamente cuando el binario cambia (ej. al actualizar zoxide).
# Para forzar regeneración: rm "${ZSH_CACHE_DIR}/.zoxide_init.zsh"
#
# Trade-off: al actualizar zoxide, el primer startup regenera el cache (~53ms) antes de
# sourcing. Las sesiones siguientes vuelven a ser rápidas. No se pierden funcionalidades
# nuevas: el cache siempre refleja la versión activa del binario.
_ZOXIDE_BIN=$(command -v zoxide 2>/dev/null)

if [[ -n "$_ZOXIDE_BIN" ]]; then
  _ZOXIDE_INIT_CACHE="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}/.zoxide_init.zsh"
  if [[ ! -f "$_ZOXIDE_INIT_CACHE" || "$_ZOXIDE_BIN" -nt "$_ZOXIDE_INIT_CACHE" ]]; then
    zoxide init zsh > "$_ZOXIDE_INIT_CACHE"
  fi
  source "$_ZOXIDE_INIT_CACHE"
fi

unset _ZOXIDE_BIN _ZOXIDE_INIT_CACHE
