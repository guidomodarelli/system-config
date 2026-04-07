# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"

if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  source "$SDKMAN_DIR/bin/sdkman-init.sh"

  if command -v sdk >/dev/null 2>&1; then
    sdk_java_home="$(sdk home java 2>/dev/null || true)"

    if [[ -n "$sdk_java_home" && -d "$sdk_java_home" ]]; then
      export JAVA_HOME="$sdk_java_home"
      path+=("$JAVA_HOME/bin")
    fi

    unset sdk_java_home
  fi
fi
