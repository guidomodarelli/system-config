# Git aliases for PowerShell

# Helper functions for Git commands that need branch names
function git_current_branch {
    (git symbolic-ref --short HEAD 2> $null) -or (git rev-parse --short HEAD 2> $null)
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
function gbg { Set-Variable -Name LANG -Value "C"; git branch -vv | Select-String ": gone\]" }
function gbgD {
    Set-Variable -Name LANG -Value "C"
    git branch --no-color -vv | Select-String ": gone\]" | ForEach-Object {
        git branch -D ($_.ToString() -replace "^.*?(\S+).*$", '$1')
    }
}
function gbgd {
    Set-Variable -Name LANG -Value "C"
    git branch --no-color -vv | Select-String ": gone\]" | ForEach-Object {
        git branch -d ($_.ToString() -replace "^.*?(\S+).*$", '$1')
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
function gg { git gui citool $args }
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
function gpoat { git push origin --all && git push origin --tags $args }
function gpod { git push origin --delete $args }
function gpr { git pull --rebase $args }
function gpra { git pull --rebase --autostash $args }
function gprav { git pull --rebase --autostash -v $args }
function gpristine { git reset --hard && git clean --force -dfx $args }
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
function grt { Set-Location -Path "$(git rev-parse --show-toplevel 2> $null || echo '.')" }
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
function gwipe { git reset --hard && git clean --force -df $args }
function gwt { git worktree $args }
function gwta { git worktree add $args }
function gwtls { git worktree list $args }
function gwtmv { git worktree move $args }
function gwtrm { git worktree remove $args }

# Grep with color and exclusions
function global:grep { & grep.exe --color=auto --exclude-dir=".bzr" --exclude-dir="CVS" --exclude-dir=".git" --exclude-dir=".hg" --exclude-dir=".svn" --exclude-dir=".idea" --exclude-dir=".tox" --exclude-dir=".venv" --exclude-dir="venv" $args }
function rg { & rg.exe --glob "!.git/*" $args }

# Common function for _git_log_prettily
function _git_log_prettily {
    if ($args.Count -eq 0) {
        git log --pretty=format:"%C(auto)%h%Creset -%C(auto)%d%Creset %s %C(green)(%cr) %C(bold blue)<%an>%Creset"
    } else {
        git log --pretty=format:"%C(auto)%h%Creset -%C(auto)%d%Creset %s %C(green)(%cr) %C(bold blue)<%an>%Creset" $args
    }
}

$exa_options = "--group-directories-first --icons"

function exa {
  if ($args.Count -eq 0) {
    & eza @($exa_options -split ' ')
  } else {
    & eza @(($exa_options -split ' ') + $args)
  }
}

$ll_options = "$exa_options --long --header --group"

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

$lt_options = "$exa_options --tree"

function lt {
  if ($args.Count -eq 0) {
    & eza @($lt_options -split ' ')
  } else {
    & eza @(($lt_options -split ' ') + $args)
  }
}
