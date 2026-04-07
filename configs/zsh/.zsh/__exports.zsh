CURRENT_OS=$(uname)
# Ensure PATH entries are unique (automatically removes duplicates)
typeset -U PATH

# =============================================================================
# Shared (all platforms)
# =============================================================================

export PROGRAMS="$HOME/.local/lib"
export LOCAL_BINARIES="$HOME/.local/bin"

### Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOROOT="/usr/local/go"

### GPG
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

### Homebrew
export HOMEBREW_CURLRC=1

# =============================================================================
# Darwin (macOS)
# =============================================================================

if [[ "$CURRENT_OS" = "Darwin" ]]; then
  ### Python
  export PATH="$HOME/Library/Python/3.9/bin:$PATH"

  ### Homebrew
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/usr/local"
  fi

  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
  fi
fi

# =============================================================================
# Linux
# =============================================================================

if [[ "$CURRENT_OS" = "Linux" ]]; then
  ### GTK
  export GTK_PATH=:/usr/lib/gtk-2.0

  ### Android
  export ANDROID_HOME=$HOME/Android/Sdk

  ### Linuxbrew
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)"

  # ---------------------------------------------------------------------------
  # WSL (Windows Subsystem for Linux)
  # ---------------------------------------------------------------------------
  if grep -qi "microsoft" /proc/version 2>/dev/null; then
    # https://developer.hashicorp.com/vagrant/docs/other/wsl#windows-access
    export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
  fi
fi

# =============================================================================
# PATH
# =============================================================================

# In zsh, `path` (lowercase) is a special array tied to `PATH`.
# Modifying `path` automatically updates `PATH`.
# Combined with `typeset -U PATH` above, duplicates are removed automatically.
path+=(
  $LOCAL_BINARIES
  $HOME/.turso
  $PROGRAMS/gf
  $HOME/.local/bin/flutter/bin/
  $GOOGLE_CLOUD_HOME/bin
  $GOROOT/bin
  $GOBIN
  $HOME/.yarn/bin
  $HOME/.config/yarn/global/node_modules/.bin
)

if [[ "$CURRENT_OS" = "Linux" ]]; then
  path+=(
    /home/linuxbrew/.linuxbrew/bin
    /snap/bin
    $ANDROID_HOME/platform-tools
    $ANDROID_HOME/emulator
  )
fi
