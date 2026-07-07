# Ensure es-wrapper (node/npx) is on PATH for ALL zsh invocations,
# including non-interactive shells that don't read ~/.zshrc — e.g. git hooks
# (husky/commitlint), editors and GUI tools that commit without sourcing the
# interactive shell config.
if [[ -d "$HOME/.es-wrapper/bin" && ":$PATH:" != *":$HOME/.es-wrapper/bin:"* ]]; then
  export PATH="$HOME/.es-wrapper/bin:$PATH"
fi
