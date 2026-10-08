# anyframe 🖼️

## Synopsis ✨

anyframe is a zsh plugin that provides a convenient way to use [peco](https://github.com/peco/peco), [percol](https://github.com/mooz/percol), or [fzf](https://github.com/junegunn/fzf) for interactive filtering and selection in your zsh command line. It offers multiple useful widgets for tasks like branch selection, command history filtering, and process killing.

## How to set up 🛠️

First of all, you need to install [peco](https://github.com/peco/peco), [percol](https://github.com/mooz/percol), or [fzf](https://github.com/junegunn/fzf) (, or fzf-tmux)

### Manually install 📥

Put all files somewhere in your $fpath, and add the following lines to your .zshrc:

```
autoload -Uz anyframe-init
anyframe-init
```

#### For example

```
# download all files
% cd /path/to/dir
% git clone https://github.com/mollifier/anyframe
```

And add the following lines to your .zshrc:

```
fpath=(/path/to/dir/anyframe(N-/) $fpath)

autoload -Uz anyframe-init
anyframe-init
```

### Installing using package managers 📦

#### Using Antigen 📌
If you use [Antigen](https://github.com/zsh-users/antigen), add the following line to your .zshrc:

```
antigen bundle mollifier/anyframe
```

#### Using zinit ⚡
If you use [zinit](https://github.com/zdharma-continuum/zinit), add the following to your .zshrc:

```
zinit light mollifier/anyframe
```

#### Using zplug 🔌
If you use [zplug](https://github.com/zplug/zplug), add the following to your .zshrc:

```
zplug "mollifier/anyframe"
```

### Keybinding setup ⌨️

You can map anyframe widgets to whatever key you like.

For example, add the following lines to your .zshrc:

```
# Recent directories with cdr
bindkey '^xb' anyframe-widget-cdr
bindkey '^x^b' anyframe-widget-checkout-git-branch

# Command history
bindkey '^xr' anyframe-widget-execute-history
bindkey '^x^r' anyframe-widget-execute-history

# Put history item into command line
bindkey '^xi' anyframe-widget-put-history
bindkey '^x^i' anyframe-widget-put-history

# Navigate to ghq managed repos
bindkey '^xg' anyframe-widget-cd-ghq-repository
bindkey '^x^g' anyframe-widget-cd-ghq-repository

# Kill processes
bindkey '^xk' anyframe-widget-kill
bindkey '^x^k' anyframe-widget-kill

# Insert git branch name
bindkey '^xe' anyframe-widget-insert-git-branch
bindkey '^x^e' anyframe-widget-insert-git-branch
```

## Requirements 📋

Some widgets require external commands:

### anyframe-widget-cdr
Requires cdr functionality to be enabled in your zsh.

To use cdr, add the following line to your .zshrc:

```
autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs
```

For more information, see the REMEMBERING RECENT DIRECTORIES section in man zshcontrib(1).

### anyframe-widget-cd-ghq-repository
Requires [ghq](https://github.com/motemen/ghq) to be installed.

## Usage 📝

Once installed and configured, you can use the keybindings you've set up to access any of the anyframe widgets:

- 📂 `anyframe-widget-cdr`: Browse and jump to recently visited directories
- 🔄 `anyframe-widget-checkout-git-branch`: List and checkout git branches
- 📜 `anyframe-widget-execute-history`: Search and execute commands from your shell history
- 📋 `anyframe-widget-put-history`: Insert a command from history into your current command line
- 🗃️ `anyframe-widget-cd-ghq-repository`: Navigate to repositories managed by ghq
- 🔪 `anyframe-widget-kill`: Interactive process killing
- 🌿 `anyframe-widget-insert-git-branch`: Insert a git branch name into your command line

## Configurations ⚙️

You can customize which selector tool (peco, percol, fzf) is used:

```
# expressly specify to use peco
zstyle ":anyframe:selector:" use peco
# expressly specify to use percol
zstyle ":anyframe:selector:" use percol
# expressly specify to use fzf-tmux
zstyle ":anyframe:selector:" use fzf-tmux
# expressly specify to use fzf
zstyle ":anyframe:selector:" use fzf

# specify path and options for peco, percol, or fzf
zstyle ":anyframe:selector:peco:" command 'peco --no-ignore-case'
zstyle ":anyframe:selector:percol:" command 'percol --case-sensitive'
zstyle ":anyframe:selector:fzf-tmux:" command 'fzf-tmux --extended'
zstyle ":anyframe:selector:fzf:" command 'fzf --extended'
```

## Examples 🔍

### Example 1: Using history search 📜
Press `^xr` (Ctrl+x, r) to bring up a searchable list of your command history. Type to filter, then press Enter to execute the selected command.

### Example 2: Killing processes 🔪
Press `^xk` (Ctrl+x, k) to show a list of running processes. Select one or more processes to kill them.

### Example 3: Changing to a repository directory 📂
Press `^xg` (Ctrl+x, g) to see a list of repositories managed by ghq. Select one to change to that directory.

### Example 4: Checking out git branches 🌿
Press `^x^b` (Ctrl+x, Ctrl+b) to see a list of git branches, then select one to check it out.


