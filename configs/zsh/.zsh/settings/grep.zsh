# Agrega GNU grep (soporte pcre con -P) al PATH en macOS.
#
# Trade-off: se eliminó el test `echo | grep -P` que verificaba disponibilidad al inicio.
# El test spawneaba un subproceso en cada startup (~40ms) solo para mostrar un aviso.
# Desventaja: si GNU grep no está instalado, el error aparece recién al usar `grep -P`,
# no al abrir la terminal. Instalar con: brew install grep
#
# Desventaja: la ruta /usr/local/opt/grep corresponde a Homebrew en Intel Mac.
# En Apple Silicon la ruta correcta es /opt/homebrew/opt/grep/libexec/gnubin.
# Si grep -P no funciona en Apple Silicon, agregar esa ruta aquí.
if [[ $(uname) = "Darwin" ]]; then
  export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
fi
