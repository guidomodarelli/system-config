# Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOROOT="/usr/local/go"

# Java
export JAVA_HOME="$(dirname $(dirname $(readlink /etc/alternatives/java) 2> /dev/null) 2> /dev/null || echo 'Java not installed')"
