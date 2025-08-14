fif() {
    if [ ! "$#" -gt 0 ]; then
    logWarn "Need a string to search for!"
    return 1
  fi

  local search_pattern="$1"

  # Search with ripgrep and process with fzf
  rg --ignore-case --multiline --vimgrep --no-messages "$search_pattern" 2>/dev/null |
    cut -d: -f-2 |
    fzf \
      --exit-0 \
      --border \
      --prompt "Find files> " \
      --color "hl:-1:underline,hl+:-1:underline:reverse" \
      --delimiter : \
      --preview "rg --ignore-case --multiline --passthru --pretty '$search_pattern' {1}" \
      --preview-window "60%,wrap,+{2}" \
      --bind "enter:become(code -g {1}:{2})" \
      --bind "ctrl-c:abort"
}

