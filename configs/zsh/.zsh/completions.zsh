ZSH_COMPLETION=$ZSH/completions

generate_completions() {
  local script_name="$1"
  local script_file="$2"
  local safe_script_name="${script_name//[^a-zA-Z0-9]/_}"
  local completions_file="$HOME/.zsh/completions/_${script_name}"

  cat << EOF > $completions_file
#compdef ${script_name}

_${safe_script_name}_completions() {
  local -a commands
  commands=(
EOF

  grep -oP '^\w+(?=\(\))' $script_file | while read -r cmd; do
    echo "    \"$cmd:$cmd\"" >> $completions_file
  done

  cat << EOF >> $completions_file
  )

  _describe 'command' commands
}

compdef _${safe_script_name}_completions ${script_name}
EOF
}

# Call the function to generate the completions file for setup.sh
generate_completions "setup.sh" "$HOME/system-config/scripts/setup/setup.sh"
generate_completions "setup.py" "$HOME/system-config/scripts/setup/setup.sh"

fpath=(/usr/local/share/zsh-completions $HOME/.zsh/completions $fpath)

zstyle :compinstall filename "${ZDOTDIR:-$HOME}/.zshrc"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

autoload -Uz compinit
compinit
_comp_options+=(globdots)

[ ! -f ~/fzf-tab/fzf-tab.plugin.zsh ] || source ~/fzf-tab/fzf-tab.plugin.zsh
