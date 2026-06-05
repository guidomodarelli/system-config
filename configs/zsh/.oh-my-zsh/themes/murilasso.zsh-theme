# === Async PR cache (URL + state) ===
typeset -g _MURILASSO_PR_URL=""
typeset -g _MURILASSO_PR_STATE=""
typeset -g _MURILASSO_PR_BRANCH=""
typeset -g _MURILASSO_PR_REPO=""
typeset -g _MURILASSO_PR_LAST_FETCH=-999

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
    _MURILASSO_PR_LAST_FETCH=-999
    return
  fi

  local cache_file="${TMPDIR:-/tmp}/.murilasso_pr_v2_${repo//\//_}_${branch//\//_}"

  if [[ "$branch" != "$_MURILASSO_PR_BRANCH" || "$repo" != "$_MURILASSO_PR_REPO" ]]; then
    _MURILASSO_PR_BRANCH="$branch"
    _MURILASSO_PR_REPO="$repo"
    _MURILASSO_PR_URL=""
    _MURILASSO_PR_STATE=""
    _MURILASSO_PR_LAST_FETCH=$SECONDS
    # Muestra cache inmediatamente si existe, y siempre lanza fetch en bg para actualizar
    [[ -f "$cache_file" ]] && _murilasso_read_pr_cache "$cache_file"
    (gh pr view --json url,state -q '.url + "\n" + .state' 2>/dev/null > "$cache_file") &!
  elif [[ -z "$_MURILASSO_PR_URL" && -f "$cache_file" ]]; then
    # El fetch en background terminó — leer el resultado
    _murilasso_read_pr_cache "$cache_file"
    _MURILASSO_PR_LAST_FETCH=$SECONDS
  elif [[ "$_MURILASSO_PR_STATE" == "OPEN" ]]; then
    # Re-leer cache en cada precmd (~1ms) para detectar merges/closes
    [[ -f "$cache_file" ]] && _murilasso_read_pr_cache "$cache_file"
    # Re-fetchear en background cada 30 segundos
    if (( SECONDS - _MURILASSO_PR_LAST_FETCH > 30 )); then
      _MURILASSO_PR_LAST_FETCH=$SECONDS
      (gh pr view --json url,state -q '.url + "\n" + .state' 2>/dev/null > "$cache_file") &!
    fi
  fi
}

(( ${precmd_functions[(Ie)_murilasso_refresh_pr]} )) || precmd_functions+=(_murilasso_refresh_pr)

# === Async CI status (refresca cada 2 minutos via $SECONDS builtin) ===
typeset -g _MURILASSO_PR_CI=""
typeset -g _MURILASSO_CI_LAST_FETCH=-999
typeset -g _MURILASSO_CI_LAST_KEY=""

_murilasso_refresh_ci() {
  [[ -z "$_MURILASSO_PR_URL" ]] && { _MURILASSO_PR_CI=""; return; }

  local key="${_MURILASSO_PR_REPO}:${_MURILASSO_PR_BRANCH}"
  local ci_cache="${TMPDIR:-/tmp}/.murilasso_ci_${_MURILASSO_PR_REPO//\//_}_${_MURILASSO_PR_BRANCH//\//_}"

  # Refresca si: cambió de branch/repo O pasaron más de 2 minutos
  if [[ "$key" != "$_MURILASSO_CI_LAST_KEY" ]] || (( SECONDS - _MURILASSO_CI_LAST_FETCH > 120 )); then
    _MURILASSO_CI_LAST_KEY="$key"
    _MURILASSO_CI_LAST_FETCH=$SECONDS
    (
      gh pr view --json statusCheckRollup -q '
        if (.statusCheckRollup // [] | length) == 0 then ""
        elif .statusCheckRollup | any(
          .conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or
          .state == "FAILURE" or .state == "ERROR"
        ) then "FAILURE"
        elif .statusCheckRollup | any(
          .status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or
          .state == "PENDING"
        ) then "PENDING"
        else "SUCCESS"
        end' 2>/dev/null > "$ci_cache"
    ) &!
  fi

  [[ -f "$ci_cache" ]] && IFS= read -r _MURILASSO_PR_CI < "$ci_cache"
}

(( ${precmd_functions[(Ie)_murilasso_refresh_ci]} )) || precmd_functions+=(_murilasso_refresh_ci)

# === Node.js version (RPS1) ===
typeset -g _MURILASSO_NODE_BIN=""
typeset -g _MURILASSO_NODE_VERSION=""
typeset -g _MURILASSO_NODE_SEG=""

_murilasso_refresh_node() {
  # NVM_BIN cambia inmediatamente con `nvm use`; fallback a whence para setups sin NVM
  local node_bin="${NVM_BIN:+${NVM_BIN}/node}"
  [[ -z "$node_bin" ]] && node_bin=$(whence -p node 2>/dev/null)

  if [[ -z "$node_bin" ]]; then
    _MURILASSO_NODE_BIN=""
    _MURILASSO_NODE_VERSION=""
    _MURILASSO_NODE_SEG=""
    return
  fi

  # Solo llama node -v cuando cambia el binario (ej. nvm use)
  if [[ "$node_bin" != "$_MURILASSO_NODE_BIN" ]]; then
    _MURILASSO_NODE_BIN="$node_bin"
    _MURILASSO_NODE_VERSION=$(node -v 2>/dev/null)
  fi

  # Busca .nvmrc subiendo desde PWD
  local nvmrc_path="" dir="$PWD"
  while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
    [[ -f "$dir/.nvmrc" ]] && { nvmrc_path="$dir/.nvmrc"; break; }
    dir="${dir:h}"
  done

  local version_seg="%{$fg[green]%}⬡ ${_MURILASSO_NODE_VERSION}%{$reset_color%}"

  if [[ -n "$nvmrc_path" ]]; then
    local nvmrc_ver running_ver
    nvmrc_ver=$(< "$nvmrc_path")
    nvmrc_ver="${${nvmrc_ver// /}#v}"
    running_ver="${_MURILASSO_NODE_VERSION#v}"
    if [[ "$running_ver" != "$nvmrc_ver"* ]]; then
      version_seg="${version_seg} %{$fg[yellow]%}≠ v${nvmrc_ver} .nvmrc%{$reset_color%}"
    fi
  fi

  _MURILASSO_NODE_SEG="${version_seg}  "
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

  local display_branch="$branch"
  (( ${#branch} > 40 )) && display_branch="${branch[1,39]}…"

  local branch_color="$terminfo[bold]$fg[blue]"
  local upstream_track
  upstream_track=$(git for-each-ref --format='%(upstream:track)' "refs/heads/${branch}" 2>/dev/null)
  [[ "$upstream_track" == *"gone"* ]] && branch_color="$terminfo[bold]$fg[red]"

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

    local ci_marker
    case "$_MURILASSO_PR_CI" in
      SUCCESS) ci_marker=" %{$fg[green]%}✔%{$reset_color%}" ;;
      FAILURE) ci_marker=" %{$fg[red]%}✗%{$reset_color%}" ;;
      PENDING) ci_marker=" %{$fg[yellow]%}●%{$reset_color%}" ;;
      *)       ci_marker=" %{$fg[white]%}◦%{$reset_color%}" ;;
    esac

    pr_seg=" — %{${osc8_open}%}%{${pr_color}%}${pr_icon} #${pr_number}%{$reset_color%}%{${osc8_close}%}${ci_marker}"
  fi

  print -P " — %{${branch_color}%}${display_branch}%{$reset_color%} ${dirty_marker}${pr_seg}"
}

# === Prompt ===
PROMPT='%{$terminfo[bold]$fg[green]%}%n%{$reset_color%}:%{$fg[blue]%}%3~%{$reset_color%}$(_murilasso_git_segment)
%B$%b '
RPS1='${_MURILASSO_NODE_SEG}%(?..%{$fg[red]%}%? ↵%{$reset_color%})'

ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
