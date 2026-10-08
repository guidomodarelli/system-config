# Make the nvm-managed Node.js toolchain available to ALL zsh invocations,
# including non-interactive shells that don't read ~/.zshrc — e.g. git hooks
# (husky/commitlint) and editors/GUI tools that commit without sourcing the
# interactive shell config. nvm is lazy-loaded in ~/.zshrc, so those shells
# would otherwise have no node/npx on PATH and hooks fail with
# "npx: command not found".
if [[ -d "$HOME/.nvm/versions/node" ]]; then
  # Prefer the version pointed to by the `default` alias (may be partial, e.g.
  # "v24"), resolving it to the highest matching installed version; otherwise
  # fall back to the highest installed version overall.
  _nvm_default="$(< "$HOME/.nvm/alias/default" 2>/dev/null)"
  _nvm_node_bin=""

  if [[ -n "$_nvm_default" ]]; then
    _nvm_node_bin=$(print -rl -- "$HOME"/.nvm/versions/node/${_nvm_default}*/bin(N) | sort -V | tail -1)
  fi

  if [[ -z "$_nvm_node_bin" ]]; then
    _nvm_node_bin=$(print -rl -- "$HOME"/.nvm/versions/node/*/bin(N) | sort -V | tail -1)
  fi

  if [[ -n "$_nvm_node_bin" && ":$PATH:" != *":$_nvm_node_bin:"* ]]; then
    export PATH="$_nvm_node_bin:$PATH"
  fi

  unset _nvm_default _nvm_node_bin
fi
