#!/usr/bin/env zsh

if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
elif [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
