# ██████  ███████ ███████  █████  ██    ██ ██      ████████ ███████
# ██   ██ ██      ██      ██   ██ ██    ██ ██         ██    ██
# ██   ██ █████   █████   ███████ ██    ██ ██         ██    ███████
# ██   ██ ██      ██      ██   ██ ██    ██ ██         ██         ██
# ██████  ███████ ██      ██   ██  ██████  ███████    ██    ███████

# Grep with color and exclusions
function global:grep { & grep.exe --color=auto --exclude-dir=".bzr" --exclude-dir="CVS" --exclude-dir=".git" --exclude-dir=".hg" --exclude-dir=".svn" --exclude-dir=".idea" --exclude-dir=".tox" --exclude-dir=".venv" --exclude-dir="venv" $args }
function rg { & rg.exe --glob "!.git/*" $args }

# --- Codex unified (replica de lógica Zsh) ------------------------------------

# Returns the built-in prompt used by `cx --commit`.
function Get-CxCommitPrompt {
    $configsDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $promptFile = Join-Path $configsDir '.codex/commit_prompt.txt'

    if (-not (Test-Path -LiteralPath $promptFile)) {
        throw "Commit prompt file not found: $promptFile"
    }

    return (Get-Content -LiteralPath $promptFile -Raw)
}

# Returns `-c` overrides to disable all configured MCP servers for the current run.
function Get-CxDisableMcpConfigArgs {
    $disableArgs = New-Object System.Collections.Generic.List[string]
    $mcpListOutput = & codex mcp list 2>$null

    if (-not $mcpListOutput) {
        return @()
    }

    $serverNames = New-Object System.Collections.Generic.List[string]

    foreach ($line in $mcpListOutput) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*Name\s+') { continue }

        $tokens = ($line -split '\s+') | Where-Object { $_ -ne '' }
        if ($tokens.Count -gt 0) {
            $serverNames.Add($tokens[0])
        }
    }

    foreach ($serverName in ($serverNames | Select-Object -Unique)) {
        $disableArgs.Add('-c')
        $disableArgs.Add("mcp_servers.$serverName.enabled=false")
    }

    return $disableArgs.ToArray()
}

# Unified implementation: cx handles both safe and yolo modes.
function cx {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Args
    )

    if ($Args.Count -gt 0 -and $Args[0] -eq 'update') {
        brew upgrade codex
        return
    }

    $model = 'gpt-5.3-codex'
    $reasoning = 'medium'
    $yolo = $false
    $commitMode = $false
    $rest = New-Object System.Collections.Generic.List[string]
    $mcpConfigArgs = @()

    for ($i = 0; $i -lt $Args.Count; $i++) {
        switch ($Args[$i]) {
            '-m' {
                if ($i + 1 -lt $Args.Count) {
                    $model = $Args[$i + 1]
                    $i++
                }
            }
            '-re' {
                if ($i + 1 -lt $Args.Count) {
                    $reasoning = $Args[$i + 1]
                    $i++
                }
            }
            '-c' { $commitMode = $true }
            '--commit' { $commitMode = $true }
            '--yolo' {
                $yolo = $true
            }
            '--' {
                if ($i + 1 -lt $Args.Count) {
                    for ($j = $i + 1; $j -lt $Args.Count; $j++) {
                        $rest.Add($Args[$j])
                    }
                }
                break
            }
            default {
                $rest.Add($Args[$i])
            }
        }
    }

    if ($commitMode) {
        # `--commit` has priority over any user-provided query tokens.
        $yolo = $true
        $rest.Clear()
        $rest.Add((Get-CxCommitPrompt))
        $mcpConfigArgs = Get-CxDisableMcpConfigArgs
    }

    $cmd = @('codex','-m', $model,'-c',"model_reasoning_effort=$reasoning")
    if ($mcpConfigArgs.Count -gt 0) {
        $cmd += $mcpConfigArgs
    }
    if ($yolo) {
        $cmd += '--yolo'
    } else {
        $cmd += @('--sandbox','workspace-write','--ask-for-approval','on-failure')
    }
    $cmd += '--search'
    $cmd += $rest.ToArray()

    Write-Host "Running: $($cmd -join ' ')"

    & $cmd[0] $cmd[1..($cmd.Count-1)]
}

# Dangerous alias for codex (bypass approvals & sandbox)
function cxd {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Args
    )
    cx --yolo @Args
}

# --- Fin Codex unified -------------------------------------------------------

#  ██████  ██ ████████
# ██       ██    ██
# ██   ███ ██    ██
# ██    ██ ██    ██
#  ██████  ██    ██

# Git aliases for PowerShell

# Helper functions for Git commands that need branch names
function git_current_branch {
    $branch = git symbolic-ref --short HEAD 2> $null
    if (-not [string]::IsNullOrWhiteSpace($branch)) {
        return $branch.Trim()
    }

    $detachedHead = git rev-parse --short HEAD 2> $null
    if (-not [string]::IsNullOrWhiteSpace($detachedHead)) {
        return $detachedHead.Trim()
    }

    return $null
}

function git_main_branch {
    $branches = git branch --list master main 2> $null
    if ($branches -match "master") { return "master" }
    if ($branches -match "main") { return "main" }
    return "main"
}

function git_develop_branch {
    $branches = git branch --list dev develop development 2> $null
    if ($branches -match "develop") { return "develop" }
    if ($branches -match "dev") { return "dev" }
    if ($branches -match "development") { return "development" }
    return "develop"
}

# Simple aliases
Set-Alias -Name g -Value git
Set-Alias -Name gk -Value gitk

# Git command functions
function ga { git add $args }
function gaa { git add --all $args }
function gam { git am $args }
function gama { git am --abort $args }
function gamc { git am --continue $args }
function gams { git am --skip $args }
function gamscp { git am --show-current-patch $args }
function gap { git apply $args }
function gapa { git add --patch $args }
function gapt { git apply --3way $args }
function gau { git add --update $args }
function gav { git add --verbose $args }
function gb { git branch $args }
function gbD { git branch --delete --force $args }
function gba { git branch --all $args }
function gbd { git branch --delete $args }
function gbg {
    $previousLang = $env:LANG
    try {
        $env:LANG = 'C'
        git branch -vv | Select-String ": gone\]"
    } finally {
        $env:LANG = $previousLang
    }
}
function gbgD {
    $previousLang = $env:LANG
    try {
        $env:LANG = 'C'
        git branch --no-color -vv | Select-String ": gone\]" | ForEach-Object {
            git branch -D ($_.ToString() -replace "^.*?(\S+).*$", '$1')
        }
    } finally {
        $env:LANG = $previousLang
    }
}
function gbgd {
    $previousLang = $env:LANG
    try {
        $env:LANG = 'C'
        git branch --no-color -vv | Select-String ": gone\]" | ForEach-Object {
            git branch -d ($_.ToString() -replace "^.*?(\S+).*$", '$1')
        }
    } finally {
        $env:LANG = $previousLang
    }
}
function gbl { git blame -w $args }
function gbm { git branch --move $args }
function gbnm { git branch --no-merged $args }
function gbr { git branch --remote $args }
function gbs { git bisect $args }
function gbsb { git bisect bad $args }
function gbsg { git bisect good $args }
function gbsn { git bisect new $args }
function gbso { git bisect old $args }
function gbsr { git bisect reset $args }
function gbss { git bisect start $args }
function gc { git commit --verbose $args }
function gc! { git commit --verbose --amend $args }
function gcB { git checkout -B $args }
function gca { git commit --verbose --all $args }
function gca! { git commit --verbose --all --amend $args }
function gcam { git commit --all --message $args }
function gcan! { git commit --verbose --all --no-edit --amend $args }
function gcann! { git commit --verbose --all --date=now --no-edit --amend $args }
function gcans! { git commit --verbose --all --signoff --no-edit --amend $args }
function gcas { git commit --all --signoff $args }
function gcasm { git commit --all --signoff --message $args }
function gcb { git checkout -b $args }
function gcd { git checkout $(git_develop_branch) $args }
function gcf { git config --list $args }
function gcl { git clone --recurse-submodules $args }
function gclean { git clean --interactive -d $args }
function gclf { git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules $args }
function gcm { git checkout $(git_main_branch) $args }
function gcmsg { git commit --message $args }
function gcn { git commit --verbose --no-edit $args }
function gcn! { git commit --verbose --no-edit --amend $args }
function gco { git checkout $args }
function gcor { git checkout --recurse-submodules $args }
function gcount { git shortlog --summary --numbered $args }
function gcp { git cherry-pick $args }
function gcpa { git cherry-pick --abort $args }
function gcpc { git cherry-pick --continue $args }
function gcs { git commit --gpg-sign $args }
function gcsm { git commit --signoff --message $args }
function gcss { git commit --gpg-sign --signoff $args }
function gcssm { git commit --gpg-sign --signoff --message $args }
function gd { git diff $args }
function gdca { git diff --cached $args }
function gdct { git describe --tags $(git rev-list --tags --max-count=1) $args }
function gdcw { git diff --cached --word-diff $args }
function gds { git diff --staged $args }
function gdt { git diff-tree --no-commit-id --name-only -r $args }
function gdup { git diff "@{upstream}" }
function gdw { git diff --word-diff $args }
function gf { git fetch $args }
function gfa { git fetch --all --tags --prune --jobs=10 $args }
function gfg { git ls-files | Select-String $args }
function gfo { git fetch origin $args }
function gfp { git fetch --force --prune --prune-tags --tags --jobs=8 $args }
function ggui { git gui citool $args }
function gga { git gui citool --amend $args }
function ggpull { git pull origin "$(git_current_branch)" }
function ggpush { git push origin "$(git_current_branch)" }
function ggsup { git branch --set-upstream-to=origin/$(git_current_branch) $args }
function ghh { git help $args }
function gignore { git update-index --assume-unchanged $args }
function gignored { git ls-files -v | Select-String "^[[:lower:]]" $args }
function gll { git pull $args }
function glg { git log --stat $args }
function glgg { git log --graph $args }
function glgga { git log --graph --decorate --all $args }
function glgm { git log --graph --max-count=10 $args }
function glgp { git log --stat --patch $args }
function glo { git log --oneline --decorate $args }
function glod { git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" $args }
function glods { git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short $args }
function glog { git log --oneline --decorate --graph $args }
function gloga { git log --oneline --decorate --graph --all $args }
function glol { git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" $args }
function glola { git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all $args }
function glols { git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat $args }
function glp { _git_log_prettily $args }
function gluc { git pull upstream $(git_current_branch) $args }
function glum { git pull upstream $(git_main_branch) $args }
function gm { git merge $args }
function gma { git merge --abort $args }
function gmc { git merge --continue $args }
function gmff { git merge --ff-only $args }
function gmom { git merge origin/$(git_main_branch) $args }
function gms { git merge --squash $args }
function gmtl { git mergetool --no-prompt $args }
function gmtlvim { git mergetool --no-prompt --tool=vimdiff $args }
function gmum { git merge upstream/$(git_main_branch) $args }
function gp { git push $args }
function gpd { git push --dry-run $args }
function gpf { git push --force-with-lease --force-if-includes $args }
function gpf! { git push --force $args }
function gpoat {
    git push origin --all
    if ($LASTEXITCODE -eq 0) {
        git push origin --tags $args
    }
}
function gpod { git push origin --delete $args }
function gpr { git pull --rebase $args }
function gpra { git pull --rebase --autostash $args }
function gprav { git pull --rebase --autostash -v $args }
function gpristine {
    git reset --hard
    if ($LASTEXITCODE -eq 0) {
        git clean --force -dfx $args
    }
}
function gprom { git pull --rebase origin $(git_main_branch) $args }
function gpromi { git pull --rebase=interactive origin $(git_main_branch) $args }
function gprum { git pull --rebase upstream $(git_main_branch) $args }
function gprumi { git pull --rebase=interactive upstream $(git_main_branch) $args }
function gprv { git pull --rebase -v $args }
function gpsup { git push --set-upstream origin $(git_current_branch) $args }
function gpsupf { git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes $args }
function gpu { git push upstream $args }
function gpv { git push --verbose $args }
function gr { git remote $args }
function gra { git remote add $args }
function grb { git rebase $args }
function grba { git rebase --abort $args }
function grbc { git rebase --continue $args }
function grbd { git rebase $(git_develop_branch) $args }
function grbi { git rebase --interactive $args }
function grbm { git rebase $(git_main_branch) $args }
function grbo { git rebase --onto $args }
function grbom { git rebase origin/$(git_main_branch) $args }
function grbs { git rebase --skip $args }
function grbum { git rebase upstream/$(git_main_branch) $args }
function grev { git revert $args }
function greva { git revert --abort $args }
function grevc { git revert --continue $args }
function grf { git reflog $args }
function grh { git reset $args }
function grhh { git reset --hard $args }
function grhk { git reset --keep $args }
function grhs { git reset --soft $args }
function grm { git rm $args }
function grmc { git rm --cached $args }
function grmv { git remote rename $args }
function groh { git reset origin/$(git_current_branch) --hard $args }
function grrm { git remote remove $args }
function grs { git restore $args }
function grset { git remote set-url $args }
function grss { git restore --source $args }
function grst { git restore --staged $args }
function grt {
    $gitRoot = git rev-parse --show-toplevel 2> $null
    if ([string]::IsNullOrWhiteSpace($gitRoot)) {
        Set-Location -Path '.'
    } else {
        Set-Location -LiteralPath $gitRoot.Trim()
    }
}
function gru { git reset -- $args }
function grup { git remote update $args }
function grv { git remote --verbose $args }
function gsb { git status --short --branch $args }
function gsd { git svn dcommit $args }
function gsh { git show $args }
function gsi { git submodule init $args }
function gsps { git show --pretty=short --show-signature $args }
function gsr { git svn rebase $args }
function gss { git status --short $args }
function gst { git status $args }
function gsta { git stash push $args }
function gstaa { git stash apply $args }
function gstall { git stash --all $args }
function gstc { git stash clear $args }
function gstd { git stash drop $args }
function gstl { git stash list $args }
function gstp { git stash pop $args }
function gsts { git stash show --patch $args }
function gsu { git submodule update $args }
function gsw { git switch $args }
function gswc { git switch --create $args }
function gswd { git switch $(git_develop_branch) $args }
function gswm { git switch $(git_main_branch) $args }
function gta { git tag --annotate $args }
function gtl { param($pattern="*"); git tag --sort=-v:refname -n --list "${pattern}*" }
function gts { git tag --sign $args }
function gtv { git tag | Sort-Object -Property { [Version]$_ } $args }
function gunignore { git update-index --no-assume-unchanged $args }
function gunwip {
    $msg = git rev-list --max-count=1 --format="%s" HEAD
    if ($msg -match "--wip--") {
        git reset HEAD~1
    }
}
function gwch { git whatchanged -p --abbrev-commit --pretty=medium $args }
function gwip {
    git add -A
    git ls-files --deleted -z | ForEach-Object { if ($_) { git rm $_ } } 2> $null
    git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]" $args
}
function gwipe {
    git reset --hard
    if ($LASTEXITCODE -eq 0) {
        git clean --force -df $args
    }
}
function gwt { git worktree $args }
function gwta { git worktree add $args }
function gwtls { git worktree list $args }
function gwtmv { git worktree move $args }
function gwtrm { git worktree remove $args }

# Common function for _git_log_prettily
function _git_log_prettily {
    if ($args.Count -eq 0) {
        git log --pretty=format:"%C(auto)%h%Creset -%C(auto)%d%Creset %s %C(green)(%cr) %C(bold blue)<%an>%Creset"
    } else {
        git log --pretty=format:"%C(auto)%h%Creset -%C(auto)%d%Creset %s %C(green)(%cr) %C(bold blue)<%an>%Creset" $args
    }
}

function ConvertFrom-GitPathLiteral {
    param([string]$PathText)

    if ([string]::IsNullOrWhiteSpace($PathText)) {
        return $PathText
    }

    $resolved = $PathText.Trim()

    if ($resolved.StartsWith('"') -and $resolved.EndsWith('"')) {
        $resolved = $resolved.Substring(1, $resolved.Length - 2)
        $resolved = [System.Text.RegularExpressions.Regex]::Unescape($resolved)
    }

    return $resolved
}

function Get-GitStatusEntries {
    $statusLines = git status --short --untracked-files=all 2> $null
    if (-not $statusLines) {
        return @()
    }

    $entries = @()

    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 3) {
            continue
        }

        $rawStatus = $line.Substring(0, 2)
        $normalizedStatus = $rawStatus -replace ' ', '.'
        $pathFragment = $line.Substring(3)

        $resolvedPath = $pathFragment
        if ($resolvedPath -match '\s->\s') {
            $resolvedPath = ($resolvedPath -split '\s+->\s+')[-1]
        }
        $resolvedPath = ConvertFrom-GitPathLiteral $resolvedPath

        $entries += [PSCustomObject]@{
            Status = $rawStatus
            NormalizedStatus = $normalizedStatus
            PathFragment = $pathFragment
            ResolvedPath = $resolvedPath
            Display = "{0} {1}" -f $normalizedStatus, $pathFragment
        }
    }

    return $entries
}

function gcnvm {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Message,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$AdditionalArgs
    )

    $arguments = @('--no-verify', '-m', $Message)
    if ($AdditionalArgs) {
        $arguments += $AdditionalArgs
    }

    git commit @arguments
}

function git_history_purge {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Path)

    git filter-repo --path $Path --invert-paths --force
}

function git_rebase_sign_all {
    param([Parameter(Mandatory = $true, Position = 0)][string]$BaseCommit)

    git rebase -i --exec 'git commit --amend --no-edit --gpg-sign' $BaseCommit
}

function git_deleted_files_restore {
    $deletedFiles = git ls-files -d 2> $null
    if (-not $deletedFiles) {
        Write-Host 'No deleted files detected.' -ForegroundColor Yellow
        return
    }

    git restore --source=HEAD --staged --worktree -- $deletedFiles
}

function git_files_select {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$StatusFilter,
        [Parameter(Mandatory = $true, Position = 1)][string]$PromptText
    )

    $entries = Get-GitStatusEntries
    if (-not $entries) {
        Write-Host 'No Git changes found.' -ForegroundColor Yellow
        return @()
    }

    $filtered = $entries | Where-Object { $_.NormalizedStatus -match $StatusFilter }
    if (-not $filtered) {
        Write-Host "No files match filter '$StatusFilter'." -ForegroundColor Yellow
        return @()
    }

    $lookup = @{}
    foreach ($entry in $filtered) {
        $lookup[$entry.Display] = $entry
    }

    $selection = Invoke-FzfSelection -Items ($filtered.Display) -PromptText $PromptText -Multi
    if (-not $selection) {
        return @()
    }

    $selectionList = if ($selection -is [System.Array]) { $selection } else { @($selection) }

    $paths = foreach ($item in $selectionList) {
        if ($lookup.ContainsKey($item)) {
            $lookup[$item].ResolvedPath
        }
    }

    return $paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function git_diff {
    $files = git_files_select '.[MD]' 'Git diff'
    if (-not $files) {
        return
    }

    git diff -- $files
}

function git_diff_index {
    $files = git_files_select '[MDRA]' 'Git diff (INDEX)'
    if (-not $files) {
        return
    }

    git diff --cached -- $files
}

function git_add_select {
    $files = git_files_select '.[MD?]' 'Git add'
    if (-not $files) {
        return
    }

    git add -- $files
}

function git_restore_select {
    $files = git_files_select '.[MD]' 'Git restore'
    if (-not $files) {
        return
    }

    git restore -- $files
}

function git_untracked_remove {
    $files = git_files_select '.[?]' 'Git remove'
    if (-not $files) {
        return
    }

    foreach ($path in $files) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

function git_unstage {
    $files = git_files_select '[MDRA]' 'Git unstage'
    if (-not $files) {
        return
    }

    git restore --staged -- $files
}

function git_assume_unchanged_list {
    git ls-files -v | Where-Object { $_ -match '^[a-z]' } | ForEach-Object { $_.Substring(2) }
}

function git_skip_worktree_list {
    git ls-files -v | Where-Object { $_ -match '^S' } | ForEach-Object { $_.Substring(2) }
}

function git_patch_create {
    param([string]$PatchName)

    $name = $PatchName
    while ([string]::IsNullOrWhiteSpace($name)) {
        $name = Read-Host 'Enter patch file name (e.g. patch-file)'
    }

    $patchFile = "$name.patch"
    $addTxt = Read-Host 'Add .txt extension for GitHub? [y/N]'
    if ($addTxt -match '^[Yy]$') {
        $patchFile = "$patchFile.txt"
    }

    $files = git_files_select '.[MD]' 'Git create patch'
    if (-not $files) {
        Write-Host 'No files selected. Patch not created.' -ForegroundColor Yellow
        return
    }

    $diffOutput = git diff -- $files
    if (-not $diffOutput) {
        Write-Host 'No diff output generated. Patch not created.' -ForegroundColor Yellow
        return
    }

    Set-Content -LiteralPath $patchFile -Value $diffOutput -Encoding UTF8
    Write-Host "Patch file created: $patchFile" -ForegroundColor Green
}

function git_branch_delete_local_remote {
    [CmdletBinding()]
    param(
        [Alias('f')][switch]$Force,
        [Alias('h')][switch]$Help,
        [Parameter(Position = 0)][string]$Branch
    )

    if ($Help) {
        Write-Host "Uso: git_branch_delete_local_remote [-Force] [branch]" -ForegroundColor Cyan
        Write-Host "Sin 'branch' abre selector interactivo." -ForegroundColor Cyan
        return
    }

    $currentBranch = git rev-parse --abbrev-ref HEAD 2> $null

    if (-not $Branch) {
        $branches = git branch --format='%(refname:short)' 2> $null | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $candidates = $branches | Where-Object { $_ -ne $currentBranch }
        if (-not $candidates) {
            Write-Host 'No other branches available.' -ForegroundColor Yellow
            return
        }

        $selection = Invoke-FzfSelection -Items $candidates -PromptText 'Borrar branch > '
        if (-not $selection) {
            Write-Host 'Cancelado.' -ForegroundColor Yellow
            return
        }

        $Branch = if ($selection -is [System.Array]) { $selection[0] } else { $selection }
    }

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        Write-Host 'Cancelado.' -ForegroundColor Yellow
        return
    }

    if ($Branch -eq $currentBranch) {
        Write-Host "No se puede borrar la branch actual: $Branch" -ForegroundColor Red
        return
    }

    if (($Branch -eq 'main' -or $Branch -eq 'master') -and -not $Force) {
        Write-Host "Branch protegida ($Branch). Use -Force para eliminar." -ForegroundColor Red
        return
    }

    $deleteArgs = if ($Force) { @('-D', $Branch) } else { @('-d', $Branch) }
    git branch @deleteArgs
    if ($LASTEXITCODE -ne 0) {
        return
    }

    $upstream = git rev-parse --abbrev-ref --symbolic-full-name "$Branch@{upstream}" 2> $null
    if ($upstream) {
        $parts = $upstream -split '/', 2
        if ($parts.Count -eq 2) {
            $remote = $parts[0]
            $remoteBranch = $parts[1]
            git push $remote --delete $remoteBranch 2> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Remota eliminada: $remote/$remoteBranch" -ForegroundColor Cyan
            }
        }
    } else {
        git ls-remote --exit-code origin "refs/heads/$Branch" > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            git push origin --delete $Branch 2> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Remota eliminada: origin/$Branch" -ForegroundColor Cyan
            }
        }
        $LASTEXITCODE = 0
    }

    Write-Host "Branch local eliminada: $Branch" -ForegroundColor Green
}

function __git_get_descriptions {
    @(
        [PSCustomObject]@{ Command = 'git_history_purge'; Description = 'elimina completamente un archivo/directorio del historial de Git' }
        [PSCustomObject]@{ Command = 'git_rebase_sign_all'; Description = 'rebase interactivo firmando todos los commits con GPG' }
        [PSCustomObject]@{ Command = 'git_deleted_files_restore'; Description = 'restaura todos los archivos eliminados desde HEAD' }
        [PSCustomObject]@{ Command = 'git_files_select'; Description = 'selector interactivo de archivos Git con filtros de estado' }
        [PSCustomObject]@{ Command = 'git_diff'; Description = 'visualiza diferencias de archivos modificados/eliminados' }
        [PSCustomObject]@{ Command = 'git_diff_index'; Description = 'visualiza diferencias de archivos en staging area' }
        [PSCustomObject]@{ Command = 'git_add_select'; Description = 'añade archivos seleccionados al staging area' }
        [PSCustomObject]@{ Command = 'git_restore_select'; Description = 'descarta cambios de archivos seleccionados' }
        [PSCustomObject]@{ Command = 'git_untracked_remove'; Description = 'elimina archivos no rastreados del sistema de archivos' }
        [PSCustomObject]@{ Command = 'git_unstage'; Description = 'quita archivos del staging area (unstage)' }
        [PSCustomObject]@{ Command = 'git_assume_unchanged_list'; Description = 'lista archivos marcados como assume-unchanged' }
        [PSCustomObject]@{ Command = 'git_skip_worktree_list'; Description = 'lista archivos marcados como skip-worktree' }
        [PSCustomObject]@{ Command = 'git_patch_create'; Description = 'genera archivo patch desde diferencias seleccionadas' }
        [PSCustomObject]@{ Command = 'git_branch_delete_local_remote'; Description = 'elimina una branch local y su remota asociada (usa -Force para main/master)' }
    )
}

function gg {
    param([Alias('l')][switch]$List)

    $entries = __git_get_descriptions

    if ($List) {
        $entries | ForEach-Object {
            Write-Host ("{0,-35} {1}" -f $_.Command, $_.Description)
        }
        return
    }

    $items = foreach ($entry in $entries) {
        $display = "{0,-35} {1}" -f $entry.Command, $entry.Description
        [PSCustomObject]@{ Display = $display; Command = $entry.Command }
    }

    $selection = Invoke-FzfSelection -Items ($items.Display) -PromptText 'GIT >'
    if (-not $selection) {
        return
    }

    $selectedDisplay = if ($selection -is [System.Array]) { $selection[0] } else { $selection }
    $commandMatch = $items | Where-Object { $_.Display -eq $selectedDisplay } | Select-Object -First 1
    if (-not $commandMatch) {
        return
    }

    $commandText = "$($commandMatch.Command) "

    try {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($commandText)
        return
    } catch {
        # PSReadLine may be unavailable (e.g., in non-interactive hosts).
    }

    Write-Host $commandText
}

Set-Alias -Name ghistory_purge -Value git_history_purge
Set-Alias -Name grebase_sign_all -Value git_rebase_sign_all
Set-Alias -Name gdeleted_files_restore -Value git_deleted_files_restore
Set-Alias -Name gdiff -Value git_diff
Set-Alias -Name gdiff_index -Value git_diff_index
Set-Alias -Name gadd_select -Value git_add_select
Set-Alias -Name grestore_select -Value git_restore_select
Set-Alias -Name guntracked_remove -Value git_untracked_remove
Set-Alias -Name gunstage -Value git_unstage
Set-Alias -Name gassume_unchanged_list -Value git_assume_unchanged_list
Set-Alias -Name gskip_worktree_list -Value git_skip_worktree_list
Set-Alias -Name gpatch_create -Value git_patch_create
Set-Alias -Name gbranch_delete_local_remote -Value git_branch_delete_local_remote

# ███████ ██   ██  █████
# ██       ██ ██  ██   ██
# █████     ███   ███████
# ██       ██ ██  ██   ██
# ███████ ██   ██ ██   ██

$eza_options = "--group-directories-first --icons"

function exa {
  if ($args.Count -eq 0) {
    & eza @($eza_options -split ' ')
  } else {
    & eza @(($eza_options -split ' ') + $args)
  }
}

$ll_options = "$eza_options --long --header --group"

function ll {
  if ($args.Count -eq 0) {
    & eza @($ll_options -split ' ')
  } else {
    & eza @(($ll_options -split ' ') + $args)
  }
}

$la_options = "$ll_options --all"

function la {
  if ($args.Count -eq 0) {
    & eza @($la_options -split ' ')
  } else {
    & eza @(($la_options -split ' ') + $args)
  }
}

$lt_options = "$eza_options --tree"

function lt {
  if ($args.Count -eq 0) {
    & eza @($lt_options -split ' ')
  } else {
    & eza @(($lt_options -split ' ') + $args)
  }
}

# ███████ ███████ ███████
# ██         ███  ██
# █████     ███   █████
# ██       ███    ██
# ██      ███████ ██

# FZF configuration
$FZF_HEADER_MULTI_SELECT_PROMPT = '(Multi-select) Select items with TAB and ENTER to confirm'
$FZF_HEADER_SINGLE_SELECT_PROMPT = '(Single-select) Select item with ENTER to confirm'
$FZF_PREFIX_PROMPT = '🔍  '
$FZF_DEFAULT_BIND = 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
$FZF_COLOR_MOLOKAI = 'bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672'

# Set FZF pointer and marker symbols (these need to be defined)
$POINTER = '➤'
$MARKER = '✓'

# Set FZF default options
$env:FZF_DEFAULT_OPTS = "--color=`"$FZF_COLOR_MOLOKAI`" --ansi --cycle --border=rounded --prompt=`"$FZF_PREFIX_PROMPT`" --pointer=$POINTER --marker=$MARKER --header=`"$FZF_HEADER_SINGLE_SELECT_PROMPT`" --multi=0 --bind=`"$FZF_DEFAULT_BIND`""

function Invoke-FzfSelection {
    param(
        [Parameter(Mandatory = $true)][string[]]$Items,
        [string]$PromptText = '',
        [switch]$Multi
    )

    if (-not $Items -or $Items.Count -eq 0) {
        return @()
    }

    $fzfCommand = Get-Command fzf -ErrorAction SilentlyContinue
    if (-not $fzfCommand) {
        Write-Warning 'fzf is not available on PATH; interactive selection is skipped.'
        return @()
    }

    $prompt = if ([string]::IsNullOrWhiteSpace($PromptText)) {
        $FZF_PREFIX_PROMPT
    } else {
        "$FZF_PREFIX_PROMPT$PromptText "
    }

    $fzfArgs = @('--ansi', '--prompt', $prompt)
    if ($Multi) {
        $fzfArgs += '--multi'
        if ($FZF_HEADER_MULTI_SELECT_PROMPT) {
            $fzfArgs += @('--header', $FZF_HEADER_MULTI_SELECT_PROMPT)
        }
    } elseif ($FZF_HEADER_SINGLE_SELECT_PROMPT) {
        $fzfArgs += @('--header', $FZF_HEADER_SINGLE_SELECT_PROMPT)
    }

    try {
        $selection = $Items | & $fzfCommand.Source @fzfArgs
    } catch {
        Write-Warning "fzf invocation failed: $_"
        return @()
    }

    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    return $selection
}

#  ██████  ██   ██  ██████
# ██       ██   ██ ██    ██
# ██   ███ ███████ ██    ██
# ██    ██ ██   ██ ██ ▄▄ ██
#  ██████  ██   ██  ██████
#                      ▀▀

function Select-GhqRepositoryPath {
    param(
        [string]$PromptLabel = 'GHQ',
        [string]$DefaultQuery = ''
    )

    $ghqCommand = Get-Command ghq -ErrorAction SilentlyContinue
    if (-not $ghqCommand) {
        Write-Warning "ghq is not available on PATH; install it (for example, 'scoop install ghq')."
        return $null
    }

    $fzfCommand = Get-Command fzf -ErrorAction SilentlyContinue
    if (-not $fzfCommand) {
        Write-Warning 'fzf is not available on PATH; ghq picker requires fzf.'
        return $null
    }

    try {
        $repoList = & $ghqCommand.Source list 2> $null
    } catch {
        Write-Warning "Failed to execute 'ghq list': $_"
        return $null
    }

    if (-not $repoList) {
        Write-Warning 'No ghq repositories found.'
        return $null
    }

    $items = @()
    foreach ($repo in $repoList) {
        if (-not [string]::IsNullOrWhiteSpace($repo)) {
            $items += $repo.Trim()
        }
    }

    if (-not $items) {
        Write-Warning 'No ghq repositories found.'
        return $null
    }

    $promptSuffix = if ([string]::IsNullOrWhiteSpace($PromptLabel)) { '[GHQ] ' } else { "[$PromptLabel] " }
    $fzfArgs = @('--ansi', '--prompt', "$FZF_PREFIX_PROMPT$promptSuffix")
    if (-not [string]::IsNullOrWhiteSpace($DefaultQuery)) {
        $fzfArgs += @('--query', $DefaultQuery)
    }

    try {
        $selection = $items | & $fzfCommand.Source @fzfArgs
    } catch {
        Write-Warning "fzf invocation failed: $_"
        return $null
    }

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($selection)) {
        return $null
    }

    $selectedRelative = ($selection -split '\r?\n')[0].Trim()
    if ([string]::IsNullOrWhiteSpace($selectedRelative)) {
        return $null
    }

    try {
        $rootOutput = & $ghqCommand.Source root 2> $null
    } catch {
        Write-Warning "Failed to determine ghq root: $_"
        return $null
    }

    $roots = @()
    foreach ($entry in $rootOutput) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            $roots += $entry.Trim()
        }
    }

    if (-not $roots) {
        Write-Warning 'ghq root returned no paths.'
        return $null
    }

    $primaryRoot = $roots[0]
    $targetPath = [System.IO.Path]::Combine($primaryRoot, $selectedRelative)

    return $targetPath
}

function Invoke-GhqRepositoryJump {
    param(
        [string]$PromptLabel = 'GHQ',
        [string]$DefaultQuery = ''
    )

    $targetPath = Select-GhqRepositoryPath -PromptLabel $PromptLabel -DefaultQuery $DefaultQuery
    if (-not $targetPath) {
        return
    }

    try {
        Set-Location -LiteralPath $targetPath
    } catch {
        Write-Warning "Unable to change directory to '$targetPath': $($_.Exception.Message)"
    }
}

function Invoke-GhqRepositoryGlobal {
    Invoke-GhqRepositoryJump -PromptLabel 'Global' -DefaultQuery '!work/ '
}

function Invoke-GhqRepositoryWork {
    Invoke-GhqRepositoryJump -PromptLabel 'Work' -DefaultQuery 'work/ !forks '
}

function Invoke-GhqRepositoryProjects {
    Invoke-GhqRepositoryJump -PromptLabel 'Projects' -DefaultQuery 'projects/ '
}

function Invoke-GhqKeyHandler {
    param(
        [string]$PromptLabel,
        [string]$DefaultQuery
    )

    $psConsoleReadLineType = [Microsoft.PowerShell.PSConsoleReadLine] -as [type]
    $didRevert = $false

    if ($psConsoleReadLineType) {
        try {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            $didRevert = $true
        } catch {
            $didRevert = $false
        }
    }

    Invoke-GhqRepositoryJump -PromptLabel $PromptLabel -DefaultQuery $DefaultQuery

    if ($psConsoleReadLineType) {
        try {
            if ($didRevert) {
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            } else {
                $invokePromptMethod = $psConsoleReadLineType.GetMethod('InvokePrompt', [Type[]]@())
                if ($invokePromptMethod) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Repaint()
                }
            }
        } catch {
            try { [Microsoft.PowerShell.PSConsoleReadLine]::Repaint() } catch { }
        }
    }
}

$psConsoleReadLineType = [Microsoft.PowerShell.PSConsoleReadLine] -as [type]
if ($psConsoleReadLineType) {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+g' -BriefDescription 'GHQ Global' -LongDescription 'Jump to ghq repository (excluding work/*)' -ScriptBlock {
        param($key, $arg)
        Invoke-GhqKeyHandler -PromptLabel 'Global' -DefaultQuery '!work/ '
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+w' -BriefDescription 'GHQ Work' -LongDescription 'Jump to work ghq repositories' -ScriptBlock {
        param($key, $arg)
        Invoke-GhqKeyHandler -PromptLabel 'Work' -DefaultQuery 'work/ !forks '
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+p' -BriefDescription 'GHQ Projects' -LongDescription 'Jump to personal/project ghq repositories' -ScriptBlock {
        param($key, $arg)
        Invoke-GhqKeyHandler -PromptLabel 'Projects' -DefaultQuery 'projects/ '
    }
}
