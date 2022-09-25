# Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOROOT="/usr/local/go"

# Java
export JAVA_HOME="$(dirname $(dirname $(readlink /etc/alternatives/java) 2>/dev/null) 2>/dev/null || echo 'Java not installed')"

paths=(
	$JAVA_HOME/bin
	$GOROOT/bin
	$GOBIN
	/usr/local/apache-maven-3.8.1/bin
	$HOME/.yarn/bin
	$HOME/.config/yarn/global/node_modules/.bin
	/home/linuxbrew/.linuxbrew/bin
)

newPath=$(echo ${paths[@]} | sed 's/ /:/g')
export PATH=$PATH:$newPath
