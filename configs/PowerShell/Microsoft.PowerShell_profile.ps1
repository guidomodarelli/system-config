# ██████  ███████ ███████  █████  ██    ██ ██      ████████ ███████
# ██   ██ ██      ██      ██   ██ ██    ██ ██         ██    ██
# ██   ██ █████   █████   ███████ ██    ██ ██         ██    ███████
# ██   ██ ██      ██      ██   ██ ██    ██ ██         ██         ██
# ██████  ███████ ██      ██   ██  ██████  ███████    ██    ███████

# Console en UTF-8: sin esto [Console]::OutputEncoding queda en CP437 (OEM) y los
# glifos del prompt murilasso (╭─ ❯ y los iconos Nerd Font) salen como `?`, tanto
# en el render normal como cuando PSReadLine los repinta via InvokePrompt (p.ej.
# tras un checkout con el widget fzf).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# --- Cache de scripts de init/completion --------------------------------------
# Spawnear un CLI (Node, Go, Rust) para generar su script de init o completion
# cuesta 30-200 ms por arranque. Estos helpers cachean el script generado a
# disco y lo regeneran solo cuando cambia el fingerprint (primera línea del
# archivo). Definidos antes de cualquier init (zoxide, codex).

# Ejecutable real detrás de un comando. Los shims de scoop son un .exe genérico
# con un `<nombre>.shim` al lado (`path = "..."`); sin seguirlo, un
# `scoop update` no cambiaría el fingerprint. Usa APIs .NET porque Get-Item
# y Get-Content cuestan ~10 ms en su primer uso durante el arranque.
function Get-ExecutableTargetInfo {
    param([Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$CommandInfo)

    $executableInfo = [System.IO.FileInfo]::new($CommandInfo.Source)
    $shimFilePath = [System.IO.Path]::ChangeExtension($executableInfo.FullName, '.shim')
    if ([System.IO.File]::Exists($shimFilePath)) {
        foreach ($shimLine in [System.IO.File]::ReadAllLines($shimFilePath)) {
            if ($shimLine -match '^\s*path\s*=\s*"?([^"]+)"?\s*$') {
                $shimTargetInfo = [System.IO.FileInfo]::new($Matches[1])
                if ($shimTargetInfo.Exists) { return $shimTargetInfo }
            }
        }
    }

    return $executableInfo
}

# Destino final de un symlink/junction, o $null si el item no es un link.
# ResolveLinkTarget es .NET 6+ (PowerShell 7); Windows PowerShell 5.1 solo
# expone las propiedades ETS `LinkType`/`Target`, así que ahí se sigue a mano.
function Resolve-FileSystemLinkTarget {
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$Item)

    if ($Item.PSObject.Methods['ResolveLinkTarget']) {
        return $Item.ResolveLinkTarget($true)
    }

    if ($Item.LinkType -notin 'SymbolicLink', 'Junction') { return $null }

    $currentItem = $Item
    for ($depth = 0; $depth -lt 32 -and $currentItem.LinkType -in 'SymbolicLink', 'Junction'; $depth++) {
        $linkTarget = @($currentItem.Target)[0]
        if (-not $linkTarget) { return $null }
        if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
            $linkTarget = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($currentItem.FullName), $linkTarget)
        }
        $currentItem = Get-Item -LiteralPath $linkTarget -Force -ErrorAction SilentlyContinue
        if (-not $currentItem) { return $null }
    }
    return $currentItem
}

# Path estable del ejecutable de un comando: si su directorio es un link (p.ej.
# los multishell dirs por sesión de fnm o `current` de scoop), se resuelve al
# directorio real para que el fingerprint no cambie entre sesiones.
function Get-StableExecutablePath {
    param([Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$CommandInfo)

    $executableInfo = Get-ExecutableTargetInfo -CommandInfo $CommandInfo
    if (-not $executableInfo.Exists) {
        return $CommandInfo.Source
    }

    $executableDirectoryInfo = $executableInfo.Directory
    # LinkTarget no existe en .NET Framework (5.1); ahí se recurre a la propiedad ETS LinkType.
    $directoryIsLink = if ($executableDirectoryInfo -and $executableDirectoryInfo.PSObject.Properties['LinkTarget']) {
        [bool]$executableDirectoryInfo.LinkTarget
    } else {
        $executableDirectoryInfo -and $executableDirectoryInfo.LinkType
    }
    if ($directoryIsLink) {
        $resolvedDirectory = Resolve-FileSystemLinkTarget -Item $executableDirectoryInfo
        if ($resolvedDirectory) {
            return [System.IO.Path]::Combine($resolvedDirectory.FullName, $executableInfo.Name)
        }
    }

    return $executableInfo.FullName
}

# Fingerprint "path estable|mtime ticks" del ejecutable de un comando.
function Get-ExecutableFingerprint {
    param([Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$CommandInfo)

    $executableInfo = Get-ExecutableTargetInfo -CommandInfo $CommandInfo
    $executableTicks = if ($executableInfo.Exists) { $executableInfo.LastWriteTimeUtc.Ticks } else { 0 }
    return '{0}|{1}' -f (Get-StableExecutablePath -CommandInfo $CommandInfo), $executableTicks
}

# Cada instalación conserva su propio init: fnm puede alternar versiones de Node
# entre terminales y un cache compartido se invalidaría en cada arranque.
# La ruta estable mantiene el mismo archivo entre los multishell links de fnm;
# el fingerprint sigue invalidándolo cuando se actualiza ese ejecutable.
function Get-ExecutableInitCachePath {
    param(
        [Parameter(Mandatory = $true)][string]$CachePath,
        [Parameter(Mandatory = $true)][System.Management.Automation.CommandInfo]$CommandInfo
    )

    $stableExecutablePath = Get-StableExecutablePath -CommandInfo $CommandInfo
    $executablePathBytes = [System.Text.Encoding]::UTF8.GetBytes($stableExecutablePath)
    $pathHasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $executablePathHash = [System.BitConverter]::ToString($pathHasher.ComputeHash($executablePathBytes)).Replace('-', '')
    } finally {
        $pathHasher.Dispose()
    }
    $cacheFileName = '{0}-{1}{2}' -f [System.IO.Path]::GetFileNameWithoutExtension($CachePath), $executablePathHash, [System.IO.Path]::GetExtension($CachePath)
    return [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($CachePath), $cacheFileName)
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
    $cacheIsFresh = $false
    if ([System.IO.File]::Exists($CachePath)) {
        $cacheReader = [System.IO.StreamReader]::new($CachePath)
        try {
            $cacheIsFresh = $cacheReader.ReadLine() -eq $fingerprintLine
        } finally {
            $cacheReader.Dispose()
        }
    }

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

$script:ZoxideCommandInfo = Get-Command zoxide -ErrorAction SilentlyContinue
$script:ZoxideInitialized = $false

# Se carga al usar z/zi, para que el primer prompt no pague su inicialización.
function Initialize-Zoxide {
    if ($script:ZoxideInitialized) { return $true }
    if (-not $script:ZoxideCommandInfo) { return $false }

    try {
        # El hook `pwd` reemplazaría el `prompt` murilasso por un wrapper que
        # pisa $LASTEXITCODE con su `zoxide add`. Con `none`, el prompt murilasso
        # llama a __zoxide_hook después de capturar el estado del último comando.
        $zoxideInitArguments = @('init', 'powershell', '--hook', 'none')
        . (Get-CachedInitScriptPath `
            -CachePath (Join-Path $env:LOCALAPPDATA 'PowerShell\zoxide-init-cache.ps1') `
            -Fingerprint ('{0}|{1}' -f (Get-ExecutableFingerprint -CommandInfo $script:ZoxideCommandInfo), ($zoxideInitArguments -join ' ')) `
            -GenerateScriptText { (& $script:ZoxideCommandInfo.Source @zoxideInitArguments) -join [Environment]::NewLine })
        $script:ZoxideInitialized = $true
        return $true
    } catch {
        Write-Warning "No se pudo inicializar zoxide: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-LazyZoxideJump {
    if (Initialize-Zoxide) { __zoxide_z @args }
}

function Invoke-LazyZoxideInteractiveJump {
    if (Initialize-Zoxide) { __zoxide_zi @args }
}

if ($script:ZoxideCommandInfo) {
    Set-Alias -Name z -Value Invoke-LazyZoxideJump -Option AllScope -Scope Global -Force
    Set-Alias -Name zi -Value Invoke-LazyZoxideInteractiveJump -Option AllScope -Scope Global -Force
}

$script:FnmCommandInfo = Get-Command fnm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$script:FnmInitialized = $false
$script:FnmInitializationAttempted = $false

# Respeta FNM_DIR y la preferencia de fnm por la instalación moderna o legacy.
function Get-FnmDataDirectory {
    param(
        [string]$UserDataDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData),
        [string]$UserHomeDirectory = $HOME
    )

    if ($env:FNM_DIR) { return $env:FNM_DIR }
    $modernDirectory = [System.IO.Path]::Combine($UserDataDirectory, 'fnm')
    if ([System.IO.Directory]::Exists($modernDirectory)) { return $modernDirectory }
    $legacyDirectory = [System.IO.Path]::Combine($UserHomeDirectory, '.fnm')
    if ([System.IO.Directory]::Exists($legacyDirectory)) { return $legacyDirectory }
    return $modernDirectory
}

# Node permanece disponible antes del primer cd incluso en una instalación nueva.
# Se agrega al final para conservar la versión heredada de una terminal padre.
function Add-FnmDefaultNodeDirectoryToPath {
    param([Parameter(Mandatory = $true)][string]$FnmDirectory)

    $defaultNodeDirectory = [System.IO.Path]::Combine($FnmDirectory, 'aliases', 'default')
    if ([System.IO.Directory]::Exists($defaultNodeDirectory) -and
        ($env:PATH -split [System.IO.Path]::PathSeparator) -notcontains $defaultNodeDirectory) {
        $env:PATH = "$env:PATH$([System.IO.Path]::PathSeparator)$defaultNodeDirectory"
    }
}

# El PATH heredado permite usar Node desde el arranque. El multishell propio se
# crea antes del primer cd o comando fnm, evitando mutar el multishell del padre.
function Initialize-FnmEnvironment {
    if ($script:FnmInitialized) { return $true }
    if ($script:FnmInitializationAttempted) { return $false }
    if (-not $script:FnmCommandInfo) { return $false }
    $script:FnmInitializationAttempted = $true

    $fnmEnvironmentScript = (& $script:FnmCommandInfo.Source env --use-on-cd --shell powershell 2>$null) -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($fnmEnvironmentScript)) {
        Write-Verbose 'Perfil: fnm env no devolvió un script; se omite su inicialización.'
        return $false
    }
    Invoke-Expression $fnmEnvironmentScript
    $script:FnmInitialized = $true
    return $true
}

if ($script:FnmCommandInfo) {
    $fnmDirectory = Get-FnmDataDirectory
    Add-FnmDefaultNodeDirectoryToPath -FnmDirectory $fnmDirectory

    function global:Set-LocationWithFnm {
        param($path)

        if (Initialize-FnmEnvironment) {
            # fnm reemplaza esta función por su implementación oficial.
            & (Get-Command Set-LocationWithFnm -CommandType Function).ScriptBlock @PSBoundParameters
        } elseif ($null -eq $path) {
            Set-Location
        } else {
            Set-Location $path
        }
    }

    function fnm {
        $null = Initialize-FnmEnvironment
        & $script:FnmCommandInfo.Source @args
    }

    Set-Alias -Name cd_with_fnm -Value Set-LocationWithFnm -Scope Global
    Set-Alias -Name cd -Value Set-LocationWithFnm -Option AllScope -Scope Global -Force
}

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
    Resolve-FileSystemLinkTarget -Item $script:ProfileScriptItem
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

# Skill invoked by `cx --commit` (resolved by Codex from its skill catalog).
$script:CxCommitSkillPrompt = '$generate-commit-messages'
# Defaults for `cx --commit`; explicit -m/-re flags still take precedence.
$script:CxCommitModel = 'gpt-6-luna'
$script:CxCommitReasoning = 'max'
# Official installer used by `cx upgrade`: installs Codex or upgrades an existing install.
$script:CxCodexInstallerUri = 'https://chatgpt.com/codex/install.ps1'

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
        # PowerShell-only behavior: upgrade Codex with the official installer.
        # A child Windows PowerShell with Bypass runs it regardless of this session's execution policy.
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm $script:CxCodexInstallerUri | iex"
        return
    }

    $model = 'gpt-6.1-sol'
    $reasoning = 'medium'
    $modelOverridden = $false
    $reasoningOverridden = $false
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
                    $modelOverridden = $true
                    $i++
                }
            }
            '-re' {
                if ($i + 1 -lt $cliArgs.Count) {
                    $reasoning = $cliArgs[$i + 1]
                    $reasoningOverridden = $true
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
        if (-not $modelOverridden) { $model = $script:CxCommitModel }
        if (-not $reasoningOverridden) { $reasoning = $script:CxCommitReasoning }
        $yolo = $true
        $promptMode = $true
        $codexArgs.Clear()
        $promptArgs.Clear()
        $promptArgs.Add($script:CxCommitSkillPrompt)
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

$script:CodexCompletionInitialized = $false
$script:CodexCompletionAttempted = $false

# La primera solicitud de autocompletado carga y registra el completer oficial.
function Initialize-CodexCompletion {
    if ($script:CodexCompletionInitialized) { return $true }
    if ($script:CodexCompletionAttempted) { return $false }
    $script:CodexCompletionAttempted = $true
    $codexCommandInfo = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $codexCommandInfo) { return $false }

    try {
        # Cache por instalación: sesiones con distintas versiones de Node no
        # deben invalidarse entre sí y volver a spawnear el CLI en cada arranque.
        $codexCompletionCachePath = Get-ExecutableInitCachePath `
            -CachePath (Join-Path $env:LOCALAPPDATA 'PowerShell\codex-completion-cache.ps1') `
            -CommandInfo $codexCommandInfo
        . (Get-CachedInitScriptPath `
            -CachePath $codexCompletionCachePath `
            -Fingerprint (Get-ExecutableFingerprint -CommandInfo $codexCommandInfo) `
            -GenerateScriptText { (& $codexCommandInfo.Source completion powershell) -join [Environment]::NewLine })
        $script:CodexCompletionInitialized = $true
        return $true
    } catch {
        Write-Warning "No se pudo cargar el autocompletado de Codex: $($_.Exception.Message)"
        return $false
    }
}

function Register-LazyCodexCompletion {
    # Registrar otra vez permite reintentar explícitamente después de corregir un fallo.
    $script:CodexCompletionInitialized = $false
    $script:CodexCompletionAttempted = $false
    Register-ArgumentCompleter -Native -CommandName 'codex' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        if (-not (Initialize-CodexCompletion)) { return }
        # Se vuelve a completar con el registro oficial, conservando el texto
        # completo y su cursor, incluso después de un pipe o un punto y coma.
        $fullInput = $commandAst.Extent.StartScriptPosition.GetFullScript()
        [System.Management.Automation.CommandCompletion]::CompleteInput($fullInput, $cursorPosition, $null).CompletionMatches
    }
}

$codexCommandInfo = Get-Command codex -ErrorAction SilentlyContinue
if ($codexCommandInfo) {
    Register-LazyCodexCompletion

    $cxCompletionScriptBlock = {
        param($wordToComplete, $commandAst, $cursorPosition)

        $wrapperFlags = @(
            @{ Text = '-m'; List = '-m'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Modelo a usar' }
            @{ Text = '-re'; List = '-re'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Esfuerzo de razonamiento del modelo' }
            @{ Text = '-c'; List = '-c'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Invoca la skill generate-commit-messages (gpt-6-luna / max)' }
            @{ Text = '--commit'; List = '--commit'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Invoca la skill generate-commit-messages (gpt-6-luna / max)' }
            @{ Text = '--mcps'; List = '--mcps'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Compatibilidad: los servidores MCP ya están activos por defecto' }
            @{ Text = '--no-mcps'; List = '--no-mcps'; Type = [System.Management.Automation.CompletionResultType]::ParameterName; Tip = 'Desactiva los servidores MCP para esta ejecución' }
            @{ Text = 'upgrade'; List = 'upgrade'; Type = [System.Management.Automation.CompletionResultType]::ParameterValue; Tip = 'Actualiza Codex desde el wrapper' }
        )
        $modelOptions = @(
            'gpt-6.1-sol',
            'gpt-6-luna'
        )
        $reasoningOptions = @('low', 'medium', 'high', 'xhigh', 'max')

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

    # Sin BOM: Set-Content -Encoding UTF8 lo agrega en Windows PowerShell 5.1.
    $patchPath = Join-Path (Get-Location).ProviderPath $patchFile
    [System.IO.File]::WriteAllText($patchPath, (@($diffOutput) -join [Environment]::NewLine) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
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
    $cleanLine = $selectedLine -replace "$([char]27)\[[0-9;]*m", ''
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

# La huella de Get-GhqRootFingerprint invalida la lista al clonar o borrar repos,
# así que el TTL solo acota cambios que la huella no detecta (por ejemplo, git init anidado).
if (-not $script:GhqSelectionCacheTtlSeconds) {
    $script:GhqSelectionCacheTtlSeconds = 300
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

    # APIs .NET directas: Test-Path/Join-Path pesan demasiado cuando se llaman por cada directorio escaneado.
    return [System.IO.File]::Exists([System.IO.Path]::Combine($DirectoryPath, 'HEAD')) -and
        [System.IO.Directory]::Exists([System.IO.Path]::Combine($DirectoryPath, 'objects')) -and
        [System.IO.Directory]::Exists([System.IO.Path]::Combine($DirectoryPath, 'refs'))
}

function Test-IsGitRepositoryDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    $gitEntryPath = [System.IO.Path]::Combine($DirectoryPath, '.git')
    if ([System.IO.Directory]::Exists($gitEntryPath) -or [System.IO.File]::Exists($gitEntryPath)) {
        return $true
    }

    return (Test-IsBareGitRepositoryDirectory -DirectoryPath $DirectoryPath)
}

function Get-ChildDirectoryInfos {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$DirectoryInfo
    )

    # Equivalente rápido de Get-ChildItem -Directory -ErrorAction SilentlyContinue.
    try {
        return @($DirectoryInfo.GetDirectories())
    } catch {
        return @()
    }
}

function Get-GhqRootFingerprint {
    param(
        [string]$RootPath
    )

    if ([string]::IsNullOrWhiteSpace($RootPath) -or -not [System.IO.Directory]::Exists($RootPath)) {
        return $null
    }

    try {
        $rootDirectoryItem = [System.IO.DirectoryInfo]::new($RootPath)
        $topLevelDirectories = @(Get-ChildDirectoryInfos -DirectoryInfo $rootDirectoryItem)
        $topLevelDirectoryCount = $topLevelDirectories.Count
        $secondLevelDirectoryCount = 0
        $maxObservedTicks = $rootDirectoryItem.LastWriteTimeUtc.Ticks
        foreach ($directory in $topLevelDirectories) {
            $directoryTicks = $directory.LastWriteTimeUtc.Ticks
            if ($directoryTicks -gt $maxObservedTicks) {
                $maxObservedTicks = $directoryTicks
            }

            $secondLevelDirectories = @(Get-ChildDirectoryInfos -DirectoryInfo $directory)
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
    if (-not [string]::IsNullOrWhiteSpace($ghqRootPath) -and [System.IO.Directory]::Exists($ghqRootPath)) {
        try {
            $excludedDirectoryNameSet = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]$script:GhqRepositoryScanExcludedDirectoryNames,
                [System.StringComparer]::OrdinalIgnoreCase
            )
            $rootDirectoryInfo = [System.IO.DirectoryInfo]::new($ghqRootPath)
            # Todas las rutas escaneadas cuelgan del root, así que la relativa sale de recortar su prefijo.
            $rootPrefixLength = $rootDirectoryInfo.FullName.TrimEnd('\', '/').Length + 1
            $pendingDirectories = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
            $pendingDirectories.Push($rootDirectoryInfo)

            while ($pendingDirectories.Count -gt 0) {
                $currentDirectory = $pendingDirectories.Pop()
                $isRootDirectory = [object]::ReferenceEquals($currentDirectory, $rootDirectoryInfo)
                if (-not $isRootDirectory -and (Test-IsGitRepositoryDirectory -DirectoryPath $currentDirectory.FullName)) {
                    $normalizedRelativePath = $currentDirectory.FullName.Substring($rootPrefixLength).Replace('\', '/')
                    if ($repoItemSet.Add($normalizedRelativePath)) {
                        $repoItems.Add($normalizedRelativePath)
                    }
                    continue
                }

                foreach ($childDirectory in @(Get-ChildDirectoryInfos -DirectoryInfo $currentDirectory)) {
                    if ($excludedDirectoryNameSet.Contains($childDirectory.Name)) { continue }
                    if (Test-IsReparsePointDirectory -DirectoryInfo $childDirectory) { continue }
                    $pendingDirectories.Push($childDirectory)
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

    # Con GHQ_ROOT definido, `ghq root` devuelve su primera entrada; leerla evita lanzar el proceso.
    # Las rutas relativas o con `~` quedan para ghq, que sabe expandirlas.
    $environmentGhqRoot = [Environment]::GetEnvironmentVariable('GHQ_ROOT')
    if (-not [string]::IsNullOrWhiteSpace($environmentGhqRoot)) {
        $primaryEnvironmentRoot = ($environmentGhqRoot -split [regex]::Escape([System.IO.Path]::PathSeparator))[0].Trim()
        if ([System.IO.Path]::IsPathRooted($primaryEnvironmentRoot)) {
            $script:GhqRootCache = $primaryEnvironmentRoot
            $script:GhqRootCacheTimestamp = [datetime]::UtcNow
            return $script:GhqRootCache
        }
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

# --- Prompt murilasso --------------------------------------------------------
# Port nativo del theme configs/zsh/.oh-my-zsh/themes/murilasso.zsh-theme, sin
# Oh My Posh: `prompt` arma con secuencias ANSI las dos líneas, el bloque
# derecho (duración, Node, exit status y hora) y el prompt de continuación.
# El estado de PR/CI se cachea en background via `gh`.
#
# Línea 1: ╭─ [venv] usuario[@host]:path — branch [operación] [ahead/behind]
#          [cambios] [stash] — PR #N CI ............ [duración] [node] [exit] hora
# Línea 2: ╰─ [jobs] ❯

# Intervalos de refresco en background (mismos valores que el theme zsh).
$MURILASSO_PR_REFRESH_SECONDS = 30
$MURILASSO_CI_REFRESH_SECONDS = 120
# Tiempo máximo de un fetch de `gh` antes de matarlo y permitir reintentos.
$MURILASSO_GH_FETCH_TIMEOUT_SECONDS = 60

# Duración mínima de un comando para mostrarla en el bloque derecho.
$MURILASSO_DURATION_THRESHOLD_MS = 3000
$MURILASSO_MILLISECONDS_PER_SECOND = 1000
$MURILASSO_MILLISECONDS_PER_MINUTE = 60000
$MURILASSO_MILLISECONDS_PER_HOUR = 3600000
$MURILASSO_TIME_FORMAT = 'HH:mm:ss'
# Branches más largas se truncan con «…» para no desbordar la línea.
$MURILASSO_BRANCH_MAX_LENGTH = 40
$MURILASSO_SHORT_SHA_LENGTH = 7
# Carpetas visibles al final del path; el resto se resume con `..`.
$MURILASSO_PATH_MAX_DEPTH = 2
# Columna libre al final de la primera línea: escribir en la última columna
# deja a algunas terminales con un wrap pendiente que duplica el salto de línea.
$MURILASSO_RIGHT_PROMPT_MARGIN = 1
$MURILASSO_RIGHT_SEGMENT_GAP = '  '

$MURILASSO_ESCAPE = [char]27
$MURILASSO_BELL = [char]7
# SGR (CSI ... m) y links OSC 8: no ocupan columnas en la terminal.
$MURILASSO_ANSI_SEQUENCE_PATTERN = '\x1b\[[0-9;]*m|\x1b\]8;;[^\x07]*\x07'

# Códigos SGR de foreground: nombres ANSI estándar y grises truecolor del theme.
$MURILASSO_COLORS = @{
    Blue         = '34'
    Cyan         = '36'
    Green        = '32'
    Magenta      = '35'
    Red          = '31'
    White        = '37'
    Yellow       = '33'
    BrightWhite  = '38;2;255;255;255'
    Frame        = '38;2;108;108;108'
    Untracked    = '38;2;128;128;128'
    Continuation = '38;2;138;138;138'
}

# Glifos por code point: los iconos Nerd Font viven en el área de uso privado
# y no se distinguen a simple vista en el código fuente.
$MURILASSO_GLYPHS = @{
    FrameTop     = [string][char]0x256D + [char]0x2500
    FrameBottom  = [string][char]0x2570 + [char]0x2500
    Separator    = [string][char]0x2014
    Ellipsis     = [string][char]0x2026
    PromptArrow  = [string][char]0x276F
    PromptRoot   = '#'
    Continuation = [string][char]0x203A
    PythonVenv   = [string][char]0xE73C
    Branch       = [string][char]0xE725
    Commit       = [string][char]0xF417
    Ahead        = [string][char]0xF062
    Behind       = [string][char]0xF063
    Conflict     = [string][char]0xF071
    Staged       = [string][char]0xF457
    Modified     = [string][char]0xF459
    Untracked    = [string][char]0xF128
    Clean        = [string][char]0xF00C
    Stash        = [string][char]0xF411
    PrDefault    = [string][char]0xF4DD
    PrOpen       = [string][char]0xF407
    PrMerged     = [string][char]0xF419
    PrClosed     = [string][char]0xF4DC
    CiSuccess    = [string][char]0xF00C
    CiFailure    = [string][char]0xF00D
    CiPending    = [string][char]0xF444
    CiUnknown    = [string][char]0xF10C
    Duration     = [string][char]0xF017
    Node         = [string][char]0xE718
    NodeMismatch = [string][char]0xF071
    ExitStatus   = [string][char]0xF057
    Jobs         = [string][char]0xF085
}

# Contadores de cambios de git en orden de render.
$MURILASSO_GIT_CHANGE_COUNTERS = @(
    @{ Key = 'Unmerged'; Glyph = 'Conflict'; Color = 'Red'; Bold = $true }
    @{ Key = 'Staged'; Glyph = 'Staged'; Color = 'Green'; Bold = $false }
    @{ Key = 'Modified'; Glyph = 'Modified'; Color = 'Yellow'; Bold = $false }
    @{ Key = 'Untracked'; Glyph = 'Untracked'; Color = 'Untracked'; Bold = $false }
)

# Rebase en curso: carpeta en el git dir y archivos con el paso actual/total.
$MURILASSO_REBASE_LAYOUTS = @(
    @{ Directory = 'rebase-merge'; StepFile = 'msgnum'; TotalFile = 'end' }
    @{ Directory = 'rebase-apply'; StepFile = 'next'; TotalFile = 'last' }
)
$MURILASSO_GIT_OPERATION_MARKERS = @(
    @{ File = 'MERGE_HEAD'; Label = 'MERGE' }
    @{ File = 'CHERRY_PICK_HEAD'; Label = 'CHERRY-PICK' }
    @{ File = 'REVERT_HEAD'; Label = 'REVERT' }
    @{ File = 'BISECT_LOG'; Label = 'BISECT' }
)
$MURILASSO_DETACHED_HEAD_LABEL = '(detached)'

$MURILASSO_PR_STATE_STYLES = @{
    OPEN   = @{ Glyph = $MURILASSO_GLYPHS.PrOpen; Color = 'Green' }
    MERGED = @{ Glyph = $MURILASSO_GLYPHS.PrMerged; Color = 'Magenta' }
    CLOSED = @{ Glyph = $MURILASSO_GLYPHS.PrClosed; Color = 'Red' }
}
$MURILASSO_PR_DEFAULT_STYLE = @{ Glyph = $MURILASSO_GLYPHS.PrDefault; Color = 'Yellow' }
$MURILASSO_CI_STATUS_STYLES = @{
    SUCCESS = @{ Glyph = $MURILASSO_GLYPHS.CiSuccess; Color = 'Green' }
    FAILURE = @{ Glyph = $MURILASSO_GLYPHS.CiFailure; Color = 'Red' }
    PENDING = @{ Glyph = $MURILASSO_GLYPHS.CiPending; Color = 'Yellow' }
}
$MURILASSO_CI_UNKNOWN_STYLE = @{ Glyph = $MURILASSO_GLYPHS.CiUnknown; Color = 'BrightWhite' }

# Exit codes 128+N de procesos terminados por la señal N (shells POSIX).
$MURILASSO_SIGNAL_NAMES = @{
    129 = 'HUP'
    130 = 'INT'
    131 = 'QUIT'
    134 = 'ABRT'
    137 = 'KILL'
    139 = 'SEGV'
    141 = 'PIPE'
    143 = 'TERM'
}

# Versión de Node embebida en el path de instalación de fnm/nvm
# (p.ej. ...\node-versions\v24.14.1\installation\node.exe).
$MURILASSO_NODE_VERSION_PATH_PATTERN = '[\\/](v\d+\.\d+\.\d+)[\\/]'
$MURILASSO_NVMRC_FILE_NAME = '.nvmrc'

# Estado in-memory para evitar lanzar fetches o resolver Node en cada render.
$global:MurilassoPromptState = @{
    Branch        = ''
    Repo          = ''
    PrLastFetch   = [datetime]::MinValue
    CiKey         = ''
    CiLastFetch   = [datetime]::MinValue
    LastHistoryId = 0
    NodePathKey   = $null
    NodeCommand   = $null
}
# `node -v` por fingerprint del ejecutable, para instalaciones sin versión en el path.
$global:MurilassoNodeVersionCache = @{}

# Sesión elevada: el prompt muestra `#` en lugar de `❯`, como root en zsh.
$script:MurilassoIsElevated = $false
try {
    $currentWindowsPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $script:MurilassoIsElevated = $currentWindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    # Fuera de Windows no hay WindowsIdentity; se asume sesión sin elevar.
}

# El prompt ya muestra el venv activo; evita el prefijo "(venv)" de Activate.ps1.
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'

function Get-MurilassoCachePath {
    param([string]$Kind, [string]$Repo, [string]$Branch)

    $safeKey = ("{0}_{1}" -f $Repo, $Branch) -replace '[\\/:*?"<>| ]', '_'
    return Join-Path ([System.IO.Path]::GetTempPath()) (".murilasso_{0}_{1}" -f $Kind, $safeKey)
}

# Fetches de `gh` en curso. Cada entrada guarda el proceso, sus lecturas async
# de stdout/stderr y a qué archivo de cache volcar el resultado.
$global:MurilassoPendingGhFetches = [System.Collections.Generic.List[hashtable]]::new()

# Une argumentos en una línea de comandos con el quoting de CommandLineToArgvW,
# el mismo que aplica ProcessStartInfo.ArgumentList en .NET 6+.
function ConvertTo-ProcessArgumentString {
    param([string[]]$Arguments = @())

    $quotedArguments = foreach ($argument in $Arguments) {
        if ($argument -and $argument -notmatch '[\s"]') {
            $argument
        } else {
            $escapedArgument = $argument -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1'
            '"{0}"' -f $escapedArgument
        }
    }
    return $quotedArguments -join ' '
}

# Lanza `gh` como proceso hijo sin esperarlo (~5 ms). Start-Job bloqueaba el
# prompt ~200 ms por llamada porque arranca un pwsh completo. WorkingDirectory
# da a `gh` el contexto del repo, que no resolvía bien desde un hilo del mismo
# proceso (por eso no se usa Start-ThreadJob). El resultado se recoge en
# Complete-MurilassoGhFetches durante un render posterior.
function Start-MurilassoGhFetch {
    param(
        [string]$Repo,
        [string]$CachePath,
        [string[]]$GhArgs,
        [string[]]$FallbackGhArgs = @()
    )

    foreach ($pendingFetch in $global:MurilassoPendingGhFetches) {
        if ($pendingFetch.CachePath -eq $CachePath) { return }
    }

    if (-not $global:MurilassoGhExecutablePath) {
        $ghCommand = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $ghCommand) { return }
        $global:MurilassoGhExecutablePath = $ghCommand.Source
    }

    $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new($global:MurilassoGhExecutablePath)
    if ($null -ne $processStartInfo.ArgumentList) {
        foreach ($ghArgument in $GhArgs) { $processStartInfo.ArgumentList.Add($ghArgument) }
    } else {
        # .NET Framework (Windows PowerShell 5.1) no tiene ArgumentList.
        $processStartInfo.Arguments = ConvertTo-ProcessArgumentString -Arguments $GhArgs
    }
    $processStartInfo.WorkingDirectory = $Repo
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.CreateNoWindow = $true
    $processStartInfo.RedirectStandardOutput = $true
    # stderr se redirige para que los errores de `gh` no se escriban sobre la consola.
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    try {
        $ghProcess = [System.Diagnostics.Process]::Start($processStartInfo)
    } catch {
        return
    }

    $global:MurilassoPendingGhFetches.Add(@{
            Process        = $ghProcess
            OutputTask     = $ghProcess.StandardOutput.ReadToEndAsync()
            ErrorTask      = $ghProcess.StandardError.ReadToEndAsync()
            Repo           = $Repo
            CachePath      = $CachePath
            FallbackGhArgs = $FallbackGhArgs
        })
}

# Recoge los fetches terminados: vuelca su salida al cache o, si vino vacía y
# hay argumentos de fallback, lanza el fetch de fallback. No bloquea.
function Complete-MurilassoGhFetches {
    $pendingFetches = $global:MurilassoPendingGhFetches
    for ($fetchIndex = $pendingFetches.Count - 1; $fetchIndex -ge 0; $fetchIndex--) {
        $pendingFetch = $pendingFetches[$fetchIndex]
        if (-not ($pendingFetch.Process.HasExited -and $pendingFetch.OutputTask.IsCompleted)) {
            # Un `gh` colgado bloquearía para siempre nuevos fetches del mismo cache.
            $fetchAgeSeconds = ([datetime]::Now - $pendingFetch.Process.StartTime).TotalSeconds
            if ($fetchAgeSeconds -gt $MURILASSO_GH_FETCH_TIMEOUT_SECONDS) {
                try { $pendingFetch.Process.Kill() } catch { }
                $pendingFetch.Process.Dispose()
                $pendingFetches.RemoveAt($fetchIndex)
            }
            continue
        }

        $pendingFetches.RemoveAt($fetchIndex)
        $output = $pendingFetch.OutputTask.Result.TrimEnd("`r", "`n")
        $exitCode = $pendingFetch.Process.ExitCode
        $pendingFetch.Process.Dispose()

        if ($pendingFetch.FallbackGhArgs.Count -gt 0 -and [string]::IsNullOrWhiteSpace($output)) {
            Start-MurilassoGhFetch -Repo $pendingFetch.Repo -CachePath $pendingFetch.CachePath -GhArgs $pendingFetch.FallbackGhArgs
            continue
        }

        if ($exitCode -eq 0 -and -not [string]::IsNullOrEmpty($output)) {
            Set-Content -LiteralPath $pendingFetch.CachePath -Value $output -Encoding utf8 -NoNewline -ErrorAction SilentlyContinue
        }
    }
}

# Branches base: solo muestran PR si está abierto (nunca cerrado ni mergeado).
$MURILASSO_BASE_BRANCHES = @('main', 'master', 'develop')
$MURILASSO_OPEN_PR_STATE = 'OPEN'

function Test-MurilassoBaseBranch {
    param([string]$Branch)

    return $Branch -cin $MURILASSO_BASE_BRANCHES
}

function Start-MurilassoPrFetch {
    param([string]$Repo, [string]$CachePath, [string]$Branch)

    $openPrQuery = 'if length > 0 then .[0] | .url + "\n" + .state else empty end'
    $openPrArgs = @(
        'pr', 'list', '--head', $Branch, '--state', 'open', '--limit', '1',
        '--json', 'url,state', '--jq', $openPrQuery
    )
    $fallbackPrQuery = if (Test-MurilassoBaseBranch $Branch) {
        'select(.state == "OPEN") | .url + "\n" + .state'
    } else {
        '.url + "\n" + .state'
    }
    $fallbackPrArgs = @('pr', 'view', '--json', 'url,state', '--jq', $fallbackPrQuery)

    Start-MurilassoGhFetch `
        -Repo $Repo `
        -CachePath $CachePath `
        -GhArgs $openPrArgs `
        -FallbackGhArgs $fallbackPrArgs
}

# Lee el cache de PR (linea 1 = url, linea 2 = state) hacia env vars. En
# branches base descarta PRs no abiertos, aunque un cache viejo los conserve.
function Read-MurilassoPrCache {
    param([string]$CachePath, [string]$Branch)

    $lines = @(Get-Content -LiteralPath $CachePath -ErrorAction SilentlyContinue)
    if ($lines.Count -eq 0) { return }

    $url = ([string]$lines[0]).Trim()
    $prState = if ($lines.Count -ge 2) { ([string]$lines[1]).Trim() } else { '' }

    if ((Test-MurilassoBaseBranch $Branch) -and $prState -ne $MURILASSO_OPEN_PR_STATE) {
        $url = ''
        $prState = ''
    }

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

# Jobs activos del usuario para el indicador ✦N. Se cuentan solo estados activos,
# no todos los jobs de la sesión.
$MURILASSO_ACTIVE_JOB_STATES = @('NotStarted', 'Running', 'Suspended', 'Blocked', 'AtBreakpoint')

function Get-MurilassoActiveJobCount {
    $userJobs = @(Get-Job -ErrorAction SilentlyContinue | Where-Object {
            $_.State -in $MURILASSO_ACTIVE_JOB_STATES
        })
    return $userJobs.Count
}

# Mantiene actualizadas las env vars de PR/CI de la branch y el repo actuales.
# Branch 'HEAD' (detached) o vacía limpia el contexto de PR.
function Update-MurilassoPromptContext {
    param([string]$Branch, [string]$Repo)

    # Primero se vuelcan los fetches terminados para que este render ya lea su cache.
    Complete-MurilassoGhFetches

    if ([string]::IsNullOrWhiteSpace($Branch) -or $Branch -eq 'HEAD' -or [string]::IsNullOrWhiteSpace($Repo)) {
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
        if (Test-Path -LiteralPath $prCache) { Read-MurilassoPrCache -CachePath $prCache -Branch $branch }
        Start-MurilassoPrFetch -Repo $repo -CachePath $prCache -Branch $branch
    }
    elseif (Test-Path -LiteralPath $prCache) {
        # Relee cache en cada render, incluso si PR anterior estaba cerrado.
        # Misma branch puede recibir un PR abierto nuevo posteriormente.
        Read-MurilassoPrCache -CachePath $prCache -Branch $branch
        # Refresca cada 30s para detectar PRs nuevos.
        if (($now - $promptState.PrLastFetch).TotalSeconds -gt $MURILASSO_PR_REFRESH_SECONDS) {
            $promptState.PrLastFetch = $now
            Start-MurilassoPrFetch -Repo $repo -CachePath $prCache -Branch $branch
        }
    }

    Update-MurilassoCiContext -Repo $repo -Branch $branch
}

# Envuelve texto en un color SGR de $MURILASSO_COLORS; -Bold suma negrita.
function Format-MurilassoText {
    param([string]$Text, [string]$Color, [switch]$Bold)

    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $sgrCodes = @()
    if ($Bold) { $sgrCodes += '1' }
    if ($Color) { $sgrCodes += $MURILASSO_COLORS[$Color] }
    return '{0}[{1}m{2}{0}[0m' -f $MURILASSO_ESCAPE, ($sgrCodes -join ';'), $Text
}

# Link clickeable OSC 8: la terminal muestra $Text y abre $Url.
function Format-MurilassoHyperlink {
    param([string]$Text, [string]$Url)

    return '{0}]8;;{1}{2}{3}{0}]8;;{2}' -f $MURILASSO_ESCAPE, $Url, $MURILASSO_BELL, $Text
}

# Columnas que ocupa un texto con secuencias ANSI: descarta SGR y OSC 8, y
# cuenta cada par surrogate como un solo glifo.
function Get-MurilassoDisplayWidth {
    param([string]$Text)

    $visibleText = $Text -replace $MURILASSO_ANSI_SEQUENCE_PATTERN, ''
    $displayWidth = 0
    foreach ($character in $visibleText.ToCharArray()) {
        if (-not [char]::IsLowSurrogate($character)) { $displayWidth++ }
    }
    return $displayWidth
}

# Path corto estilo agnoster_short: `~` para el home, separadores `/` y solo
# las últimas carpetas (p.ej. `~/../configs/PowerShell`, `C:/../System32/drivers`).
function Get-MurilassoShortPath {
    param([string]$Path, [string]$HomePath)

    $normalizedPath = $Path -replace '\\', '/'
    $normalizedHome = ($HomePath -replace '\\', '/').TrimEnd('/')
    if ($normalizedHome -and $normalizedPath.TrimEnd('/').Equals($normalizedHome, [StringComparison]::OrdinalIgnoreCase)) {
        return '~'
    }

    if ($normalizedHome -and $normalizedPath.StartsWith($normalizedHome + '/', [StringComparison]::OrdinalIgnoreCase)) {
        $rootLabel = '~'
        $relativePath = $normalizedPath.Substring($normalizedHome.Length + 1)
    } else {
        $rootSeparatorIndex = $normalizedPath.IndexOf('/')
        if ($rootSeparatorIndex -lt 0) { return $normalizedPath }
        $rootLabel = $normalizedPath.Substring(0, $rootSeparatorIndex)
        $relativePath = $normalizedPath.Substring($rootSeparatorIndex + 1)
    }

    $folders = @($relativePath.Split([char[]]'/', [StringSplitOptions]::RemoveEmptyEntries))
    if ($folders.Count -eq 0) { return $rootLabel + '/' }
    if ($folders.Count -le $MURILASSO_PATH_MAX_DEPTH) {
        return (@($rootLabel) + $folders) -join '/'
    }

    $visibleFolders = $folders[($folders.Count - $MURILASSO_PATH_MAX_DEPTH)..($folders.Count - 1)]
    return (@($rootLabel, '..') + $visibleFolders) -join '/'
}

# Sube desde $Path buscando `.git` (carpeta, o archivo en worktrees y
# submódulos), para no spawnear git fuera de un repo.
function Find-MurilassoGitRoot {
    param([string]$Path)

    $directory = $Path
    while (-not [string]::IsNullOrEmpty($directory)) {
        $dotGitPath = [System.IO.Path]::Combine($directory, '.git')
        if ([System.IO.Directory]::Exists($dotGitPath) -or [System.IO.File]::Exists($dotGitPath)) {
            return $directory
        }
        $directory = [System.IO.Path]::GetDirectoryName($directory)
    }
    return $null
}

# Git dir real del worktree: `.git` o el destino de su línea `gitdir:`.
function Get-MurilassoGitDirectory {
    param([string]$RepoRoot)

    $dotGitPath = [System.IO.Path]::Combine($RepoRoot, '.git')
    if ([System.IO.Directory]::Exists($dotGitPath)) { return $dotGitPath }
    if (-not [System.IO.File]::Exists($dotGitPath)) { return $null }

    $gitDirLine = [System.IO.File]::ReadAllText($dotGitPath).Trim()
    if ($gitDirLine -notmatch '^gitdir:\s*(.+)$') { return $null }
    $gitDirectory = $Matches[1].Trim()
    if (-not [System.IO.Path]::IsPathRooted($gitDirectory)) {
        $gitDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RepoRoot, $gitDirectory))
    }
    return $gitDirectory
}

# Operación en curso (REBASE con paso/total, MERGE, ...) o '' si no hay.
function Get-MurilassoGitOperation {
    param([string]$GitDirectory)

    if (-not $GitDirectory) { return '' }

    foreach ($rebaseLayout in $MURILASSO_REBASE_LAYOUTS) {
        $rebaseDirectory = [System.IO.Path]::Combine($GitDirectory, $rebaseLayout.Directory)
        if (-not [System.IO.Directory]::Exists($rebaseDirectory)) { continue }

        $stepPath = [System.IO.Path]::Combine($rebaseDirectory, $rebaseLayout.StepFile)
        $totalPath = [System.IO.Path]::Combine($rebaseDirectory, $rebaseLayout.TotalFile)
        if ([System.IO.File]::Exists($stepPath) -and [System.IO.File]::Exists($totalPath)) {
            return 'REBASE {0}/{1}' -f [System.IO.File]::ReadAllText($stepPath).Trim(), [System.IO.File]::ReadAllText($totalPath).Trim()
        }
        return 'REBASE'
    }

    foreach ($operationMarker in $MURILASSO_GIT_OPERATION_MARKERS) {
        if ([System.IO.File]::Exists([System.IO.Path]::Combine($GitDirectory, $operationMarker.File))) {
            return $operationMarker.Label
        }
    }
    return ''
}

# Interpreta `git status --porcelain=v2 --branch --show-stash`. Con
# `# branch.upstream` pero sin `# branch.ab`, la branch remota ya no existe.
function ConvertFrom-MurilassoGitStatus {
    param([string[]]$StatusLines = @())

    $gitStatus = @{
        Branch         = ''
        HeadOid        = ''
        Upstream       = ''
        HasAheadBehind = $false
        Ahead          = 0
        Behind         = 0
        Staged         = 0
        Modified       = 0
        Unmerged       = 0
        Untracked      = 0
        StashCount     = 0
    }

    foreach ($statusLine in $StatusLines) {
        if ([string]::IsNullOrEmpty($statusLine)) { continue }
        switch ([string]$statusLine[0]) {
            '#' {
                if ($statusLine -match '^# branch\.oid (.+)$') { $gitStatus.HeadOid = $Matches[1] }
                elseif ($statusLine -match '^# branch\.head (.+)$') { $gitStatus.Branch = $Matches[1] }
                elseif ($statusLine -match '^# branch\.upstream (.+)$') { $gitStatus.Upstream = $Matches[1] }
                elseif ($statusLine -match '^# branch\.ab \+(\d+) -(\d+)$') {
                    $gitStatus.HasAheadBehind = $true
                    $gitStatus.Ahead = [int]$Matches[1]
                    $gitStatus.Behind = [int]$Matches[2]
                }
                elseif ($statusLine -match '^# stash (\d+)$') { $gitStatus.StashCount = [int]$Matches[1] }
            }
            # Entradas ordinarias (1) y renombres/copias (2): `<tipo> XY ...`,
            # X = index (staged) e Y = working tree; `.` es sin cambios.
            { $_ -eq '1' -or $_ -eq '2' } {
                if ($statusLine.Length -ge 4) {
                    if ($statusLine[2] -ne '.') { $gitStatus.Staged++ }
                    if ($statusLine[3] -ne '.') { $gitStatus.Modified++ }
                }
            }
            'u' { $gitStatus.Unmerged++ }
            '?' { $gitStatus.Untracked++ }
        }
    }

    $gitStatus.Detached = $gitStatus.Branch -eq $MURILASSO_DETACHED_HEAD_LABEL
    $gitStatus.UpstreamGone = [bool]$gitStatus.Upstream -and -not $gitStatus.HasAheadBehind
    return $gitStatus
}

# Un solo spawn de git por render para branch, upstream, contadores y stash.
function Get-MurilassoGitStatus {
    $statusLines = @(& git --no-optional-locks status --porcelain=v2 --branch --show-stash 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return ConvertFrom-MurilassoGitStatus -StatusLines $statusLines
}

function Format-MurilassoGitSegment {
    param([hashtable]$GitStatus, [string]$Operation)

    $glyphs = $MURILASSO_GLYPHS
    if ($GitStatus.Detached) {
        $shortShaLength = [Math]::Min($MURILASSO_SHORT_SHA_LENGTH, $GitStatus.HeadOid.Length)
        $branchText = '{0} {1}' -f $glyphs.Commit, $GitStatus.HeadOid.Substring(0, $shortShaLength)
        $branchLabel = Format-MurilassoText -Text $branchText -Color 'Yellow' -Bold
    } else {
        $displayBranch = $GitStatus.Branch
        if ($displayBranch.Length -gt $MURILASSO_BRANCH_MAX_LENGTH) {
            $displayBranch = $displayBranch.Substring(0, $MURILASSO_BRANCH_MAX_LENGTH - 1) + $glyphs.Ellipsis
        }
        $branchColor = if ($GitStatus.UpstreamGone) { 'Red' } else { 'Blue' }
        $branchLabel = Format-MurilassoText -Text ('{0} {1}' -f $glyphs.Branch, $displayBranch) -Color $branchColor -Bold
    }

    $gitSegment = ' {0} {1}' -f (Format-MurilassoText -Text $glyphs.Separator -Color 'Frame'), $branchLabel
    if ($Operation) {
        $gitSegment += ' ' + (Format-MurilassoText -Text $Operation -Color 'Magenta' -Bold)
    }

    $syncText = ''
    if ($GitStatus.Ahead -gt 0) { $syncText += Format-MurilassoText -Text ($glyphs.Ahead + $GitStatus.Ahead) -Color 'Cyan' }
    if ($GitStatus.Behind -gt 0) { $syncText += Format-MurilassoText -Text ($glyphs.Behind + $GitStatus.Behind) -Color 'Cyan' }
    if ($syncText) { $gitSegment += ' ' + $syncText }

    $hasChanges = $false
    foreach ($changeCounter in $MURILASSO_GIT_CHANGE_COUNTERS) {
        $changeCount = $GitStatus[$changeCounter.Key]
        if ($changeCount -gt 0) {
            $changeText = '{0} {1}' -f $glyphs[$changeCounter.Glyph], $changeCount
            $gitSegment += ' ' + (Format-MurilassoText -Text $changeText -Color $changeCounter.Color -Bold:$changeCounter.Bold)
            $hasChanges = $true
        }
    }
    if (-not $hasChanges) {
        $gitSegment += ' ' + (Format-MurilassoText -Text $glyphs.Clean -Color 'Green')
    }

    if ($GitStatus.StashCount -gt 0) {
        $gitSegment += ' ' + (Format-MurilassoText -Text ('{0} {1}' -f $glyphs.Stash, $GitStatus.StashCount) -Color 'Cyan')
    }
    return $gitSegment
}

# PR de la branch (con link) y estado de su CI, desde las env vars MURILASSO_PR_*.
function Format-MurilassoPrSegment {
    if ([string]::IsNullOrEmpty($env:MURILASSO_PR_URL)) { return '' }

    $prStyle = $MURILASSO_PR_STATE_STYLES[[string]$env:MURILASSO_PR_STATE]
    if (-not $prStyle) { $prStyle = $MURILASSO_PR_DEFAULT_STYLE }
    $ciStyle = $MURILASSO_CI_STATUS_STYLES[[string]$env:MURILASSO_PR_CI]
    if (-not $ciStyle) { $ciStyle = $MURILASSO_CI_UNKNOWN_STYLE }

    $prLabel = Format-MurilassoText -Text ('{0} #{1}' -f $prStyle.Glyph, $env:MURILASSO_PR_NUMBER) -Color $prStyle.Color
    return ' {0} {1} {2}' -f `
        (Format-MurilassoText -Text $MURILASSO_GLYPHS.Separator -Color 'Frame'),
        (Format-MurilassoHyperlink -Text $prLabel -Url $env:MURILASSO_PR_URL),
        (Format-MurilassoText -Text $ciStyle.Glyph -Color $ciStyle.Color)
}

# Versión del `node` del PATH. fnm/nvm la llevan en el path de instalación;
# otras instalaciones corren `node -v` una vez por ejecutable.
function Get-MurilassoNodeVersion {
    $promptState = $global:MurilassoPromptState
    # `fnm use` cambia el destino del link del multishell, no el PATH: el
    # comando se resuelve por PATH y su path estable se recalcula en cada render.
    if ($promptState.NodePathKey -ne $env:PATH) {
        $promptState.NodePathKey = $env:PATH
        $promptState.NodeCommand = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    $nodeCommand = $promptState.NodeCommand
    if (-not $nodeCommand) { return '' }

    $nodeExecutablePath = Get-StableExecutablePath -CommandInfo $nodeCommand
    if ($nodeExecutablePath -match $MURILASSO_NODE_VERSION_PATH_PATTERN) { return $Matches[1] }

    $nodeFingerprint = Get-ExecutableFingerprint -CommandInfo $nodeCommand
    if (-not $global:MurilassoNodeVersionCache.ContainsKey($nodeFingerprint)) {
        $nodeVersionOutput = @(& $nodeCommand.Source -v 2>$null)
        $global:MurilassoNodeVersionCache[$nodeFingerprint] = if ($nodeVersionOutput.Count -gt 0) { ([string]$nodeVersionOutput[0]).Trim() } else { '' }
    }
    return $global:MurilassoNodeVersionCache[$nodeFingerprint]
}

# Versión pedida por el `.nvmrc` más cercano (sin `v`), subiendo desde $Path
# hasta antes del home; '' si no hay.
function Find-MurilassoNvmrcVersion {
    param([string]$Path, [string]$HomePath)

    $directory = $Path
    while (-not [string]::IsNullOrEmpty($directory) -and -not $directory.Equals($HomePath, [StringComparison]::OrdinalIgnoreCase)) {
        $nvmrcPath = [System.IO.Path]::Combine($directory, $MURILASSO_NVMRC_FILE_NAME)
        if ([System.IO.File]::Exists($nvmrcPath)) {
            return ([System.IO.File]::ReadAllText($nvmrcPath) -replace '\s', '').TrimStart('v')
        }
        $directory = [System.IO.Path]::GetDirectoryName($directory)
    }
    return ''
}

# Versión de Node en verde y, si no coincide con el `.nvmrc`, la esperada en
# amarillo. Solo se comparan `.nvmrc` numéricos (no alias como `lts/*`).
function Format-MurilassoNodeSegment {
    param([string]$NodeVersion, [string]$ExpectedVersion)

    if (-not $NodeVersion) { return '' }

    $nodeSegment = Format-MurilassoText -Text ('{0} {1}' -f $MURILASSO_GLYPHS.Node, $NodeVersion) -Color 'Green'
    $runningVersion = $NodeVersion.TrimStart('v') + '.'
    if ($ExpectedVersion -match '^\d' -and -not $runningVersion.StartsWith($ExpectedVersion + '.')) {
        $mismatchText = '{0} v{1} {2}' -f $MURILASSO_GLYPHS.NodeMismatch, $ExpectedVersion, $MURILASSO_NVMRC_FILE_NAME
        $nodeSegment += ' ' + (Format-MurilassoText -Text $mismatchText -Color 'Yellow')
    }
    return $nodeSegment
}

# Duración compacta: 4.2s, 3m07s, 1h02m.
function Format-MurilassoDuration {
    param([double]$Milliseconds)

    if ($Milliseconds -lt $MURILASSO_MILLISECONDS_PER_MINUTE) {
        return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.0}s', $Milliseconds / $MURILASSO_MILLISECONDS_PER_SECOND)
    }

    $wholeSeconds = [Math]::Floor($Milliseconds / $MURILASSO_MILLISECONDS_PER_SECOND)
    if ($Milliseconds -lt $MURILASSO_MILLISECONDS_PER_HOUR) {
        return '{0}m{1:00}s' -f [Math]::Floor($Milliseconds / $MURILASSO_MILLISECONDS_PER_MINUTE), ($wholeSeconds % 60)
    }
    $wholeMinutes = [Math]::Floor($Milliseconds / $MURILASSO_MILLISECONDS_PER_MINUTE)
    return '{0}h{1:00}m' -f [Math]::Floor($Milliseconds / $MURILASSO_MILLISECONDS_PER_HOUR), ($wholeMinutes % 60)
}

# Exit code en rojo, con el nombre de la señal para los códigos 128+N.
function Format-MurilassoStatusSegment {
    param([int]$ExitCode)

    if ($ExitCode -eq 0) { return '' }
    $statusText = '{0} {1}' -f $MURILASSO_GLYPHS.ExitStatus, $ExitCode
    if ($MURILASSO_SIGNAL_NAMES.ContainsKey($ExitCode)) {
        $statusText += ' SIG' + $MURILASSO_SIGNAL_NAMES[$ExitCode]
    }
    return Format-MurilassoText -Text $statusText -Color 'Red'
}

# Exit code y duración del último comando del historial. Un Enter vacío no
# agrega historial: no hay comando nuevo y no se muestra estado ni duración.
function Get-MurilassoLastCommandResult {
    param([bool]$LastExecutionStatus, [object]$LastNativeExitCode)

    $lastCommandResult = @{ ExitCode = 0; DurationMs = 0 }
    $lastHistoryEntry = Get-History -Count 1
    $promptState = $global:MurilassoPromptState
    if (-not $lastHistoryEntry -or $lastHistoryEntry.Id -eq $promptState.LastHistoryId) {
        return $lastCommandResult
    }

    $promptState.LastHistoryId = $lastHistoryEntry.Id
    $lastCommandResult.DurationMs = ($lastHistoryEntry.EndExecutionTime - $lastHistoryEntry.StartExecutionTime).TotalMilliseconds
    if (-not $LastExecutionStatus) {
        # Si el error más reciente salió de este comando falló un cmdlet: código
        # 1. Si no, falló un ejecutable nativo y vale su $LASTEXITCODE.
        $lastError = $global:Error | Select-Object -First 1
        $errorFromLastCommand = $lastError -is [System.Management.Automation.ErrorRecord] -and
            $lastError.InvocationInfo -and $lastError.InvocationInfo.HistoryId -eq $lastHistoryEntry.Id
        $lastCommandResult.ExitCode = if (-not $errorFromLastCommand -and $LastNativeExitCode -is [int] -and $LastNativeExitCode -ne 0) {
            $LastNativeExitCode
        } else {
            1
        }
    }
    return $lastCommandResult
}

function Format-MurilassoRightPrompt {
    param([hashtable]$LastCommandResult, [string]$NodeSegment)

    $rightSegments = @()
    if ($LastCommandResult.DurationMs -ge $MURILASSO_DURATION_THRESHOLD_MS) {
        $durationText = '{0} {1}' -f $MURILASSO_GLYPHS.Duration, (Format-MurilassoDuration -Milliseconds $LastCommandResult.DurationMs)
        $rightSegments += Format-MurilassoText -Text $durationText -Color 'Yellow'
    }
    if ($NodeSegment) { $rightSegments += $NodeSegment }
    $statusSegment = Format-MurilassoStatusSegment -ExitCode $LastCommandResult.ExitCode
    if ($statusSegment) { $rightSegments += $statusSegment }
    $rightSegments += Format-MurilassoText -Text (Get-Date -Format $MURILASSO_TIME_FORMAT) -Color 'Frame'
    return $rightSegments -join $MURILASSO_RIGHT_SEGMENT_GAP
}

# Alinea $RightText al borde derecho; si no entra, lo oculta para no partir la línea.
function Join-MurilassoPromptLine {
    param([string]$LeftText, [string]$RightText, [int]$ConsoleWidth)

    $paddingWidth = $ConsoleWidth - $MURILASSO_RIGHT_PROMPT_MARGIN - (Get-MurilassoDisplayWidth -Text $LeftText) - (Get-MurilassoDisplayWidth -Text $RightText)
    if ($ConsoleWidth -le 0 -or $paddingWidth -lt 1) { return $LeftText }
    return $LeftText + (' ' * $paddingWidth) + $RightText
}

function Get-MurilassoPromptText {
    param([bool]$LastExecutionStatus, [object]$LastNativeExitCode)

    $glyphs = $MURILASSO_GLYPHS
    $lastCommandResult = Get-MurilassoLastCommandResult -LastExecutionStatus $LastExecutionStatus -LastNativeExitCode $LastNativeExitCode

    $currentLocation = $ExecutionContext.SessionState.Path.CurrentLocation
    $isFileSystem = $currentLocation.Provider.Name -eq 'FileSystem'
    $currentPath = if ($isFileSystem) { $currentLocation.ProviderPath } else { $currentLocation.Path }

    $repoRoot = if ($isFileSystem) { Find-MurilassoGitRoot -Path $currentPath } else { $null }
    $gitStatus = if ($repoRoot) { Get-MurilassoGitStatus } else { $null }
    $gitSegment = ''
    # El updater de PR/CI no debe tumbar el render (p.ej. un stop pendiente
    # tras un Ctrl+C en una llamada nativa).
    if ($gitStatus) {
        $prBranch = if ($gitStatus.Detached) { 'HEAD' } else { $gitStatus.Branch }
        try { Update-MurilassoPromptContext -Branch $prBranch -Repo $repoRoot } catch { }
        $gitOperation = Get-MurilassoGitOperation -GitDirectory (Get-MurilassoGitDirectory -RepoRoot $repoRoot)
        $gitSegment = (Format-MurilassoGitSegment -GitStatus $gitStatus -Operation $gitOperation) + (Format-MurilassoPrSegment)
    } else {
        try { Update-MurilassoPromptContext -Branch '' -Repo '' } catch { }
    }

    if ($script:ZoxideInitialized) {
        try { $null = __zoxide_hook } catch { }
    }

    $contextText = ''
    if ($env:VIRTUAL_ENV) {
        $venvName = [System.IO.Path]::GetFileName($env:VIRTUAL_ENV.TrimEnd('\', '/'))
        $contextText += Format-MurilassoText -Text ('{0} {1} ' -f $glyphs.PythonVenv, $venvName) -Color 'Yellow'
    }
    $contextText += Format-MurilassoText -Text ([Environment]::UserName) -Color 'Green' -Bold
    if ($env:SSH_CONNECTION -or $env:SSH_CLIENT) {
        $contextText += (Format-MurilassoText -Text '@' -Color 'Frame') + (Format-MurilassoText -Text ([Environment]::MachineName) -Color 'Magenta')
    }
    $contextText += (Format-MurilassoText -Text ':' -Color 'BrightWhite') +
        (Format-MurilassoText -Text (Get-MurilassoShortPath -Path $currentPath -HomePath $HOME) -Color 'Blue')

    $expectedNodeVersion = if ($isFileSystem) { Find-MurilassoNvmrcVersion -Path $currentPath -HomePath $HOME } else { '' }
    # Un node roto o un link inaccesible solo pierde el segmento, no el prompt.
    $nodeVersion = ''
    try { $nodeVersion = Get-MurilassoNodeVersion } catch { }
    $nodeSegment = Format-MurilassoNodeSegment -NodeVersion $nodeVersion -ExpectedVersion $expectedNodeVersion
    $rightText = Format-MurilassoRightPrompt -LastCommandResult $lastCommandResult -NodeSegment $nodeSegment

    $consoleWidth = 0
    try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch { }
    $firstLine = '{0} {1}{2}' -f (Format-MurilassoText -Text $glyphs.FrameTop -Color 'Frame'), $contextText, $gitSegment
    $firstLine = Join-MurilassoPromptLine -LeftText $firstLine -RightText $rightText -ConsoleWidth $consoleWidth

    $secondLine = (Format-MurilassoText -Text $glyphs.FrameBottom -Color 'Frame') + ' '
    $activeJobCount = Get-MurilassoActiveJobCount
    if ($activeJobCount -gt 0) {
        $secondLine += (Format-MurilassoText -Text ('{0} {1}' -f $glyphs.Jobs, $activeJobCount) -Color 'Yellow') + ' '
    }
    $arrowColor = if ($lastCommandResult.ExitCode -eq 0) { 'Green' } else { 'Red' }
    $arrowGlyph = if ($script:MurilassoIsElevated) { $glyphs.PromptRoot } else { $glyphs.PromptArrow }
    $secondLine += (Format-MurilassoText -Text $arrowGlyph -Color $arrowColor) + ' '

    return $firstLine + [Environment]::NewLine + $secondLine
}

function global:prompt {
    # `$?` y `$LASTEXITCODE` se capturan antes de que el render los pise con
    # git, gh o node; `$LASTEXITCODE` se restaura para el próximo comando.
    $lastExecutionStatus = $?
    $lastNativeExitCode = $global:LASTEXITCODE

    try {
        $promptText = Get-MurilassoPromptText -LastExecutionStatus $lastExecutionStatus -LastNativeExitCode $lastNativeExitCode
    } catch {
        # Sin esto PowerShell caería a su prompt `PS>` y perdería la ubicación.
        $promptText = 'PS {0}> ' -f $ExecutionContext.SessionState.Path.CurrentLocation
    }

    $global:LASTEXITCODE = $lastNativeExitCode
    return $promptText
}

if ($psConsoleReadLineType) {
    try {
        Set-PSReadLineOption `
            -ContinuationPrompt ('   {0} ' -f $MURILASSO_GLYPHS.Continuation) `
            -Colors @{ ContinuationPrompt = '{0}[{1}m' -f $MURILASSO_ESCAPE, $MURILASSO_COLORS.Continuation }
    } catch {
        Write-Warning "Prompt murilasso: no se pudo configurar el prompt de continuación de PSReadLine: $($_.Exception.Message)"
    }
}
# --- Fin prompt murilasso ----------------------------------------------------
# --- Fin prompt murilasso ----------------------------------------------------
