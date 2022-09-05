source "$ZSH_HOME/exports.zsh"

paths=(
	$JAVA_HOME/bin
	$GOROOT/bin
	$GOBIN
	"/usr/local/apache-maven-3.8.1/bin"
	$HOME/.yarn/bin
	$HOME/.config/yarn/global/node_modules/.bin
	/home/linuxbrew/.linuxbrew/bin
)

newPath=$(echo ${paths[@]} | sed 's/ /:/g')
export PATH=$PATH:$newPath
