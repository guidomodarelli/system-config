# ██████  ███████ ███████  █████  ██    ██ ██      ████████ ███████
# ██   ██ ██      ██      ██   ██ ██    ██ ██         ██    ██
# ██   ██ █████   █████   ███████ ██    ██ ██         ██    ███████
# ██   ██ ██      ██      ██   ██ ██    ██ ██         ██         ██
# ██████  ███████ ██      ██   ██  ██████  ███████    ██    ███████

# Console en UTF-8: sin esto [Console]::OutputEncoding queda en CP437 (OEM) y los
# glifos del prompt (✔ ✗ ● ◦) salen como `?` cuando PSReadLine los repinta via
# InvokePrompt (p.ej. tras un checkout con el widget fzf). El render normal de Oh
# My Posh no lo necesita, pero el repintado de PSReadLine respeta este encoding.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# --- Cache de scripts de init/completion --------------------------------------
# Spawnear un CLI (Node, Go, Rust) para generar su script de init o completion
# cuesta 30-200 ms por arranque. Estos helpers cachean el script generado a
# disco y lo regeneran solo cuando cambia el fingerprint (primera línea del
# archivo). Definidos antes de cualquier init (zoxide, codex, oh-my-posh).

# Path estable del ejecutable de un comando: si su directorio es un link (p.ej.
# los multishell dirs por sesión de fnm), se resuelve al directorio real para
# que el fingerprint no cambie entre sesiones.
function Get-StableExecutablePath {
    param([Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$CommandInfo)

    $executableItem = Get-Item -LiteralPath $CommandInfo.Source -ErrorAction SilentlyContinue
    if (-not $executableItem) {
        return $CommandInfo.Source
    }

    $executableDirectoryItem = $executableItem.Directory
    if ($executableDirectoryItem -and $executableDirectoryItem.LinkType) {
        $resolvedDirectory = $executableDirectoryItem.ResolveLinkTarget($true)
        if ($resolvedDirectory) {
            return (Join-Path $resolvedDirectory.FullName $executableItem.Name)
        }
    }

    return $executableItem.FullName
}

# Fingerprint "path estable|mtime ticks" del ejecutable de un comando.
function Get-ExecutableFingerprint {
    param([Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$CommandInfo)

    $executableItem = Get-Item -LiteralPath $CommandInfo.Source -ErrorAction SilentlyContinue
    $executableTicks = if ($executableItem) { $executableItem.LastWriteTimeUtc.Ticks } else { 0 }
    return '{0}|{1}' -f (Get-StableExecutablePath -CommandInfo $CommandInfo), $executableTicks
}

# Devuelve el path del script cacheado, regenerándolo con $GenerateScriptText
# cuando el fingerprint de la primera línea no coincide. El caller debe
# dot-sourcear el path devuelto: el script se ejecuta fuera de esta función a
# propósito, para no encerrar sus definiciones en el scope de la función.
function Get-CachedInitScriptPath {
    param(
        [Parameter(Mandatory = $true)][string]$CachePath,
        [Parameter(Mandatory = $true)][string]$Fingerprint,
        [Parameter(Mandatory = $true)][scriptblock]$GenerateScriptText
    )

    $fingerprintLine = "# init-script-fingerprint $Fingerprint"
    $cacheIsFresh = (Test-Path -LiteralPath $CachePath) -and
        ((Get-Content -LiteralPath $CachePath -TotalCount 1) -eq $fingerprintLine)

    if (-not $cacheIsFresh) {
        $scriptText = (& $GenerateScriptText)
        if ([string]::IsNullOrWhiteSpace($scriptText)) {
            throw "Init script generator for '$CachePath' returned no output"
        }

        $cacheDirectory = Split-Path -Parent $CachePath
        if (-not (Test-Path -LiteralPath $cacheDirectory)) {
            New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
        }
        Set-Content -LiteralPath $CachePath -Value ($fingerprintLine + [Environment]::NewLine + $scriptText) -Encoding utf8
    }

    return $CachePath
}
# --- Fin cache de scripts de init/completion -----------------------------------

# Grep with color and exclusions
function global:grep { & grep.exe --color=auto --exclude-dir=".bzr" --exclude-dir="CVS" --exclude-dir=".git" --exclude-dir=".hg" --exclude-dir=".svn" --exclude-dir=".idea" --exclude-dir=".tox" --exclude-dir=".venv" --exclude-dir="venv" $args }
function rg { & rg.exe --glob "!.git/*" $args }

$zoxideCommand = Get-Command zoxide -ErrorAction SilentlyContinue
if ($zoxideCommand) {
    try {
        # Cache del init de zoxide: evita spawnear el binario (~30 ms) por arranque.
        . (Get-CachedInitScriptPath `
            -CachePath (Join-Path $env:LOCALAPPDATA 'PowerShell\zoxide-init-cache.ps1') `
            -Fingerprint (Get-ExecutableFingerprint -CommandInfo $zoxideCommand) `
            -GenerateScriptText { (& $zoxideCommand.Source init powershell) -join [Environment]::NewLine })
    } catch {
        Write-Warning "Unable to initialize zoxide: $($_.Exception.Message)"
    }
}

fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# Ensure ~\.local\bin (used by native installers such as Claude Code) is on PATH.
$localBin = Join-Path $env:USERPROFILE '.local\bin'
if ((Test-Path $localBin) -and ($env:Path -split [IO.Path]::PathSeparator) -notcontains $localBin) {
    $env:Path = "$localBin$([IO.Path]::PathSeparator)$env:Path"
}

# Asegura que openssl.exe sea spawneable por Node (portless, etc.) y apunta
# OPENSSL_CONF al openssl.cnf que acompaña al binario detectado.
$opensslInstallCandidates = @(
    'C:\Program Files\Git\mingw64\bin\openssl.exe',
    'C:\Program Files\Git\usr\bin\openssl.exe',
    'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
    'C:\Program Files\OpenSSL\bin\openssl.exe',
    'C:\Program Files (x86)\OpenSSL-Win32\bin\openssl.exe',
    'C:\Program Files (x86)\OpenSSL\bin\openssl.exe'
)
$opensslExecutablePath = $null
$opensslCommand = Get-Command openssl.exe -ErrorAction SilentlyContinue
if ($opensslCommand) {
    $opensslExecutablePath = $opensslCommand.Source
} else {
    foreach ($candidateExecutable in $opensslInstallCandidates) {
        if (Test-Path -LiteralPath $candidateExecutable -PathType Leaf) {
            $opensslExecutablePath = $candidateExecutable
            break
        }
    }
}

if ($opensslExecutablePath) {
    $opensslBinaryDirectory = Split-Path -Parent $opensslExecutablePath
    if (($env:Path -split [IO.Path]::PathSeparator) -notcontains $opensslBinaryDirectory) {
        $env:Path = "$opensslBinaryDirectory$([IO.Path]::PathSeparator)$env:Path"
    }

    if (-not $env:OPENSSL_CONF) {
        $opensslConfigCandidates = @(
            (Join-Path $opensslBinaryDirectory '..\ssl\openssl.cnf'),
            (Join-Path $opensslBinaryDirectory '..\etc\ssl\openssl.cnf'),
            (Join-Path $opensslBinaryDirectory '..\..\etc\ssl\openssl.cnf'),
            (Join-Path $opensslBinaryDirectory '..\..\ssl\openssl.cnf'),
            (Join-Path $opensslBinaryDirectory 'cnf\openssl.cnf'),
            (Join-Path $opensslBinaryDirectory 'openssl.cnf')
        )
        foreach ($candidatePath in $opensslConfigCandidates) {
            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                $env:OPENSSL_CONF = (Resolve-Path -LiteralPath $candidatePath).Path
                break
            }
        }
    }
}

# Absolute repository root derived from this profile's real location. $PROFILE
# es un symlink (OneDrive\Documents\PowerShell) fuera del repo: `git -C` sobre
# $PSScriptRoot fallaba siempre y el fallback `../..` apuntaba a OneDrive.
# Resolver el symlink evita spawnear git y ancla al layout real del repo
# (<repo>/configs/PowerShell).
$script:ProfileScriptItem = Get-Item -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue
$script:ProfileScriptRealItem = if ($script:ProfileScriptItem -and $script:ProfileScriptItem.LinkType) {
    $script:ProfileScriptItem.ResolveLinkTarget($true)
} else {
    $script:ProfileScriptItem
}
$script:ProfileScriptDirectory = if ($script:ProfileScriptRealItem) {
    $script:ProfileScriptRealItem.DirectoryName
} else {
    $PSScriptRoot
}
$script:REPO_ROOT = (Resolve-Path (Join-Path $script:ProfileScriptDirectory '..\..')).Path

# --- Codex unified (replica de lógica Zsh) ------------------------------------

# Returns the built-in prompt used by `cx --commit`.
function Get-CxCommitPrompt {
    $promptFile = Join-Path $script:REPO_ROOT 'configs/.agents/skills/commands/generate-commit-messages/SKILL.md'

    if (-not (Test-Path -LiteralPath $promptFile)) {
        throw "Commit prompt file not found: $promptFile"
    }

    return (Get-Content -LiteralPath $promptFile -Raw)
}

function Get-CxPluginIdForMcpServer {
    param([string]$ServerName)

    if ([string]::IsNullOrWhiteSpace($ServerName)) {
        return $null
    }

    $codexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        Join-Path $HOME '.codex'
    } else {
        $env:CODEX_HOME
    }
    $pluginCacheDir = Join-Path $codexHome 'plugins/cache'

    if (-not (Test-Path -LiteralPath $pluginCacheDir -PathType Container)) {
        return $null
    }

    foreach ($marketplaceDir in (Get-ChildItem -LiteralPath $pluginCacheDir -Directory -ErrorAction SilentlyContinue)) {
        foreach ($pluginDir in (Get-ChildItem -LiteralPath $marketplaceDir.FullName -Directory -ErrorAction SilentlyContinue)) {
            foreach ($versionDir in (Get-ChildItem -LiteralPath $pluginDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                $pluginManifestPath = Join-Path $versionDir.FullName '.codex-plugin/plugin.json'
                if (-not (Test-Path -LiteralPath $pluginManifestPath -PathType Leaf)) {
                    continue
                }

                try {
                    $pluginManifest = Get-Content -LiteralPath $pluginManifestPath -Raw | ConvertFrom-Json
                } catch {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($pluginManifest.mcpServers)) {
                    continue
                }

                $mcpConfigPath = if ([System.IO.Path]::IsPathRooted($pluginManifest.mcpServers)) {
                    $pluginManifest.mcpServers
                } else {
                    Join-Path $versionDir.FullName $pluginManifest.mcpServers
                }
                if (-not (Test-Path -LiteralPath $mcpConfigPath -PathType Leaf)) {
                    continue
                }

                try {
                    $mcpConfig = Get-Content -LiteralPath $mcpConfigPath -Raw | ConvertFrom-Json
                } catch {
                    continue
                }

                $mcpServerNames = @($mcpConfig.mcpServers.PSObject.Properties.Name)
                if ($mcpServerNames -notcontains $ServerName) {
                    continue
                }

                $pluginName = if ([string]::IsNullOrWhiteSpace($pluginManifest.name)) {
                    $pluginDir.Name
                } else {
                    $pluginManifest.name
                }

                return "$pluginName@$($marketplaceDir.Name)"
            }
        }
    }

    return $null
}

# Returns `-c` overrides to disable all configured MCP servers for the current run.
function Get-CxDisableMcpConfigArgs {
    $disableArgs = New-Object System.Collections.Generic.List[string]
    $seenConfigKeys = @{}
    $mcpListJson = & codex mcp list --json 2>$null

    if ($mcpListJson) {
        try {
            $mcpServers = $mcpListJson | ConvertFrom-Json
        } catch {
            $mcpServers = @()
        }

        foreach ($server in $mcpServers) {
            if ($null -eq $server -or [string]::IsNullOrWhiteSpace($server.name)) { continue }
            if ($server.enabled -eq $false) { continue }

            $configKey = "mcp_servers.$($server.name).enabled=false"
            $pluginId = $null
            $transportCwd = $server.transport.cwd
            if (-not [string]::IsNullOrWhiteSpace($transportCwd)) {
                $normalizedCwd = ($transportCwd -replace '\\', '/')
                $pluginPathPattern = '/plugins/cache/(?<marketplace>[^/]+)/(?<plugin>[^/]+)/'
                if ($normalizedCwd -match $pluginPathPattern) {
                    $pluginId = "$($Matches['plugin'])@$($Matches['marketplace'])"
                }
            }

            if ([string]::IsNullOrWhiteSpace($pluginId)) {
                $pluginId = Get-CxPluginIdForMcpServer -ServerName $server.name
            }
            if (-not [string]::IsNullOrWhiteSpace($pluginId)) {
                $configKey = "plugins.`"$pluginId`".enabled=false"
            }

            if (-not $seenConfigKeys.ContainsKey($configKey)) {
                $seenConfigKeys[$configKey] = $true
                $disableArgs.Add('-c')
                $disableArgs.Add($configKey)
            }
        }

        return $disableArgs.ToArray()
    }

    $mcpListOutput = & codex mcp list 2>$null
    if (-not $mcpListOutput) {
        return @()
    }

    $serverNames = New-Object System.Collections.Generic.List[string]
    foreach ($line in $mcpListOutput) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*Name\s+') { continue }
        if ($line -match '^\s*-+\s*$') { continue }
        if ($line -match '^\s*No\s+MCP\s+servers?.*$') { continue }
        if ($line -match '^\s*(?<name>[A-Za-z0-9._-]+)\s+(?<transport>stdio|sse|http|https|ws|wss|streamable_http)\b') {
            $serverNames.Add($Matches['name'])
        }
    }

    foreach ($serverName in ($serverNames | Select-Object -Unique)) {
        $configKey = "mcp_servers.$serverName.enabled=false"
        if (-not $seenConfigKeys.ContainsKey($configKey)) {
            $seenConfigKeys[$configKey] = $true
            $disableArgs.Add('-c')
            $disableArgs.Add($configKey)
        }
    }

    return $disableArgs.ToArray()
}

function Resolve-CxCodexExecutable {
    $codexCommand = Get-Command codex -ErrorAction Stop

    if ($codexCommand.CommandType -eq [System.Management.Automation.CommandTypes]::ExternalScript -and
        [System.IO.Path]::GetExtension($codexCommand.Source) -eq '.ps1') {
        $codexCmdShim = [System.IO.Path]::ChangeExtension($codexCommand.Source, '.cmd')

        if (Test-Path -LiteralPath $codexCmdShim) {
            return $codexCmdShim
        }
    }

    return $codexCommand.Source
}

# Unified implementation: cx handles both safe and yolo modes.
function cx {
    Clear-Host

    $cliArgs = @($args)

    if ($cliArgs.Count -gt 0 -and $cliArgs[0] -eq 'upgrade') {
        # PowerShell-only behavior: upgrade Codex through npm.
        npm i -g @openai/codex
        return
    }

    $model = 'gpt-5.6-luna'
    $reasoning = 'high'
    $yolo = $false
    $commitMode = $false
    $disableMcps = $false
    $codexArgs = New-Object System.Collections.Generic.List[string]
    $promptArgs = New-Object System.Collections.Generic.List[string]
    $promptMode = $false
    $mcpConfigArgs = @()

    for ($i = 0; $i -lt $cliArgs.Count; $i++) {
        switch ($cliArgs[$i]) {
            '-m' {
                if ($i + 1 -lt $cliArgs.Count) {
                    $model = $cliArgs[$i + 1]
                    $i++
                }
            }
            '-re' {
                if ($i + 1 -lt $cliArgs.Count) {
                    $reasoning = $cliArgs[$i + 1]
                    $i++
                }
            }
            '-c' { $commitMode = $true }
            '--commit' { $commitMode = $true }
            # Kept as a no-op for compatibility; MCPs are enabled by default.
            '--mcps' {}
            '--no-mcps' { $disableMcps = $true }
            # Internal-only flag, exposed via `cxd`.
            '--yolo' {
                $yolo = $true
            }
            '--' {
                $promptMode = $true
                if ($i + 1 -lt $cliArgs.Count) {
                    for ($j = $i + 1; $j -lt $cliArgs.Count; $j++) {
                        $promptArgs.Add($cliArgs[$j])
                    }
                }
                break
            }
            default {
                $codexArgs.Add($cliArgs[$i])
            }
        }
    }

    if ($commitMode) {
        # `--commit` has priority over any user-provided query tokens.
        $yolo = $true
        $promptMode = $true
        $codexArgs.Clear()
        $promptArgs.Clear()
        $promptArgs.Add((Get-CxCommitPrompt))
    }

    if ($disableMcps) {
        $disableMcpConfigArgs = Get-CxDisableMcpConfigArgs
        if ($disableMcpConfigArgs.Count -gt 0) {
            $mcpConfigArgs = $disableMcpConfigArgs
        } else {
            $mcpConfigArgs = @()
        }
    }

    $cmd = @((Resolve-CxCodexExecutable),'-m', $model,'-c',"model_reasoning_effort=$reasoning")
    if ($mcpConfigArgs.Count -gt 0) {
        $cmd += $mcpConfigArgs
    }
    if ($yolo) {
        $cmd += '--yolo'
    } else {
        $cmd += @('--sandbox','workspace-write','--ask-for-approval','never')
    }
    if ($promptMode -and $promptArgs.Count -gt 0) {
        # Ensure prompts that start with "-" are treated as positional payload.
        $cmd += '--'
        $cmd += $promptArgs.ToArray()
    } elseif ($codexArgs.Count -gt 0) {
        $cmd += $codexArgs.ToArray()
    }

    Write-Host "Running: $($cmd -join ' ')"

    $codexExecutable = $cmd[0]
    $codexArguments = $cmd[1..($cmd.Count - 1)]

    & $codexExecutable @codexArguments
}

# Dangerous alias for codex (bypass approvals & sandbox)
function cxd {
    cx --yolo @args
}

$codexCommandInfo = Get-Command codex -ErrorAction SilentlyContinue
if ($codexCommandInfo) {
    try {
        # Cache del completion de Codex: `codex completion powershell` spawnea
        # el CLI de Node (~150 ms por arranque).
        . (Get-CachedInitScriptPath `
            -CachePath (Join-Path $env:LOCALAPPDATA 'PowerShell\codex-completion-cache.ps1') `
            -Fingerprint (Get-ExecutableFingerprint -CommandInfo $codexCommandInfo) `
            -GenerateScriptText { (& codex completion powershell) -join [Environment]::NewLine })
    } catch {
        Write-Warning "Unable to load Codex PowerShell completion: $($_.Exception.Message)"
    }

    $cxCompletionScriptBlock = {
        param($wordToComplete, $commandAst, $cursorPosition)

        $wrapperFlags = @(
            @{ Text = '-m'; List = '-m'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Modelo a usar' }
            @{ Text = '-re'; List = '-re'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Esfuerzo de razonamiento del modelo' }
            @{ Text = '-c'; List = '-c'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Usa el prompt interno de commit' }
            @{ Text = '--commit'; List = '--commit'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Usa el prompt interno de commit' }
            @{ Text = '--mcps'; List = '--mcps'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Compatibilidad: los servidores MCP ya están activos por defecto' }
            @{ Text = '--no-mcps'; List = '--no-mcps'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Desactiva los servidores MCP para esta ejecución' }
            @{ Text = 'upgrade'; List = 'upgrade'; Type = [System.Management.Automation.CompletionResultType]::ParameterValue; Tip = 'Actualiza Codex desde el wrapper' }
        )
        $modelOptions = @(
            'gpt-5.6-luna',
            'gpt-5.6-terra',
            'gpt-5.6-sol'
        )
        $reasoningOptions = @('medium', 'high', 'xhigh', 'max')

        $results = New-Object System.Collections.Generic.List[System.Management.Automation.CompletionResult]
        $dashMode = 'none'
        if ($wordToComplete -like '--*') {
            $dashMode = 'double'
        } elseif ($wordToComplete -like '-*') {
            $dashMode = 'single'
        }

        $elements = @($commandAst.CommandElements)
        $tokenTexts = @()
        foreach ($element in $elements) {
            $tokenTexts += $element.Extent.Text
        }

        $previousToken = $null
        if ($tokenTexts.Count -ge 2) {
            if ([string]::IsNullOrWhiteSpace($wordToComplete) -and $tokenTexts.Count -ge 2) {
                $previousToken = $tokenTexts[-1]
            } elseif ($tokenTexts.Count -ge 3) {
                $previousToken = $tokenTexts[-2]
            }
        }

        if ($previousToken -eq '-m') {
            foreach ($model in $modelOptions) {
                if ($model -like "$wordToComplete*") {
                    $results.Add([System.Management.Automation.CompletionResult]::new(
                        $model,
                        $model,
                        [System.Management.Automation.CompletionResultType]::ParameterValue,
                        'Model'
                    ))
                }
            }
        } elseif ($previousToken -eq '-re') {
            foreach ($reasoning in $reasoningOptions) {
                if ($reasoning -like "$wordToComplete*") {
                    $results.Add([System.Management.Automation.CompletionResult]::new(
                        $reasoning,
                        $reasoning,
                        [System.Management.Automation.CompletionResultType]::ParameterValue,
                        'Reasoning effort'
                    ))
                }
            }
        } else {
            foreach ($flag in $wrapperFlags) {
                $isShortFlag = $flag.Text.StartsWith('-') -and -not $flag.Text.StartsWith('--')
                $isLongFlag = $flag.Text.StartsWith('--')

                if ($dashMode -eq 'none' -and ($isShortFlag -or $isLongFlag)) { continue }
                if ($dashMode -eq 'single' -and -not $isShortFlag) { continue }
                if ($dashMode -eq 'double' -and -not $isLongFlag) { continue }

                if ($flag.Text -like "$wordToComplete*") {
                    $results.Add([System.Management.Automation.CompletionResult]::new(
                        $flag.Text,
                        $flag.List,
                        $flag.Type,
                        $flag.Tip
                    ))
                }
            }
        }

        $results |
            Sort-Object -Property ListItemText -Unique
    }

    Register-ArgumentCompleter -CommandName 'cx', 'cxd' -ScriptBlock $cxCompletionScriptBlock
}

# --- Fin Codex unified -------------------------------------------------------

# Dangerous Claude Code wrapper: bypasses all permission checks.
function ccd {
    Clear-Host
    & claude --dangerously-skip-permissions @args
}

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

function Get-GitLocalBranchCompletion {
    param([string]$WordToComplete)

    git for-each-ref --format='%(refname:short)' refs/heads 2> $null |
        Where-Object { $_ -like "$WordToComplete*" } |
        Sort-Object -Unique |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_,
                $_,
                [System.Management.Automation.CompletionResultType]::ParameterValue,
                'Git local branch'
            )
        }
}

$gitLocalBranchCompletionScriptBlock = {
    param($wordToComplete, $commandAst, $cursorPosition)

    Get-GitLocalBranchCompletion -WordToComplete $wordToComplete
}

Register-ArgumentCompleter -CommandName @(
    'gbD',
    'gbd',
    'gbm',
    'gco',
    'gcor',
    'gsw',
    'gm',
    'gms',
    'grb',
    'grbi',
    'grhh',
    'grhk',
    'grhs',
    'grss'
) -ScriptBlock $gitLocalBranchCompletionScriptBlock

# Simple aliases
Set-Alias -Name g -Value git
Set-Alias -Name gk -Value gitk

# Remove built-in aliases that conflict with git shorthand functions.
$gitFunctionAliasConflicts = @('gc', 'gcm', 'gcs', 'gl', 'gm', 'gp', 'gpv')
foreach ($aliasName in $gitFunctionAliasConflicts) {
    if (Test-Path "Alias:$aliasName") { Remove-Item "Alias:$aliasName" -Force }
}

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
function gbDs { git branch --delete $args }
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
    # PowerShell function names are case-insensitive, so gbgd and gbgD collide.
    # Both force-delete gone branches; use gbgs for the safe (-d) variant.
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
function gbgDs {
    # Safe delete of gone branches (-d): skips branches not fully merged.
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
function gfg {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string[]]$Pattern,
        [switch]$CaseSensitive,
        [switch]$SimpleMatch,
        [switch]$NotMatch,
        [switch]$AllMatches,
        [switch]$List,
        [switch]$Raw,
        [switch]$NoEmphasis,
        [switch]$Quiet,
        [int[]]$Context,
        [string]$Culture,
        [string]$Encoding,
        [string[]]$Include,
        [string[]]$Exclude
    )

    if (-not $Pattern) {
        Write-Host 'Uso: gfg <pattern> [Select-String args]' -ForegroundColor Yellow
        return
    }

    $selectStringParams = @{}
    foreach ($parameterName in @(
        'Pattern',
        'CaseSensitive',
        'SimpleMatch',
        'NotMatch',
        'AllMatches',
        'List',
        'Raw',
        'NoEmphasis',
        'Quiet',
        'Context',
        'Culture',
        'Encoding',
        'Include',
        'Exclude'
    )) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $selectStringParams[$parameterName] = $PSBoundParameters[$parameterName]
        }
    }

    Invoke-SelectStringOnGitLines -InputLines (git ls-files) @selectStringParams
}
function gfo { git fetch origin $args }
function gfp { git fetch --force --prune --prune-tags --tags --jobs=8 $args }
function ggui { git gui citool $args }
function gga { git gui citool --amend $args }
function ggpull { git pull origin "$(git_current_branch)" }
function ggpush { git push origin "$(git_current_branch)" }
function ggsup { git branch --set-upstream-to=origin/$(git_current_branch) $args }
function ghh { git help $args }
function gignore { git update-index --assume-unchanged $args }
function gignored {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string[]]$Pattern,
        [switch]$CaseSensitive,
        [switch]$SimpleMatch,
        [switch]$NotMatch,
        [switch]$AllMatches,
        [switch]$List,
        [switch]$Raw,
        [switch]$NoEmphasis,
        [switch]$Quiet,
        [int[]]$Context,
        [string]$Culture,
        [string]$Encoding,
        [string[]]$Include,
        [string[]]$Exclude
    )

    $ignoredLines = git ls-files -v | Where-Object { $_ -cmatch '^[a-z]' }
    if (-not $ignoredLines) {
        return
    }

    if (-not $Pattern) {
        $ignoredLines
        return
    }

    $selectStringParams = @{}
    foreach ($parameterName in @(
        'Pattern',
        'CaseSensitive',
        'SimpleMatch',
        'NotMatch',
        'AllMatches',
        'List',
        'Raw',
        'NoEmphasis',
        'Quiet',
        'Context',
        'Culture',
        'Encoding',
        'Include',
        'Exclude'
    )) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $selectStringParams[$parameterName] = $PSBoundParameters[$parameterName]
        }
    }

    Invoke-SelectStringOnGitLines -InputLines $ignoredLines @selectStringParams
}
if (Test-Path Alias:gl) { Remove-Item Alias:gl -Force }
function gl { git pull $args }
function gll { gl $args }
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
function gp { git push @args }
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
function gtv {
    [CmdletBinding()]
    param(
        [switch]$Descending,
        [switch]$Unique,
        [switch]$CaseSensitive,
        [string]$Culture,
        [switch]$Stable,
        [int]$Top,
        [int]$Bottom,
        [object[]]$Property
    )

    $tags = git tag
    if (-not $tags) {
        return
    }

    $sortProperties = @(
        @{ Expression = { (Get-GitTagVersionSortKey $_).IsVersion }; Descending = $true },
        @{ Expression = { (Get-GitTagVersionSortKey $_).Version }; Descending = [bool]$Descending },
        @{ Expression = { (Get-GitTagVersionSortKey $_).Label }; Descending = [bool]$Descending }
    )

    if ($PSBoundParameters.ContainsKey('Property')) {
        $sortProperties += $Property
    }

    $sortParams = @{
        Property = $sortProperties
    }

    if ($Unique) {
        $sortParams.Unique = $true
    }

    if ($CaseSensitive) {
        $sortParams.CaseSensitive = $true
    }

    if ($PSBoundParameters.ContainsKey('Culture')) {
        $sortParams.Culture = $Culture
    }

    if ($Stable) {
        $sortParams.Stable = $true
    }

    if ($PSBoundParameters.ContainsKey('Top')) {
        $sortParams.Top = $Top
    }

    if ($PSBoundParameters.ContainsKey('Bottom')) {
        $sortParams.Bottom = $Bottom
    }

    $tags | Sort-Object @sortParams
}
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

function Invoke-SelectStringOnGitLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string[]]$InputLines,
        [string[]]$Pattern,
        [switch]$CaseSensitive,
        [switch]$SimpleMatch,
        [switch]$NotMatch,
        [switch]$AllMatches,
        [switch]$List,
        [switch]$Raw,
        [switch]$NoEmphasis,
        [switch]$Quiet,
        [int[]]$Context,
        [string]$Culture,
        [string]$Encoding,
        [string[]]$Include,
        [string[]]$Exclude
    )

    if (-not $InputLines) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        $InputLines
        return
    }

    $selectStringParams = @{}

    foreach ($parameterName in @(
        'Pattern',
        'CaseSensitive',
        'SimpleMatch',
        'NotMatch',
        'AllMatches',
        'List',
        'Raw',
        'NoEmphasis',
        'Quiet',
        'Context',
        'Culture',
        'Encoding',
        'Include',
        'Exclude'
    )) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $selectStringParams[$parameterName] = $PSBoundParameters[$parameterName]
        }
    }

    $InputLines | Select-String @selectStringParams
}

function Get-GitTagVersionSortKey {
    param([string]$TagName)

    if ([string]::IsNullOrWhiteSpace($TagName)) {
        return [PSCustomObject]@{
            IsVersion = $false
            Version = [Version]'0.0'
            Label = ''
        }
    }

    $trimmed = $TagName.Trim()
    $normalized = $trimmed -replace '^[Vv]', ''

    $parsedVersion = $null
    if ([Version]::TryParse($normalized, [ref]$parsedVersion)) {
        return [PSCustomObject]@{
            IsVersion = $true
            Version = $parsedVersion
            Label = $trimmed
        }
    }

    return [PSCustomObject]@{
        IsVersion = $false
        Version = [Version]'0.0'
        Label = $trimmed
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
$FZF_PREFIX_PROMPT = '> '
$FZF_DEFAULT_BIND = 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
$FZF_COLOR_MOLOKAI = 'bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672'

# Set FZF pointer and marker symbols (these need to be defined)
$POINTER = '>'
$MARKER = '*'

# Set FZF default options
$env:FZF_DEFAULT_OPTS = "--color=$FZF_COLOR_MOLOKAI --ansi --cycle --border=rounded --prompt=> --pointer=$POINTER --marker=$MARKER --multi=0 --bind=$FZF_DEFAULT_BIND"

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

function Invoke-PSReadLinePromptRefresh {
    $psConsoleReadLineType = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
    if (-not $psConsoleReadLineType) {
        return
    }

    # PSReadLine solo expone InvokePrompt(int? key, object arg); ambos parametros
    # son opcionales, asi que PowerShell completa los defaults al llamar sin args.
    # No existe un metodo Repaint(): el probe previo con GetMethod fallaba (no hay
    # overload de 0 params) y caia a un fallback inexistente, dejando el refresco
    # como no-op y el prompt congelado tras un checkout via widget.
    try {
        $psConsoleReadLineType::InvokePrompt()
    } catch {
        # Hosts sin consola interactiva (p.ej. ISE) no soportan InvokePrompt.
    }
}

function Invoke-PSReadLineInsertText {
    param(
        [Parameter(Mandatory = $true)][string]$Text
    )

    $psConsoleReadLineType = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
    if ($psConsoleReadLineType) {
        try {
            $psConsoleReadLineType::Insert($Text)
            return
        } catch {
            # Fallback for hosts that do not support PSReadLine insertion.
        }
    }

    Write-Host $Text
}

function Invoke-FzfGitCheckoutRef {
    param(
        [Parameter(Mandatory = $true)][string]$RefKind,
        [Parameter(Mandatory = $true)][string]$PromptText,
        [Parameter(Mandatory = $true)][scriptblock]$GetRefs
    )

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        Write-Warning 'git no esta disponible en PATH; se omite el selector de checkout.'
        return
    }

    $items = @(& $GetRefs) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if (-not $items) {
        Write-Host "No se encontraron elementos Git de tipo $RefKind." -ForegroundColor Yellow
        return
    }

    $selection = Invoke-FzfSelection -Items $items -PromptText $PromptText
    if (-not $selection) {
        return
    }

    $selectedRef = if ($selection -is [System.Array]) { $selection[0] } else { $selection }
    if ([string]::IsNullOrWhiteSpace($selectedRef)) {
        return
    }

    if ($RefKind -eq 'branch') {
        git show-ref --verify --quiet "refs/remotes/$selectedRef"
        if ($LASTEXITCODE -eq 0 -and $selectedRef -match '^[^/]+/(?<branchName>.+)$') {
            $localBranchName = $Matches['branchName']

            git show-ref --verify --quiet "refs/heads/$localBranchName"
            if ($LASTEXITCODE -eq 0) {
                git checkout $localBranchName
            } else {
                git checkout --track $selectedRef
            }

            Invoke-PSReadLinePromptRefresh
            return
        }
    }

    git checkout $selectedRef
    Invoke-PSReadLinePromptRefresh
}

function Invoke-FzfGitCheckoutBranch {
    Invoke-FzfGitCheckoutRef -RefKind 'branch' -PromptText 'Branch Git >' -GetRefs {
        git branch --format='%(refname:short)' 2> $null |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    }
}

function Invoke-FzfGitCheckoutTag {
    Invoke-FzfGitCheckoutRef -RefKind 'tag' -PromptText 'Tag Git >' -GetRefs {
        git tag --sort=-creatordate 2> $null
    }
}

function Invoke-FzfGitCheckoutCommit {
    $commitItems = git log --oneline --decorate --color=always --max-count=200 2> $null
    if (-not $commitItems) {
        Write-Host 'No se encontraron commits Git.' -ForegroundColor Yellow
        return
    }

    $selection = Invoke-FzfSelection -Items $commitItems -PromptText 'Commit Git >'
    if (-not $selection) {
        return
    }

    $selectedLine = if ($selection -is [System.Array]) { $selection[0] } else { $selection }
    $cleanLine = $selectedLine -replace "`e\[[0-9;]*m", ''
    $commitHash = ($cleanLine -split '\s+')[0]
    if ([string]::IsNullOrWhiteSpace($commitHash)) {
        return
    }

    git checkout $commitHash
    Invoke-PSReadLinePromptRefresh
}

function Invoke-FzfHistoryInsert {
    $historyItems = Get-History |
        Sort-Object -Property Id -Descending |
        ForEach-Object { $_.CommandLine } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if (-not $historyItems) {
        Write-Host 'No se encontro historial de PowerShell.' -ForegroundColor Yellow
        return
    }

    $selection = Invoke-FzfSelection -Items $historyItems -PromptText 'Historial >'
    if (-not $selection) {
        return
    }

    $selectedCommand = if ($selection -is [System.Array]) { $selection[0] } else { $selection }
    Invoke-PSReadLineInsertText -Text $selectedCommand
}

function Get-FzfProcessItems {
    param(
        [switch]$CurrentUserOnly
    )

    $currentUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Get-Process -IncludeUserName -ErrorAction SilentlyContinue |
        Where-Object { -not $CurrentUserOnly -or $_.UserName -eq $currentUserName } |
        Sort-Object -Property ProcessName, Id |
        ForEach-Object {
            '{0,8}  {1,-30}  {2}' -f $_.Id, $_.ProcessName, $_.UserName
        }
}

function Select-FzfProcessId {
    param(
        [string]$PromptText = 'Process >',
        [switch]$CurrentUserOnly
    )

    $processItems = Get-FzfProcessItems -CurrentUserOnly:$CurrentUserOnly
    if (-not $processItems) {
        Write-Host 'No se encontraron procesos.' -ForegroundColor Yellow
        return $null
    }

    $selection = Invoke-FzfSelection -Items $processItems -PromptText $PromptText
    if (-not $selection) {
        return $null
    }

    $selectedProcessLine = if ($selection -is [System.Array]) { $selection[0] } else { $selection }
    if ($selectedProcessLine -match '^\s*(?<processId>\d+)\s+') {
        return [int]$Matches['processId']
    }

    return $null
}

function Invoke-FzfProcessKill {
    param(
        [switch]$CurrentUserOnly
    )

    $processId = Select-FzfProcessId -PromptText 'Matar proceso >' -CurrentUserOnly:$CurrentUserOnly
    if (-not $processId) {
        return
    }

    try {
        Stop-Process -Id $processId -Force -ErrorAction Stop
        Write-Host "Proceso terminado: $processId" -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo terminar el proceso '$processId': $($_.Exception.Message)"
    }
}

function Invoke-FzfProcessIdCopy {
    $processId = Select-FzfProcessId -PromptText 'Copiar process id >'
    if (-not $processId) {
        return
    }

    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
        Set-Clipboard -Value $processId
        Write-Host "Process id copiado: $processId" -ForegroundColor Green
        return
    }

    Invoke-PSReadLineInsertText -Text ([string]$processId)
}

function Invoke-FzfWidgetSelector {
    $widgetItems = @(
        'Ctrl+b           Checkout de branch Git',
        'Ctrl+x,Ctrl+w    Repositorio GHQ work',
        'Ctrl+x,Ctrl+p    Repositorio GHQ projects',
        'Ctrl+x,Ctrl+g    Repositorio GHQ global',
        'Ctrl+h           Insertar comando del historial',
        'Ctrl+t           Checkout de tag Git',
        'Ctrl+g,c         Checkout de commit Git',
        'Ctrl+x,k         Terminar proceso del usuario actual',
        'Ctrl+x,r         Terminar proceso',
        'Ctrl+x,p         Copiar process id',
        'Alt+e            Editar linea actual'
    )

    $selection = Invoke-FzfSelection -Items $widgetItems -PromptText 'Widget >'
    if ($selection) {
        Write-Host $selection
    }
}

function Split-EditorCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine
    )

    [regex]::Matches($CommandLine, "`"[^`"]*`"|'[^']*'|\S+") |
        ForEach-Object {
            $commandPart = $_.Value
            if (($commandPart.StartsWith('"') -and $commandPart.EndsWith('"')) -or
                ($commandPart.StartsWith("'") -and $commandPart.EndsWith("'"))) {
                $commandPart.Substring(1, $commandPart.Length - 2)
            } else {
                $commandPart
            }
        }
}

function Invoke-ConfiguredEditor {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $editorCommand = if ($env:EDITOR) { $env:EDITOR } elseif ($env:VISUAL) { $env:VISUAL } else { 'notepad' }
    $editorCommandParts = @(Split-EditorCommand -CommandLine $editorCommand)
    if (-not $editorCommandParts) {
        Write-Warning 'No se pudo resolver el editor configurado.'
        return
    }

    $editorExecutable = $editorCommandParts[0]
    $editorArguments = @($editorCommandParts | Select-Object -Skip 1)
    $editorName = [System.IO.Path]::GetFileNameWithoutExtension($editorExecutable)
    if ($editorName -in @('code', 'code-insiders', 'codium') -and $editorArguments -notcontains '--wait') {
        $editorArguments += '--wait'
    }

    & $editorExecutable @editorArguments $Path
}

function Invoke-PSReadLineEditCurrentLine {
    $psConsoleReadLineType = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
    if (-not $psConsoleReadLineType) {
        return
    }

    $line = $null
    $cursor = $null
    try {
        $psConsoleReadLineType::GetBufferState([ref]$line, [ref]$cursor)
    } catch {
        return
    }

    $temporaryFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $temporaryFile -Value $line -NoNewline -Encoding UTF8
        Invoke-ConfiguredEditor -Path $temporaryFile
        $editedLine = Get-Content -LiteralPath $temporaryFile -Raw
        if ($null -ne $editedLine) {
            $editedLine = $editedLine.TrimEnd("`r", "`n")
            $psConsoleReadLineType::RevertLine()
            $psConsoleReadLineType::Insert($editedLine)
        }
    } finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

function Set-PSReadLineAcceptSuggestionKeyHandler {
    try {
        Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function AcceptSuggestion -ErrorAction Stop
    } catch {
        Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
    }
}

#  ██████  ██   ██  ██████
# ██       ██   ██ ██    ██
# ██   ███ ███████ ██    ██
# ██    ██ ██   ██ ██ ▄▄ ██
#  ██████  ██   ██  ██████
#                      ▀▀

if (-not $script:GhqSelectionCacheTtlSeconds) {
    $script:GhqSelectionCacheTtlSeconds = 10
}

$script:GhqCommandInfoCache = $null
$script:FzfCommandInfoCache = $null
$script:GhqRootCache = $null
$script:GhqRootCacheTimestamp = $null
$script:GhqRepositoryListCache = $null
$script:GhqRepositoryListCacheTimestamp = $null
$script:GhqRepositoryListCacheRootFingerprint = $null
$script:GhqRepositoryScanDefaultExcludedDirectoryNames = @(
    '.cache',
    '.npm',
    '.pnpm-store',
    '.yarn',
    '.terraform',
    'node_modules'
)
$script:GhqRepositoryScanExcludedDirectoryNames = @()

function Test-CacheEntryIsFresh {
    param(
        [Nullable[datetime]]$Timestamp,
        [int]$TtlSeconds = 0
    )

    if (-not $Timestamp -or $TtlSeconds -le 0) {
        return $false
    }

    $elapsedSeconds = ([datetime]::UtcNow - $Timestamp).TotalSeconds
    return $elapsedSeconds -lt $TtlSeconds
}

function Get-CachedGhqCommandInfo {
    if ($script:GhqCommandInfoCache) {
        return $script:GhqCommandInfoCache
    }

    $script:GhqCommandInfoCache = Get-Command ghq -ErrorAction SilentlyContinue
    return $script:GhqCommandInfoCache
}

function Get-CachedFzfCommandInfo {
    if ($script:FzfCommandInfoCache) {
        return $script:FzfCommandInfoCache
    }

    $script:FzfCommandInfoCache = Get-Command fzf -ErrorAction SilentlyContinue
    return $script:FzfCommandInfoCache
}

function Get-GhqRepositoryScanExcludedDirectoryNames {
    $excludedDirectoryNames = [System.Collections.Generic.List[string]]::new()
    $seenExcludedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($defaultExcludedDirectoryName in $script:GhqRepositoryScanDefaultExcludedDirectoryNames) {
        if ([string]::IsNullOrWhiteSpace($defaultExcludedDirectoryName)) { continue }
        if ($seenExcludedNames.Add($defaultExcludedDirectoryName)) {
            $excludedDirectoryNames.Add($defaultExcludedDirectoryName)
        }
    }

    $environmentExcludedDirectoryNames = [Environment]::GetEnvironmentVariable('GHQ_SCAN_EXCLUDES')
    if (-not [string]::IsNullOrWhiteSpace($environmentExcludedDirectoryNames)) {
        $tokens = $environmentExcludedDirectoryNames -split '[,;]'
        foreach ($token in $tokens) {
            $trimmedToken = $token.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmedToken)) { continue }
            if ($seenExcludedNames.Add($trimmedToken)) {
                $excludedDirectoryNames.Add($trimmedToken)
            }
        }
    }

    return @($excludedDirectoryNames)
}

function Test-ShouldSkipGhqScanDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryName
    )

    foreach ($excludedName in $script:GhqRepositoryScanExcludedDirectoryNames) {
        if ($DirectoryName -ieq $excludedName) {
            return $true
        }
    }

    return $false
}

function Test-IsReparsePointDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [object]$DirectoryInfo
    )

    if ($null -eq $DirectoryInfo -or $null -eq $DirectoryInfo.Attributes) {
        return $false
    }

    return [bool]($DirectoryInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Test-IsBareGitRepositoryDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    $headFilePath = Join-Path $DirectoryPath 'HEAD'
    $objectsDirectoryPath = Join-Path $DirectoryPath 'objects'
    $refsDirectoryPath = Join-Path $DirectoryPath 'refs'

    if (-not (Test-Path -LiteralPath $headFilePath -PathType Leaf)) {
        return $false
    }
    if (-not (Test-Path -LiteralPath $objectsDirectoryPath -PathType Container)) {
        return $false
    }
    if (-not (Test-Path -LiteralPath $refsDirectoryPath -PathType Container)) {
        return $false
    }

    return $true
}

function Test-IsGitRepositoryDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    if (Test-Path -LiteralPath (Join-Path $DirectoryPath '.git')) {
        return $true
    }

    return (Test-IsBareGitRepositoryDirectory -DirectoryPath $DirectoryPath)
}

function Get-RelativePathCompat {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if ([System.IO.Path].GetMethod('GetRelativePath', [type[]]@([string], [string]))) {
        return [System.IO.Path]::GetRelativePath($BasePath, $TargetPath)
    }

    $resolvedBasePath = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\', '/')
    $resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path

    $baseUri = New-Object System.Uri(($resolvedBasePath -replace '\\', '/') + '/')
    $targetUri = New-Object System.Uri(($resolvedTargetPath -replace '\\', '/'))
    $relativeUri = $baseUri.MakeRelativeUri($targetUri).ToString()
    return [System.Uri]::UnescapeDataString($relativeUri) -replace '/', '\'
}

function Get-GhqRootFingerprint {
    param(
        [string]$RootPath
    )

    if ([string]::IsNullOrWhiteSpace($RootPath) -or -not (Test-Path -LiteralPath $RootPath)) {
        return $null
    }

    try {
        $rootDirectoryItem = Get-Item -LiteralPath $RootPath -ErrorAction Stop
        $topLevelDirectories = @(Get-ChildItem -LiteralPath $RootPath -Directory -ErrorAction SilentlyContinue)
        $topLevelDirectoryCount = $topLevelDirectories.Count
        $secondLevelDirectoryCount = 0
        $maxObservedTicks = $rootDirectoryItem.LastWriteTimeUtc.Ticks
        foreach ($directory in $topLevelDirectories) {
            $directoryTicks = $directory.LastWriteTimeUtc.Ticks
            if ($directoryTicks -gt $maxObservedTicks) {
                $maxObservedTicks = $directoryTicks
            }

            $secondLevelDirectories = @(Get-ChildItem -LiteralPath $directory.FullName -Directory -ErrorAction SilentlyContinue)
            $secondLevelDirectoryCount += $secondLevelDirectories.Count
            foreach ($secondLevelDirectory in $secondLevelDirectories) {
                $secondLevelDirectoryTicks = $secondLevelDirectory.LastWriteTimeUtc.Ticks
                if ($secondLevelDirectoryTicks -gt $maxObservedTicks) {
                    $maxObservedTicks = $secondLevelDirectoryTicks
                }
            }
        }

        return '{0}:{1}:{2}:{3}' -f $rootDirectoryItem.LastWriteTimeUtc.Ticks, $topLevelDirectoryCount, $secondLevelDirectoryCount, $maxObservedTicks
    } catch {
        return $null
    }
}

function Get-CachedGhqRepositoryList {
    $ghqRootPath = Get-CachedGhqRootPath
    $rootFingerprint = Get-GhqRootFingerprint -RootPath $ghqRootPath
    $isFresh = Test-CacheEntryIsFresh -Timestamp $script:GhqRepositoryListCacheTimestamp -TtlSeconds $script:GhqSelectionCacheTtlSeconds
    if ($isFresh -and $script:GhqRepositoryListCache -and $script:GhqRepositoryListCacheRootFingerprint -eq $rootFingerprint) {
        return $script:GhqRepositoryListCache
    }

    $ghqCommand = Get-CachedGhqCommandInfo
    if (-not $ghqCommand) {
        return $null
    }

    $script:GhqRepositoryScanExcludedDirectoryNames = Get-GhqRepositoryScanExcludedDirectoryNames
    $repoItems = [System.Collections.Generic.List[string]]::new()
    $repoItemSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if (-not [string]::IsNullOrWhiteSpace($ghqRootPath) -and (Test-Path -LiteralPath $ghqRootPath)) {
        try {
            $pendingDirectories = [System.Collections.Generic.Stack[string]]::new()
            foreach ($directory in (Get-ChildItem -LiteralPath $ghqRootPath -Directory -ErrorAction SilentlyContinue)) {
                if (Test-ShouldSkipGhqScanDirectory -DirectoryName $directory.Name) { continue }
                if (Test-IsReparsePointDirectory -DirectoryInfo $directory) { continue }
                $pendingDirectories.Push($directory.FullName)
            }

            while ($pendingDirectories.Count -gt 0) {
                $currentDirectoryPath = $pendingDirectories.Pop()
                if (Test-IsGitRepositoryDirectory -DirectoryPath $currentDirectoryPath) {
                    $relativePath = Get-RelativePathCompat -BasePath $ghqRootPath -TargetPath $currentDirectoryPath
                    if (-not [string]::IsNullOrWhiteSpace($relativePath) -and $relativePath -ne '.') {
                        $normalizedRelativePath = ($relativePath -replace '\\', '/')
                        if ($repoItemSet.Add($normalizedRelativePath)) {
                            $repoItems.Add($normalizedRelativePath)
                        }
                    }
                    continue
                }

                foreach ($childDirectory in (Get-ChildItem -LiteralPath $currentDirectoryPath -Directory -ErrorAction SilentlyContinue)) {
                    if (Test-ShouldSkipGhqScanDirectory -DirectoryName $childDirectory.Name) { continue }
                    if (Test-IsReparsePointDirectory -DirectoryInfo $childDirectory) { continue }
                    $pendingDirectories.Push($childDirectory.FullName)
                }
            }
        } catch {
            Write-Warning "Failed to scan repositories under ghq root '$ghqRootPath': $_"
        }
    }

    if ($repoItems.Count -eq 0) {
        $repoList = & $ghqCommand.Source list 2> $null
        foreach ($repo in $repoList) {
            if (-not [string]::IsNullOrWhiteSpace($repo)) {
                $normalizedRepoPath = $repo.Trim()
                if ($repoItemSet.Add($normalizedRepoPath)) {
                    $repoItems.Add($normalizedRepoPath)
                }
            }
        }
    }

    if ($repoItems.Count -gt 1) {
        $uniqueRepoItems = $repoItems.ToArray()
        [Array]::Sort($uniqueRepoItems, [System.StringComparer]::OrdinalIgnoreCase)
        $repoItems = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $uniqueRepoItems) {
            $repoItems.Add($item)
        }
    }

    $script:GhqRepositoryListCache = @($repoItems)
    $script:GhqRepositoryListCacheTimestamp = [datetime]::UtcNow
    $script:GhqRepositoryListCacheRootFingerprint = $rootFingerprint
    return $script:GhqRepositoryListCache
}

function Get-CachedGhqRootPath {
    $isFresh = Test-CacheEntryIsFresh -Timestamp $script:GhqRootCacheTimestamp -TtlSeconds $script:GhqSelectionCacheTtlSeconds
    if ($isFresh -and -not [string]::IsNullOrWhiteSpace($script:GhqRootCache)) {
        return $script:GhqRootCache
    }

    $ghqCommand = Get-CachedGhqCommandInfo
    if (-not $ghqCommand) {
        return $null
    }

    $rootOutput = & $ghqCommand.Source root 2> $null
    foreach ($entry in $rootOutput) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            $script:GhqRootCache = $entry.Trim()
            $script:GhqRootCacheTimestamp = [datetime]::UtcNow
            return $script:GhqRootCache
        }
    }

    return $null
}

function Select-GhqRepositoryPath {
    param(
        [string]$PromptLabel = 'GHQ',
        [string]$DefaultQuery = ''
    )

    $ghqCommand = Get-CachedGhqCommandInfo
    if (-not $ghqCommand) {
        Write-Warning "ghq is not available on PATH; install it (for example, 'scoop install ghq')."
        return $null
    }

    $fzfCommand = Get-CachedFzfCommandInfo
    if (-not $fzfCommand) {
        Write-Warning 'fzf is not available on PATH; ghq picker requires fzf.'
        return $null
    }

    try {
        $items = Get-CachedGhqRepositoryList
    } catch {
        Write-Warning "Failed to execute 'ghq list': $_"
        return $null
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
        $primaryRoot = Get-CachedGhqRootPath
    } catch {
        Write-Warning "Failed to determine ghq root: $_"
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($primaryRoot)) {
        Write-Warning 'ghq root returned no paths.'
        return $null
    }

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

    $psConsoleReadLineType = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
    $didRevert = $false

    if ($psConsoleReadLineType) {
        try {
            $psConsoleReadLineType::RevertLine()
            $didRevert = $true
        } catch {
            $didRevert = $false
        }
    }

    Invoke-GhqRepositoryJump -PromptLabel $PromptLabel -DefaultQuery $DefaultQuery

    if ($psConsoleReadLineType) {
        try {
            if ($didRevert) {
                $psConsoleReadLineType::AcceptLine()
            } else {
                $invokePromptMethod = $psConsoleReadLineType.GetMethod('InvokePrompt', [Type[]]@())
                if ($invokePromptMethod) {
                    $psConsoleReadLineType::InvokePrompt()
                } else {
                    $psConsoleReadLineType::Repaint()
                }
            }
        } catch {
            try { $psConsoleReadLineType::Repaint() } catch { }
        }
    }
}

$psConsoleReadLineType = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
if ($psConsoleReadLineType) {
    Set-PSReadLineOption -EditMode Emacs

    Set-PSReadLineKeyHandler -Chord 'Ctrl+b' -BriefDescription 'Branch Git' -LongDescription 'Hace checkout de una branch Git seleccionada con fzf' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfGitCheckoutBranch
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+h' -BriefDescription 'Insertar Historial' -LongDescription 'Inserta un comando seleccionado desde el historial de PowerShell' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfHistoryInsert
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'Tag Git' -LongDescription 'Hace checkout de un tag Git seleccionado con fzf' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfGitCheckoutTag
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+g,c' -BriefDescription 'Commit Git' -LongDescription 'Hace checkout de un commit Git seleccionado con fzf' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfGitCheckoutCommit
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+g' -BriefDescription 'GHQ Global' -LongDescription 'Salta a un repositorio ghq excluyendo work/*' -ScriptBlock {
        param($key, $arg)
        Invoke-GhqKeyHandler -PromptLabel 'Global' -DefaultQuery '!work/ '
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+w' -BriefDescription 'GHQ Work' -LongDescription 'Salta a un repositorio ghq de work' -ScriptBlock {
        param($key, $arg)
        Invoke-GhqKeyHandler -PromptLabel 'Work' -DefaultQuery 'work/ !forks '
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+p' -BriefDescription 'GHQ Projects' -LongDescription 'Salta a un repositorio ghq de projects' -ScriptBlock {
        param($key, $arg)
        Invoke-GhqKeyHandler -PromptLabel 'Projects' -DefaultQuery 'projects/ '
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,k' -BriefDescription 'Terminar Proceso Usuario' -LongDescription 'Termina un proceso del usuario actual seleccionado con fzf' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfProcessKill -CurrentUserOnly
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,r' -BriefDescription 'Terminar Proceso' -LongDescription 'Termina un proceso seleccionado con fzf' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfProcessKill
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,p' -BriefDescription 'Copiar Process Id' -LongDescription 'Copia un process id seleccionado con fzf' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfProcessIdCopy
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+x,x' -BriefDescription 'Selector Widgets' -LongDescription 'Muestra los equivalentes copiados de mappings.zsh' -ScriptBlock {
        param($key, $arg)
        Invoke-FzfWidgetSelector
    }

    Set-PSReadLineKeyHandler -Chord 'End' -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord 'Home' -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord 'Alt+n' -Function NextHistory
    Set-PSReadLineKeyHandler -Chord 'Alt+p' -Function PreviousHistory
    Set-PSReadLineKeyHandler -Chord 'Ctrl+n' -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord 'Ctrl+p' -Function HistorySearchBackward
    Set-PSReadLineAcceptSuggestionKeyHandler
    Set-PSReadLineKeyHandler -Chord 'Alt+e' -BriefDescription 'Editar Linea' -LongDescription 'Edita la linea de comando actual en el editor configurado' -ScriptBlock {
        param($key, $arg)
        Invoke-PSReadLineEditCurrentLine
    }
}

# ██████  ██████   ██████  ███    ███ ██████  ████████
# ██   ██ ██   ██ ██    ██ ████  ████ ██   ██    ██
# ██████  ██████  ██    ██ ██ ████ ██ ██████     ██
# ██      ██   ██ ██    ██ ██  ██  ██ ██         ██
# ██      ██   ██  ██████  ██      ██ ██         ██

# --- Prompt murilasso para Oh My Posh ----------------------------------------
# Port del theme configs/zsh/.oh-my-zsh/themes/murilasso.zsh-theme. El render
# vive en murilasso.omp.json; aca solo se replica el cacheo async de PR/CI via
# `gh`, que Oh My Posh consume por env vars dentro de Set-PoshContext.

# Intervalos de refresco en background (mismos valores que el theme zsh).
$MURILASSO_PR_REFRESH_SECONDS = 30
$MURILASSO_CI_REFRESH_SECONDS = 120

# Estado in-memory para evitar lanzar fetches en cada render del prompt.
$global:MurilassoPromptState = @{
    Branch      = ''
    Repo        = ''
    PrLastFetch = [datetime]::MinValue
    CiKey       = ''
    CiLastFetch = [datetime]::MinValue
}

function Get-MurilassoCachePath {
    param([string]$Kind, [string]$Repo, [string]$Branch)

    $safeKey = ("{0}_{1}" -f $Repo, $Branch) -replace '[\\/:*?"<>| ]', '_'
    return Join-Path ([System.IO.Path]::GetTempPath()) (".murilasso_{0}_{1}" -f $Kind, $safeKey)
}

# Lanza `gh` en un background job (proceso hijo aislado; no bloquea el prompt)
# y vuelca el resultado al archivo de cache. Se usa Start-Job en vez de
# Start-ThreadJob porque `gh` no resuelve bien su contexto (auth/repo) desde un
# hilo secundario del mismo proceso. Limpia jobs ya terminados para no acumular.
function Start-MurilassoGhFetch {
    param([string]$Repo, [string]$CachePath, [string[]]$GhArgs)

    Get-Job -Name 'murilasso_fetch' -ErrorAction SilentlyContinue |
        Where-Object { $_.State -in 'Completed', 'Failed', 'Stopped' } |
        Remove-Job -Force -ErrorAction SilentlyContinue

    $null = Start-Job -Name 'murilasso_fetch' -ScriptBlock {
        param($repoPath, $cachePath, $ghArgs)

        Set-Location -LiteralPath $repoPath
        $output = & gh @ghArgs 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $output) {
            Set-Content -LiteralPath $cachePath -Value ($output -join "`n") -Encoding utf8 -NoNewline
        }
    } -ArgumentList $Repo, $CachePath, $GhArgs
}

# Lee el cache de PR (linea 1 = url, linea 2 = state) hacia env vars.
function Read-MurilassoPrCache {
    param([string]$CachePath)

    $lines = Get-Content -LiteralPath $CachePath -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $url = if ($lines.Count -ge 1) { ([string]$lines[0]).Trim() } else { '' }
    $prState = if ($lines.Count -ge 2) { ([string]$lines[1]).Trim() } else { '' }

    $env:MURILASSO_PR_URL = $url
    $env:MURILASSO_PR_STATE = $prState
    $env:MURILASSO_PR_NUMBER = if ($url) { ($url -split '/')[-1] } else { '' }
}

function Clear-MurilassoPrContext {
    $env:MURILASSO_PR_URL = ''
    $env:MURILASSO_PR_STATE = ''
    $env:MURILASSO_PR_NUMBER = ''
    $env:MURILASSO_PR_CI = ''
}

# Refresca el estado de CI del PR actual (cada 2 min o al cambiar de branch).
function Update-MurilassoCiContext {
    param([string]$Repo, [string]$Branch)

    if ([string]::IsNullOrEmpty($env:MURILASSO_PR_URL)) {
        $env:MURILASSO_PR_CI = ''
        return
    }

    $promptState = $global:MurilassoPromptState
    $ciKey = "${Repo}:${Branch}"
    $ciCache = Get-MurilassoCachePath -Kind 'ci' -Repo $Repo -Branch $Branch
    $now = Get-Date

    if ($ciKey -ne $promptState.CiKey -or
        ($now - $promptState.CiLastFetch).TotalSeconds -gt $MURILASSO_CI_REFRESH_SECONDS) {
        $promptState.CiKey = $ciKey
        $promptState.CiLastFetch = $now
        $ciQuery = 'if (.statusCheckRollup // [] | length) == 0 then "" elif .statusCheckRollup | any(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or .state == "FAILURE" or .state == "ERROR") then "FAILURE" elif .statusCheckRollup | any(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or .state == "PENDING") then "PENDING" else "SUCCESS" end'
        Start-MurilassoGhFetch -Repo $Repo -CachePath $ciCache -GhArgs @('pr', 'view', '--json', 'statusCheckRollup', '-q', $ciQuery)
    }

    if (Test-Path -LiteralPath $ciCache) {
        $ciStatus = Get-Content -LiteralPath $ciCache -Raw -ErrorAction SilentlyContinue
        if ($null -ne $ciStatus) { $env:MURILASSO_PR_CI = $ciStatus.Trim() }
    }
}

# Mantiene actualizadas las env vars de PR/CI que consume murilasso.omp.json.
function Update-MurilassoPromptContext {
    # Un solo spawn de git por render: rev-parse acepta ambos flags y devuelve
    # una línea por flag (branch primero, toplevel después).
    $gitPromptInfo = @(& git rev-parse --abbrev-ref HEAD --show-toplevel 2>$null)
    $branch = if ($gitPromptInfo.Count -ge 1) { $gitPromptInfo[0] } else { $null }
    $repo = if ($gitPromptInfo.Count -ge 2) { $gitPromptInfo[1] } else { $null }

    if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD' -or [string]::IsNullOrWhiteSpace($repo)) {
        Clear-MurilassoPrContext
        $global:MurilassoPromptState.Branch = ''
        $global:MurilassoPromptState.Repo = ''
        return
    }

    $branch = $branch.Trim()
    $repo = $repo.Trim()
    $promptState = $global:MurilassoPromptState
    $prCache = Get-MurilassoCachePath -Kind 'pr' -Repo $repo -Branch $branch
    $now = Get-Date

    if ($branch -ne $promptState.Branch -or $repo -ne $promptState.Repo) {
        # Cambio de branch/repo: reset, muestra cache si existe y lanza fetch.
        $promptState.Branch = $branch
        $promptState.Repo = $repo
        $promptState.PrLastFetch = $now
        Clear-MurilassoPrContext
        if (Test-Path -LiteralPath $prCache) { Read-MurilassoPrCache $prCache }
        Start-MurilassoGhFetch -Repo $repo -CachePath $prCache -GhArgs @('pr', 'view', '--json', 'url,state', '-q', '.url + "\n" + .state')
    }
    elseif ([string]::IsNullOrEmpty($env:MURILASSO_PR_URL) -and (Test-Path -LiteralPath $prCache)) {
        # El fetch en background termino: leer el resultado.
        Read-MurilassoPrCache $prCache
        $promptState.PrLastFetch = $now
    }
    elseif ($env:MURILASSO_PR_STATE -eq 'OPEN') {
        # Re-lee cache cada render (rapido) y re-fetchea cada 30s.
        if (Test-Path -LiteralPath $prCache) { Read-MurilassoPrCache $prCache }
        if (($now - $promptState.PrLastFetch).TotalSeconds -gt $MURILASSO_PR_REFRESH_SECONDS) {
            $promptState.PrLastFetch = $now
            Start-MurilassoGhFetch -Repo $repo -CachePath $prCache -GhArgs @('pr', 'view', '--json', 'url,state', '-q', '.url + "\n" + .state')
        }
    }

    Update-MurilassoCiContext -Repo $repo -Branch $branch
}

# $PSScriptRoot apunta a la carpeta del symlink, no a la del repo. El profile ya
# resolvió el link al inicio ($script:ProfileScriptDirectory); el theme vive
# junto al archivo real del profile.
$murilassoThemePath = Join-Path $script:ProfileScriptDirectory 'murilasso.omp.json'
$ohMyPoshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ohMyPoshCommand -and (Test-Path -LiteralPath $murilassoThemePath)) {
    # Cache del init de Oh My Posh: `oh-my-posh init pwsh | Invoke-Expression`
    # devuelve un one-liner que re-invoca el binario en cada arranque (~170 ms).
    # Se cachea el script real (salida de --print). El theme se lee en cada
    # render del prompt, así que editar murilasso.omp.json no requiere
    # regenerar; el binario de omp, el path del theme y la versión del
    # generador forman el fingerprint.
    $murilassoOmpInitCachePath = Join-Path $env:LOCALAPPDATA 'PowerShell\oh-my-posh-init-cache.ps1'
    $murilassoOmpInitialized = $false
    try {
        # 'inline-config-v1' versiona el generador de abajo: cambiar su lógica
        # debe bumpear el sufijo para invalidar caches ya generados.
        $murilassoOmpFingerprint = '{0}|{1}|inline-config-v1' -f (Get-ExecutableFingerprint -CommandInfo $ohMyPoshCommand), $murilassoThemePath
        . (Get-CachedInitScriptPath `
            -CachePath $murilassoOmpInitCachePath `
            -Fingerprint $murilassoOmpFingerprint `
            -GenerateScriptText {
                $ompInitScript = (& $ohMyPoshCommand.Source init pwsh --config $murilassoThemePath --print) -join [Environment]::NewLine

                # El script de --print NO embebe el config: `oh-my-posh init`
                # lo persiste en un mapping session-id -> config
                # (pwsh.<id>.omp.cache) que el render consulta via
                # POSH_SESSION_ID. Como este cache evita correr `init`, una
                # sesión con id nuevo no tendría mapping y el render caería al
                # theme default. Inyectar --config en cada invocación de render
                # hace el script autosuficiente.
                $shellFlagToken = '"--shell=$script:ShellName"'
                if (-not $ompInitScript.Contains($shellFlagToken)) {
                    throw "oh-my-posh --print output no longer contains the expected token $shellFlagToken; review the --config injection"
                }
                $ompInitScript.Replace($shellFlagToken, "'--config=$murilassoThemePath', $shellFlagToken")
            })

        # El script cacheado embebe el POSH_SESSION_ID de cuando se generó.
        # Regenerarlo da a cada sesión su propio scope de cache de omp; el
        # theme no depende del id porque el config va inline en cada render.
        $env:POSH_SESSION_ID = [guid]::NewGuid().ToString()
        $murilassoOmpInitialized = $true
    } catch {
        # Cache corrupto o invalidación fallida: descartarlo y caer al init en
        # vivo para no perder el prompt.
        Remove-Item -LiteralPath $murilassoOmpInitCachePath -Force -ErrorAction SilentlyContinue
        try {
            oh-my-posh init pwsh --config $murilassoThemePath | Invoke-Expression
            $murilassoOmpInitialized = $true
        } catch {
            Write-Warning "Unable to initialize Oh My Posh (murilasso): $($_.Exception.Message)"
        }
    }

    if ($murilassoOmpInitialized) {
        # El hook Set-PoshContext de Oh My Posh vive DENTRO de su modulo dinamico
        # `oh-my-posh-core` y su `prompt` resuelve esa version del modulo, no un
        # override global. Por eso envolvemos el `prompt` de OMP: guardamos su
        # scriptblock (queda ligado al scope del modulo) y definimos un `prompt`
        # global que corre nuestro updater de PR/CI ANTES de delegar en el de OMP,
        # de modo que las env vars ya esten seteadas cuando OMP renderiza.
        $global:MurilassoOmpPrompt = (Get-Command prompt).ScriptBlock
        function global:prompt {
            # El updater corre `git`/`gh`/`Start-Job` en cada render. Si una de
            # esas llamadas nativas lanza un error terminante (p.ej. queda un stop
            # pendiente tras un Ctrl+C), la excepcion escaparia de `prompt` y
            # PowerShell caeria a su prompt de fallback (`PS>`), perdiendo el theme.
            # Aislar el updater garantiza que siempre se delegue al render de OMP.
            try { Update-MurilassoPromptContext } catch { }
            & $global:MurilassoOmpPrompt
        }
    }
}
# --- Fin prompt murilasso ----------------------------------------------------
