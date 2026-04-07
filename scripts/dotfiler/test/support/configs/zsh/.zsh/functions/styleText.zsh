#!/usr/bin/env bash

_last_arg() {
  printf '%s' "${@: -1}"
}

logCyan() {
  _last_arg "$@"
}

logGreen() {
  _last_arg "$@"
}

logYellow() {
  _last_arg "$@"
}

logBlue() {
  _last_arg "$@"
}

logInfo() {
  printf '%b' "$1"
}

logWarning() {
  printf '%b\n' "$1" >&2
}

logError() {
  printf '%b\n' "$1" >&2
}
