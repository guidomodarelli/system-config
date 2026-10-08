export SDKMAN_DIR="$HOME/.sdkman"

# Se omite `source sdkman-init.sh` (~500ms) + `sdk home java` (~130ms).
# JAVA_HOME se resuelve directamente desde el symlink `current` que SDKMAN mantiene
# actualizado, sin necesidad de ejecutar el init completo.
#
# Trade-off: el comando `sdk` no está disponible hasta su primer uso (lazy load).
# Costo: ~630ms pagados una sola vez por sesión la primera vez que se invoca `sdk`.
#
# Desventajas:
# - `sdk env` (auto-switch de versiones Java al hacer cd) no funciona hasta que
#   `sdk` esté cargado. Si usás ese feature, considerar volver al source directo.
# - Los completions de `sdk` no están disponibles hasta el primer uso.
# - Scripts que llamen funciones internas de sdkman al inicio fallarán silenciosamente.

() {
  local java_current="$SDKMAN_DIR/candidates/java/current"
  [[ -d "$java_current" ]] || return
  export JAVA_HOME="$java_current"
  path+=("$JAVA_HOME/bin")
}

# Lazy load: carga sdkman completo la primera vez que se invoca `sdk`
sdk() {
  unset -f sdk
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
  sdk "$@"
}
