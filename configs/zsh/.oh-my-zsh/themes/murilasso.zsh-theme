# === Async PR URL cache ===
typeset -g _MURILASSO_PR_URL=""
typeset -g _MURILASSO_PR_BRANCH=""

_murilasso_refresh_pr() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    _MURILASSO_PR_URL=""
    _MURILASSO_PR_BRANCH=""
    return
  fi

  local cache_file="${TMPDIR:-/tmp}/.murilasso_pr_url_${branch//\//_}"

  if [[ "$branch" != "$_MURILASSO_PR_BRANCH" ]]; then
    _MURILASSO_PR_BRANCH="$branch"
    _MURILASSO_PR_URL=""
    if [[ -f "$cache_file" ]]; then
      _MURILASSO_PR_URL=$(cat "$cache_file")
    else
      (
        local pr_url
        pr_url=$(gh pr view --json url -q '.url' 2>/dev/null)
        [[ -n "$pr_url" ]] && echo "$pr_url" > "$cache_file"
      ) &!
    fi
  elif [[ -z "$_MURILASSO_PR_URL" && -f "$cache_file" ]]; then
    _MURILASSO_PR_URL=$(cat "$cache_file")
  fi
}

(( ${precmd_functions[(Ie)_murilasso_refresh_pr]} )) || precmd_functions+=(_murilasso_refresh_pr)

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
    pr_seg=" — %{${osc8_open}%}%{$fg[yellow]%}PR #${pr_number}%{$reset_color%}%{${osc8_close}%}"
  fi

  print -P " — %{$terminfo[bold]$fg[blue]%}${branch}%{$reset_color%}${pr_seg} ${dirty_marker}"
}

# === Prompt ===
PROMPT='%{$terminfo[bold]$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$(_murilasso_git_segment)
%B$%b '
RPS1='%(?..%{$fg[red]%}%? ↵%{$reset_color%})'

ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
