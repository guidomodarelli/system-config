# Reemplaza el plugin fzf de Oh My Zsh ($ZSH_CUSTOM tiene prioridad sobre $ZSH/plugins).
# El original ejecuta `fzf --version` y `fzf --zsh` en cada startup (~18ms); acá la
# salida de `fzf --zsh` se cachea y se regenera cuando el binario cambia.
# Si fzf no existe o es anterior a 0.48 (sin `--zsh`), delega en el plugin original.
# Para forzar regeneración: rm "${ZSH_CACHE_DIR}/.fzf_init.zsh"
() {
  local fzf_binary="${commands[fzf]}"
  local fzf_init_cache="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}/.fzf_init.zsh"
  local original_plugin="$ZSH/plugins/fzf/fzf.plugin.zsh"

  if [[ -n "$fzf_binary" && ( ! -s "$fzf_init_cache" || "${fzf_binary:A}" -nt "$fzf_init_cache" ) ]]; then
    fzf --zsh >| "$fzf_init_cache" 2>/dev/null || command rm -f "$fzf_init_cache"
  fi

  if [[ -z "$fzf_binary" || ! -s "$fzf_init_cache" ]]; then
    source "$original_plugin"
    return
  fi

  source "$fzf_init_cache"

  if [[ -z "$FZF_DEFAULT_COMMAND" ]]; then
    if (( $+commands[fd] )); then
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    elif (( $+commands[rg] )); then
      export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
    elif (( $+commands[ag] )); then
      export FZF_DEFAULT_COMMAND='ag -l --hidden -g "" --ignore .git'
    fi
  fi
}
