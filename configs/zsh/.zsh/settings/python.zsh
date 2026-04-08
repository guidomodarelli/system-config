# Initialize pyenv early so python3 resolves through pyenv shims.
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"

  latest_installed_python_version="$(pyenv versions --bare | sort -V | tail -1)"
  if [ -n "$latest_installed_python_version" ]; then
    export PYENV_VERSION="$latest_installed_python_version"
  fi
fi
