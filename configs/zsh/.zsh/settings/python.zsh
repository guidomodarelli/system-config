export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# Se omite `eval "$(pyenv init - zsh)"` (~700ms) — los shims ya están en PATH.
#
# Trade-off: pyenv no ejecuta `rehash` automáticamente al instalar paquetes con pip.
# Sin rehash, los nuevos binarios instalados (ej. `black`, `ruff`) no aparecen en PATH
# hasta correr `pyenv rehash` manualmente.
#
# Solución: los wrappers de pip/pip3/pipx corren `pyenv rehash` automáticamente
# después de install/uninstall/upgrade, replicando el comportamiento de pyenv init.
#
# Desventaja residual: si instalás binarios Python por fuera de pip (ej. compilando
# manualmente), seguís necesitando `pyenv rehash` a mano.
#
# También se elimina `pyenv versions --bare` (~200ms) que seteaba PYENV_VERSION al
# latest instalado, lo cual sobreescribía archivos .python-version en proyectos.
# pyenv resuelve la versión correctamente sin esa variable: PYENV_VERSION >
# .python-version > pyenv global.

_pyenv_auto_rehash() {
  local bin="$1"; shift
  command "$bin" "$@"
  local exit_code=$?
  case "$1" in
    install|uninstall|upgrade)
      pyenv rehash 2>/dev/null
      ;;
  esac
  return $exit_code
}

function pip  { _pyenv_auto_rehash pip  "$@"; }
function pip3 { _pyenv_auto_rehash pip3 "$@"; }
function pipx { _pyenv_auto_rehash pipx "$@"; }
