LIB="/usr/lib"
export PROGRAMS="$HOME/.local/lib"
export LOCAL_BINARIES="$HOME/.local/bin"

# https://developer.hashicorp.com/vagrant/docs/other/wsl#windows-access
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"

### Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOROOT="/usr/local/go"

### Java
# Maven 3.6.0: https://archive.apache.org/dist/maven/maven-3/3.6.0/binaries/
# jdk11: https://adoptium.net/temurin/releases/?version=11&arch=x64&os=linux
if [[ $(uname) = "Darwin" ]]; then
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home/"
else
  # export JAVA_HOME="$(dirname $(dirname $(readlink /usr/bin/java) 2>/dev/null) 2>/dev/null || sdk home java $(sdk current java | awk '{print $4}' | grep "[0-9]") || echo 'JAVA_NOT_INSTALLED')"
fi

# GPG
export GPG_TTY=$(tty)

### pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

### Google Cloud
export GOOGLE_CLOUD_HOME="$PROGRAMS/google-cloud-sdk"
# The next line updates PATH for the Google Cloud SDK.
if [ -f "$GOOGLE_CLOUD_HOME/path.zsh.inc" ]; then . "$GOOGLE_CLOUD_HOME/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$GOOGLE_CLOUD_HOME/completion.zsh.inc" ]; then . "$GOOGLE_CLOUD_HOME/completion.zsh.inc"; fi

### HOMEBREW
export HOMEBREW_CURLRC=1
if [[ $(uname) = "Linux" ]]; then
	eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)"
fi

### GTK
export GTK_PATH=:$LIB/gtk-2.0

### Android
export ANDROID_HOME=$HOME/Android/Sdk

paths=(
	$LOCAL_BINARIES
  $HOME/.turso
	$PROGRAMS/gf
	$HOME/.local/bin/flutter/bin/
  $GOOGLE_CLOUD_HOME/bin
	$JAVA_HOME/bin
	$GOROOT/bin
	$GOBIN
	$HOME/.yarn/bin
	$HOME/.config/yarn/global/node_modules/.bin
	/home/linuxbrew/.linuxbrew/bin
	/snap/bin
	$ANDROID_HOME/platform-tools
	$ANDROID_HOME/emulator
)

export PATH=$PATH:$(echo ${paths[@]} | sed 's/ /:/g')
