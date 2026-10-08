# PowerShell configuration

## ghq integration

This profile exposes the same ghq shortcuts available in the zsh setup:

- `Ctrl+x, Ctrl+g` jumps to any ghq repository (filters out `work/` by default).
- `Ctrl+x, Ctrl+w` focuses on `work/` repositories and ignores `forks/`.
- `Ctrl+x, Ctrl+p` targets `projects/` repositories.

### Requirements

1. Install ghq and ensure it is on `PATH`. On Windows with Scoop:
   ```powershell
   scoop install ghq
   ```
2. Install `fzf` so the interactive picker works (e.g. `scoop install fzf`).
3. Reload the profile (open a new PowerShell session or run `.$PROFILE`).

### Manual commands

If you prefer commands instead of key chords, the profile also adds:

- `Invoke-GhqRepositoryGlobal`
- `Invoke-GhqRepositoryWork`
- `Invoke-GhqRepositoryProjects`

Each command opens the same picker and changes the current directory to the selected repository.
