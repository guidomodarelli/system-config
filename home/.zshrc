ZSH_HOME=$HOME/.zsh
ZSH_THEME="intheloop"
ZSH=$HOME/.oh-my-zsh

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ ZSH configuration                                                            │
# └──────────────────────────────────────────────────────────────────────────────┘
# ------------------------------ zsh-completions ----------------------------- #
autoload -Uz compinit
compinit
_comp_options+=(globdots)

source $HOME/.antigenrc
source $ZSH/oh-my-zsh.sh
source $ZSH_HOME/init.zsh
