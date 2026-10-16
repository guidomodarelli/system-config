#!/usr/bin/env bash
# Uploads PR screenshots to the repository's orphan `pr-assets` branch through the GitHub API
# and prints one Markdown image line per file, ready for the PR body.
#
# Usage:
#   upload-pr-image.sh <owner/repo> <folder> <image-path> [<image-path>...]
#
# <folder> groups the images of one PR inside the branch; use the PR head branch name so the
# links exist before the PR does. Each file keeps its basename, so name captures by what they
# show (`before-dark.png`, `after-dark.png`). Uploading a name that already exists replaces it.
#
# The local checkout is never touched: no branch switch, no stash, no working-tree writes. Every
# commit message carries `[skip ci]` so branch-wide push workflows do not run on the asset branch.
# Images are served with the repository's own visibility (`blob/...?raw=true`), so a private
# repository keeps them private.
set -euo pipefail

readonly ASSET_BRANCH="pr-assets"
readonly SKIP_CI_MARKER="[skip ci]"
readonly ASSET_README="Imágenes de pull requests subidas por pr-description-template. No mergear esta rama."

if [[ $# -lt 3 ]]; then
  echo "upload-pr-image: usage: upload-pr-image.sh <owner/repo> <folder> <image-path>..." >&2
  exit 2
fi

repository="$1"
folder="${2//[^A-Za-z0-9._\/-]/-}"
shift 2

for image_path in "$@"; do
  if [[ ! -f "$image_path" ]]; then
    echo "upload-pr-image: image not found: $image_path" >&2
    exit 1
  fi
done

payload_file="$(mktemp)"
trap 'rm -f "$payload_file"' EXIT

# Creates the orphan asset branch with a single README commit when it does not exist yet.
ensure_asset_branch() {
  if gh api "repos/$repository/branches/$ASSET_BRANCH" --silent 2>/dev/null; then
    return
  fi
  local readme_blob tree_sha commit_sha
  readme_blob=$(jq -n --arg content "$ASSET_README" '{content: $content, encoding: "utf-8"}' |
    gh api "repos/$repository/git/blobs" --input - --jq .sha)
  tree_sha=$(jq -n --arg sha "$readme_blob" '{tree: [{path: "README.md", mode: "100644", type: "blob", sha: $sha}]}' |
    gh api "repos/$repository/git/trees" --input - --jq .sha)
  commit_sha=$(jq -n --arg tree "$tree_sha" --arg message "Create PR asset branch $SKIP_CI_MARKER" \
    '{message: $message, tree: $tree, parents: []}' |
    gh api "repos/$repository/git/commits" --input - --jq .sha)
  jq -n --arg sha "$commit_sha" --arg ref "refs/heads/$ASSET_BRANCH" '{ref: $ref, sha: $sha}' |
    gh api "repos/$repository/git/refs" --input - --silent
}

ensure_asset_branch

for image_path in "$@"; do
  file_name="$(basename "$image_path")"
  asset_path="$folder/$file_name"
  # On a 404 gh still prints the error body to stdout, so keep the output only when the call succeeds.
  existing_sha=$(gh api "repos/$repository/contents/$asset_path?ref=$ASSET_BRANCH" --jq .sha 2>/dev/null) || existing_sha=""
  {
    printf '{"message":"Add %s %s","branch":"%s","content":"' "$asset_path" "$SKIP_CI_MARKER" "$ASSET_BRANCH"
    base64 < "$image_path" | tr -d '\n'
    if [[ -n "$existing_sha" ]]; then
      printf '","sha":"%s"}' "$existing_sha"
    else
      printf '"}'
    fi
  } > "$payload_file"
  gh api -X PUT "repos/$repository/contents/$asset_path" --input "$payload_file" --silent
  printf '![%s](https://github.com/%s/blob/%s/%s?raw=true)\n' "${file_name%.*}" "$repository" "$ASSET_BRANCH" "$asset_path"
done
