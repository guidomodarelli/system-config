# ███████╗██╗  ██╗██████╗  ██████╗ ██████╗ ████████╗███████╗
# ██╔════╝╚██╗██╔╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝
# █████╗   ╚███╔╝ ██████╔╝██║   ██║██████╔╝   ██║   ███████╗
# ██╔══╝   ██╔██╗ ██╔═══╝ ██║   ██║██╔══██╗   ██║   ╚════██║
# ███████╗██╔╝ ██╗██║     ╚██████╔╝██║  ██║   ██║   ███████║
# ╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝

USR=/usr
LOCAL=$USR/local
LIB=$USR/lib

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ VARIABLES                                                                    │
# └──────────────────────────────────────────────────────────────────────────────┘
export DENO_INSTALL="/home/guido/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# ----------------------------- Path to oh-my-zsh ---------------------------- #
export ZSH="$HOME/.oh-my-zsh"

# -------------------------------- Path to GO -------------------------------- #
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export GOROOT=$LOCAL/go

# ----------------------------- Path to JAVA_HOME ---------------------------- #
export JAVA_HOME=$(dirname $(dirname $(readlink /etc/alternatives/java)))

# -------------------------------- Path to NVM ------------------------------- #
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] \
  && printf %s "${HOME}/.nvm" \
  || printf %s "${XDG_CONFIG_HOME}/nvm")"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ ADD TO PATH                                                                  │
# └──────────────────────────────────────────────────────────────────────────────┘
paths=(
	$LOCAL/apache-maven-3.8.1/bin
	$LOCAL/bin/install/server/bin
	$JAVA_HOME/bin
	$GOROOT/bin
	$GOBIN
	$HOME/eclipse-workspaces/equo-sdk-master/eclipse
)

newPath=$(echo ${paths[@]} | sed 's/ /:/g')
export PATH=$PATH:$newPath

# ---------------------------------------------------------------------------- #


#  ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
# ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
# ██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
# ██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
# ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
#  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ ZSH configuration                                                            │
# └──────────────────────────────────────────────────────────────────────────────┘
# ------------------------------ zsh-completions ----------------------------- #
autoload -U compinit 

compinit

# ------------------------------- ZSH vaiables ------------------------------- #
ZSH_CUSTOM=$HOME/dotfiles
ZSH_THEME="intheloop"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Source files                                                                 │
# └──────────────────────────────────────────────────────────────────────────────┘
source ~/.antigenrc
source $ZSH_CUSTOM/aliases.zsh
source $ZSH/oh-my-zsh.sh

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Completions                                                                  │
# └──────────────────────────────────────────────────────────────────────────────┘
source $ZSH/completions/et.zsh
source $ZSH/completions/kubectl.zsh

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
fpath=(/usr/local/share/zsh-completions $fpath)

# -------------------------------- Equo files -------------------------------- #
ZSH_EQUO=$ZSH_CUSTOM/equo

source $ZSH_EQUO/functions.zsh

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Plugins                                                                      │
# └──────────────────────────────────────────────────────────────────────────────┘
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(
	git
	docker
	docker-compose
	node
	npm
	gradle
	nvm
	fd
)

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ User configuration                                                           │
# └──────────────────────────────────────────────────────────────────────────────┘

# -------------------------- anyframe configuration -------------------------- #
bindkey '^b' anyframe-widget-checkout-git-branch

bindkey '^r' anyframe-widget-execute-history

bindkey '^g' anyframe-widget-cd-ghq-repository

bindkey '^k' anyframe-widget-kill

zstyle ":anyframe:selector:" use fzf

# ------------------------------- This load nvm ------------------------------ #
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

eval "$(zoxide init zsh)"

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/guido/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/home/guido/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/guido/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/guido/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
