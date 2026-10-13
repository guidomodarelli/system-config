#!/bin/bash
# refresh-groot-ui-version.sh
# Looks up the latest published groot-ui version and stores it in a per-user
# cache file. SessionStart sync runs it in the background and passes the cached
# value to setup-groot-ui.sh, so the session never waits for the npm registry.
#
# Usage:
#   bash refresh-groot-ui-version.sh <cache-file>

set -euo pipefail

readonly GROOT_UI_PACKAGE_NAME="groot-ui"

if [[ $# -ne 1 || -z "$1" ]]; then
  printf 'ERROR: usage: %s <cache-file>\n' "$0" >&2
  exit 1
fi
cache_file="$1"

if [[ -L "$cache_file" || -L "${cache_file%/*}" ]]; then
  printf 'ERROR: %s or its directory is a symlink; groot-ui version cache was not updated.\n' "$cache_file" >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  printf 'ERROR: npm is required to look up the latest %s version.\n' "$GROOT_UI_PACKAGE_NAME" >&2
  exit 1
fi
if ! latest_version="$(npm view "$GROOT_UI_PACKAGE_NAME" version | tr -d '\r\n')" || [[ -z "$latest_version" ]]; then
  printf 'ERROR: could not look up the latest %s version.\n' "$GROOT_UI_PACKAGE_NAME" >&2
  exit 1
fi

mkdir -p -- "${cache_file%/*}"
temporary_cache="$(mktemp "${cache_file}.XXXXXX")"
printf '%s\n' "$latest_version" > "$temporary_cache"
mv -f -- "$temporary_cache" "$cache_file"
printf '[groot-ui] Cached latest %s version %s.\n' "$GROOT_UI_PACKAGE_NAME" "$latest_version"
