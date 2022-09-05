ZSH_HOME=$HOME/.zsh
ZSH_THEME="intheloop"
ZSH="$HOME/.oh-my-zsh"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ ZSH configuration                                                            │
# └──────────────────────────────────────────────────────────────────────────────┘
# ------------------------------ zsh-completions ----------------------------- #
autoload -U compinit
compinit

source $ZSH/oh-my-zsh.sh
source $ZSH_HOME/init.zsh
