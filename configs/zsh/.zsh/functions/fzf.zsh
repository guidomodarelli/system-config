export FZF_DEFAULT_HEADER_WITH_MULTI='(Multi-select) Select items with TAB and ENTER to confirm'
export FZF_DEFAULT_HEADER_WITH_SINGLE='(Single-select) Select item with ENTER to confirm'
export FZF_PREFIX_PROMPT='🔍'
export FZF_DEFAULT_BIND='ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
export FZF_COLOR_MOLOKAI='bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672'

# color=tomasr/molokai
export FZF_DEFAULT_OPTS="--color=\"$FZF_COLOR_MOLOKAI\" --ansi --cycle --border=rounded --prompt=\"$FZF_PREFIX_PROMPT\" --pointer=$POINTER --marker=$MARKER --header=\"$FZF_DEFAULT_HEADER_WITH_SINGLE\" --multi=0 --bind=\"$FZF_DEFAULT_BIND\""

fzf_multi() {
  fzf --header="$FZF_DEFAULT_HEADER_WITH_MULTI" --multi "$@"
}
