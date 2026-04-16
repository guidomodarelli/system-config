#!/bin/bash

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
DEFAULT_MANIFEST_PATH="$REPO_ROOT/configs/.codex/external-repos.yml"
MANIFEST_PATH="${CODEX_EXTERNAL_REPOS_MANIFEST:-$DEFAULT_MANIFEST_PATH}"
DRY_RUN=false
GIT_AUTOMATION_OPTIONS=(-c gc.auto=0 -c maintenance.auto=false)

print_usage() {
  cat <<'USAGE'
Uso: ./scripts/setup/codex-external-repos.sh {list|install|update} [repo] [--dry-run]
USAGE
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Missing required command '$command_name'." >&2
    exit 1
  fi
}

ensure_manifest_exists() {
  if [ ! -f "$MANIFEST_PATH" ]; then
    echo "ERROR: Manifest not found at $MANIFEST_PATH" >&2
    exit 1
  fi
}

expand_path() {
  local raw_path="$1"

  case "$raw_path" in
    "~")
      printf "%s\n" "$HOME"
      ;;
    "~/"*)
      printf "%s/%s\n" "$HOME" "${raw_path#"~/"}"
      ;;
    *)
      printf "%s\n" "$raw_path"
      ;;
  esac
}

run_or_echo() {
  if [ "$DRY_RUN" = "true" ]; then
    printf "[dry-run] %s\n" "$*"
    return 0
  fi

  "$@"
}

get_repo_names() {
  yq -r '.repos[].name' "$MANIFEST_PATH"
}

repo_exists_in_manifest() {
  local repository_name="$1"
  yq -e ".repos[] | select(.name == \"$repository_name\")" "$MANIFEST_PATH" >/dev/null 2>&1
}

get_repo_field() {
  local repository_name="$1"
  local field_name="$2"
  yq -r ".repos[] | select(.name == \"$repository_name\") | .$field_name // \"\"" "$MANIFEST_PATH"
}

ensure_selected_repo_exists() {
  local repository_name="$1"

  if ! repo_exists_in_manifest "$repository_name"; then
    echo "ERROR: Repository '$repository_name' is not defined in $MANIFEST_PATH" >&2
    exit 1
  fi
}

selected_repo_names() {
  local requested_repository="${1:-}"

  if [ -n "$requested_repository" ]; then
    ensure_selected_repo_exists "$requested_repository"
    printf "%s\n" "$requested_repository"
    return 0
  fi

  get_repo_names
}

ensure_parent_directory() {
  local path="$1"
  local parent_directory
  parent_directory="$(dirname "$path")"

  run_or_echo mkdir -p "$parent_directory"
}

ensure_skills_symlink() {
  local repository_name="$1"
  local symlink_target
  local symlink_source

  symlink_target="$(expand_path "$(get_repo_field "$repository_name" "skill_link_target")")"
  symlink_source="$(expand_path "$(get_repo_field "$repository_name" "skill_source")")"

  if [ -z "$symlink_target" ] || [ -z "$symlink_source" ]; then
    return 0
  fi

  ensure_parent_directory "$symlink_target"

  if [ -L "$symlink_target" ]; then
    local current_target
    current_target="$(readlink "$symlink_target")"

    if [ "$current_target" = "$symlink_source" ]; then
      echo "Symlink for $repository_name already points to $symlink_source"
      return 0
    fi

    run_or_echo rm "$symlink_target"
  elif [ -e "$symlink_target" ]; then
    echo "ERROR: Cannot replace non-symlink path at $symlink_target" >&2
    exit 1
  fi

  run_or_echo ln -s "$symlink_source" "$symlink_target"
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would ensure symlink for $repository_name at $symlink_target"
  else
    echo "Ensured symlink for $repository_name at $symlink_target"
  fi
}

clone_repository_if_missing() {
  local repository_name="$1"
  local repo_url
  local branch_name
  local clone_target

  repo_url="$(get_repo_field "$repository_name" "repo_url")"
  branch_name="$(get_repo_field "$repository_name" "branch")"
  clone_target="$(expand_path "$(get_repo_field "$repository_name" "clone_target")")"

  if [ -d "$clone_target/.git" ]; then
    echo "Repository $repository_name already exists at $clone_target"
    return 0
  fi

  ensure_parent_directory "$clone_target"
  run_or_echo git "${GIT_AUTOMATION_OPTIONS[@]}" clone --branch "$branch_name" --single-branch "$repo_url" "$clone_target"
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would install $repository_name into $clone_target"
  else
    echo "Installed $repository_name into $clone_target"
  fi
}

update_repository_if_present() {
  local repository_name="$1"
  local branch_name
  local clone_target

  branch_name="$(get_repo_field "$repository_name" "branch")"
  clone_target="$(expand_path "$(get_repo_field "$repository_name" "clone_target")")"

  if [ ! -d "$clone_target/.git" ]; then
    echo "Skipping $repository_name because clone is missing at $clone_target"
    return 0
  fi

  run_or_echo git "${GIT_AUTOMATION_OPTIONS[@]}" -C "$clone_target" pull --ff-only origin "$branch_name"
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would update $repository_name at $clone_target"
  else
    echo "Updated $repository_name at $clone_target"
  fi
}

print_activation_note_if_needed() {
  local repository_name="$1"
  local post_install

  post_install="$(get_repo_field "$repository_name" "post_install")"
  if [ "$post_install" = "manual_codex_activation" ]; then
    echo "Manual Codex activation may still be required for $repository_name."
  fi
}

list_repositories() {
  printf "NAME\tKIND\tBRANCH\tTARGET\tREPO\n"

  while IFS= read -r repository_name; do
    local kind
    local branch_name
    local clone_target
    local repo_url

    kind="$(get_repo_field "$repository_name" "kind")"
    branch_name="$(get_repo_field "$repository_name" "branch")"
    clone_target="$(get_repo_field "$repository_name" "clone_target")"
    repo_url="$(get_repo_field "$repository_name" "repo_url")"

    printf "%s\t%s\t%s\t%s\t%s\n" "$repository_name" "$kind" "$branch_name" "$clone_target" "$repo_url"
  done < <(selected_repo_names "${1:-}")
}

install_repositories() {
  while IFS= read -r repository_name; do
    clone_repository_if_missing "$repository_name"
    ensure_skills_symlink "$repository_name"
    print_activation_note_if_needed "$repository_name"
  done < <(selected_repo_names "${1:-}")
}

update_repositories() {
  while IFS= read -r repository_name; do
    update_repository_if_present "$repository_name"

    local clone_target
    clone_target="$(expand_path "$(get_repo_field "$repository_name" "clone_target")")"
    if [ -d "$clone_target/.git" ]; then
      ensure_skills_symlink "$repository_name"
    fi
  done < <(selected_repo_names "${1:-}")
}

COMMAND_NAME=""
REQUESTED_REPOSITORY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    list|install|update)
      if [ -n "$COMMAND_NAME" ]; then
        echo "ERROR: Command already set to '$COMMAND_NAME'." >&2
        exit 1
      fi
      COMMAND_NAME="$1"
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      if [ -n "$REQUESTED_REPOSITORY" ]; then
        echo "ERROR: Unexpected argument '$1'." >&2
        exit 1
      fi
      REQUESTED_REPOSITORY="$1"
      ;;
  esac
  shift
done

if [ -z "$COMMAND_NAME" ]; then
  print_usage
  exit 1
fi

require_command git
require_command yq
ensure_manifest_exists

if [ -n "$REQUESTED_REPOSITORY" ]; then
  ensure_selected_repo_exists "$REQUESTED_REPOSITORY"
fi

case "$COMMAND_NAME" in
  list)
    list_repositories "$REQUESTED_REPOSITORY"
    ;;
  install)
    install_repositories "$REQUESTED_REPOSITORY"
    ;;
  update)
    update_repositories "$REQUESTED_REPOSITORY"
    ;;
esac
