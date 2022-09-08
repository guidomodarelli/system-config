source "$ZSH_HOME/exports.zsh"

paths=(
	/usr/local/apache-maven-3.8.1/bin
	$HOME/.yarn/bin
	$HOME/.config/yarn/global/node_modules/.bin
	/home/linuxbrew/.linuxbrew/bin
)

if command -v java &> /dev/null; then
	paths+=($JAVA_HOME/bin)
fi

if command -v go &> /dev/null; then
	paths+=(
		$GOROOT/bin
		$GOBIN
	)
fi

newPath=$(echo ${paths[@]} | sed 's/ /:/g')
export PATH=$PATH:$newPath
