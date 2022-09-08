# Go
if command -v go &> /dev/null; then
	export GOPATH="$HOME/go"
	export GOBIN="$GOPATH/bin"
	export GOROOT="/usr/local/go"
fi

# Java
if command -v java &> /dev/null; then
	export JAVA_HOME="$(dirname $(dirname $(readlink /etc/alternatives/java) 2> /dev/null) 2> /dev/null || echo 'Java not installed')"
fi
