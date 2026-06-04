# === Async PR cache (URL + state) ===
typeset -g _MURILASSO_PR_URL=""
typeset -g _MURILASSO_PR_STATE=""
typeset -g _MURILASSO_PR_BRANCH=""
typeset -g _MURILASSO_PR_REPO=""

_murilasso_read_pr_cache() {
  local cache_file="$1"
  { IFS= read -r _MURILASSO_PR_URL; IFS= read -r _MURILASSO_PR_STATE; } < "$cache_file"
}

_murilasso_refresh_pr() {
  local branch repo
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  repo=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -z "$branch" || "$branch" == "HEAD" || -z "$repo" ]]; then
    _MURILASSO_PR_URL=""
    _MURILASSO_PR_STATE=""
    _MURILASSO_PR_BRANCH=""
    _MURILASSO_PR_REPO=""
    return
  fi

  local cache_file="${TMPDIR:-/tmp}/.murilasso_pr_v2_${repo//\//_}_${branch//\//_}"

  if [[ "$branch" != "$_MURILASSO_PR_BRANCH" || "$repo" != "$_MURILASSO_PR_REPO" ]]; then
    _MURILASSO_PR_BRANCH="$branch"
    _MURILASSO_PR_REPO="$repo"
    _MURILASSO_PR_URL=""
    _MURILASSO_PR_STATE=""
    if [[ -f "$cache_file" ]]; then
      _murilasso_read_pr_cache "$cache_file"
    else
      (
        gh pr view --json url,state -q '.url + "\n" + .state' 2>/dev/null > "$cache_file"
      ) &!
    fi
  elif [[ -z "$_MURILASSO_PR_URL" && -f "$cache_file" ]]; then
    _murilasso_read_pr_cache "$cache_file"
  fi
}

(( ${precmd_functions[(Ie)_murilasso_refresh_pr]} )) || precmd_functions+=(_murilasso_refresh_pr)

# === Node.js version (RPS1) ===
typeset -g _MURILASSO_NODE_BIN=""
typeset -g _MURILASSO_NODE_SEG=""

_murilasso_refresh_node() {
  local node_bin
  node_bin=$(command -v node 2>/dev/null)

  if [[ -z "$node_bin" ]]; then
    _MURILASSO_NODE_BIN=""
    _MURILASSO_NODE_SEG=""
    return
  fi

  if [[ "$node_bin" != "$_MURILASSO_NODE_BIN" ]]; then
    _MURILASSO_NODE_BIN="$node_bin"
    local node_version
    node_version=$(node -v 2>/dev/null)
    _MURILASSO_NODE_SEG="%{$fg[green]%}⬡ ${node_version}%{$reset_color%}  "
  fi
}

(( ${precmd_functions[(Ie)_murilasso_refresh_node]} )) || precmd_functions+=(_murilasso_refresh_node)

# === Git info segment ===
_murilasso_git_segment() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -z "$branch" || "$branch" == "HEAD" ]] && return

  local dirty_marker
  if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
    dirty_marker="%{$fg[red]%}✗%{$reset_color%}"
  else
    dirty_marker="%{$fg[green]%}✔%{$reset_color%}"
  fi

  local pr_seg=""
  if [[ -n "$_MURILASSO_PR_URL" ]]; then
    local pr_number="${_MURILASSO_PR_URL##*/}"
    local osc8_open=$'\e]8;;'"${_MURILASSO_PR_URL}"$'\a'
    local osc8_close=$'\e]8;;\a'
    local pr_icon pr_color
    case "$_MURILASSO_PR_STATE" in
      OPEN)   pr_icon="○"  pr_color="$fg[green]" ;;
      MERGED) pr_icon="⊕"  pr_color="$fg[magenta]" ;;
      CLOSED) pr_icon="⊗"  pr_color="$fg[red]" ;;
      *)      pr_icon="⎇"  pr_color="$fg[yellow]" ;;
    esac
    pr_seg=" — %{${osc8_open}%}%{${pr_color}%}${pr_icon} #${pr_number}%{$reset_color%}%{${osc8_close}%}"
  fi

  print -P " — %{$terminfo[bold]$fg[blue]%}${branch}%{$reset_color%}${pr_seg} ${dirty_marker}"
}

# === Prompt ===
PROMPT='%{$terminfo[bold]$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$(_murilasso_git_segment)
%B$%b '
RPS1='${_MURILASSO_NODE_SEG}%(?..%{$fg[red]%}%? ↵%{$reset_color%})'

ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
