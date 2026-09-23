# Solo se agrega si existe: una ruta inexistente bajo /home en macOS despierta el
# automounter cada vez que zsh recorre $PATH (~18ms por lookup de comando nuevo).
if [[ -d "$HOME/.opencode/bin" ]]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi
