# Chequear $OSTYPE primero: en macOS tocar /home despierta el automounter (~18ms).
if [[ "$OSTYPE" == linux* && -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  # Avoid calling `brew shellenv` on each startup; set the common paths directly
  export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
  export MANPATH="/home/linuxbrew/.linuxbrew/share/man:${MANPATH:-}"
  export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}"
fi
