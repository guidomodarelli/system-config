# === Async PR number cache ===
typeset -g _MURILASSO_PR_NUMBER=""
typeset -g _MURILASSO_PR_BRANCH=""

_murilasso_refresh_pr() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    _MURILASSO_PR_NUMBER=""
    _MURILASSO_PR_BRANCH=""
    return
  fi

  local cache_file="${TMPDIR:-/tmp}/.murilasso_pr_${branch//\//_}"

  if [[ "$branch" != "$_MURILASSO_PR_BRANCH" ]]; then
    _MURILASSO_PR_BRANCH="$branch"
    _MURILASSO_PR_NUMBER=""
    if [[ -f "$cache_file" ]]; then
      _MURILASSO_PR_NUMBER=$(cat "$cache_file")
    else
      (
        local pr_number
        pr_number=$(gh pr view --json number -q '.number' 2>/dev/null)
        [[ -n "$pr_number" ]] && echo "$pr_number" > "$cache_file"
      ) &!
    fi
  elif [[ -z "$_MURILASSO_PR_NUMBER" && -f "$cache_file" ]]; then
    _MURILASSO_PR_NUMBER=$(cat "$cache_file")
  fi
}

(( ${precmd_functions[(Ie)_murilasso_refresh_pr]} )) || precmd_functions+=(_murilasso_refresh_pr)

# === Git info segment ===
_murilasso_git_segment() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -z "$branch" || "$branch" == "HEAD" ]] && return

  local dirty
  dirty=$(parse_git_dirty)

  local pr_seg=""
  [[ -n "$_MURILASSO_PR_NUMBER" ]] && \
    pr_seg=" — %{$fg[yellow]%}PR #${_MURILASSO_PR_NUMBER}%{$reset_color%}"

  print -P " — %{$terminfo[bold]$fg[blue]%}${branch}%{$reset_color%}${pr_seg}${dirty}"
}

# === Prompt ===
PROMPT='%{$terminfo[bold]$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$(_murilasso_git_segment) %B$%b '
RPS1='%(?..%{$fg[red]%}%? ↵%{$reset_color%})'

ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
