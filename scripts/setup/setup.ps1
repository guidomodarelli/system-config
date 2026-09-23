# NOTA: Ejecutar este script como Administrador.

$SetupLatestVersionPolicy = 'latest-stable-official'

# Emojis need a terminal that renders them (Windows Terminal, VS Code or any
# non-Windows host). The classic Windows console gets ASCII markers instead.
# SETUP_ICONS=always|never overrides the detection.
function Test-SetupEmojiSupported {
  switch ($env:SETUP_ICONS) {
    'always' { return $true }
    'never' { return $false }
  }

  if (-not [string]::IsNullOrEmpty($env:WT_SESSION) -or -not [string]::IsNullOrEmpty($env:TERM_PROGRAM)) {
    return $true
  }

  return [System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT
}

function Get-SetupIcon {
  param (
    [string]$Name
  )

  $emojiIcons = @{
    App = '🧰'; RealRun = '🚀'; DryRun = '🧪'; Platform = '💻'; Catalog = '📋'
    Recommended = '★'; Admin = '🔐'; Restart = '🔁'; Package = '📦'; Selected = '✅'
    Pointer = '👉'; Ok = '✅'; FailedItem = '❌'; Skipped = '⏩'; Info = '🔹'; Warn = '🚨'
    Error = '❌'; Time = '⌛'; Summary = '📊'; Shortcuts = '🧭'; Search = '🔎'
    Done = '🎉'; FailedRun = '💥'; NoResults = '🤷'; Prompt = '❯'; InputCursor = '▏'
  }
  $asciiIcons = @{
    App = '*'; RealRun = '>'; DryRun = '~'; Platform = '-'; Catalog = '-'
    Recommended = '*'; Admin = '!'; Restart = '~'; Package = '>'; Selected = 'x'
    Pointer = '>'; Ok = '[OK]'; FailedItem = '[X]'; Skipped = '[-]'; Info = '[i]'; Warn = '[!]'
    Error = '[X]'; Time = 't'; Summary = '='; Shortcuts = '?'; Search = '/'
    Done = '[OK]'; FailedRun = '[X]'; NoResults = '(?)'; Prompt = '>'; InputCursor = '_'
  }

  $icons = if (Test-SetupEmojiSupported) { $emojiIcons } else { $asciiIcons }
  return $icons[$Name]
}

# Blank with the same width as a single-cell marker (emoji: two columns).
function Get-SetupMarkerBlank {
  if (Test-SetupEmojiSupported) {
    return '  '
  }

  return ' '
}

function LogError {
  param (
    [string]$message
  )
  Write-Host "$(Get-SetupIcon 'Error') Error: $message" -ForegroundColor Red
}

function LogInfo {
  param (
    [string]$message
  )
  Write-Host "$(Get-SetupIcon 'Info') $message" -ForegroundColor Blue
}

function LogWarning {
  param (
    [string]$message
  )
  Write-Host "$(Get-SetupIcon 'Warn') Aviso: $message" -ForegroundColor Yellow
}

function LogSuccess {
  param (
    [string]$message
  )
  Write-Host "$(Get-SetupIcon 'Ok') $message" -ForegroundColor Green
}

# Boxes are open on the right: emoji width varies between terminals, so only
# the left border and horizontal rules are drawn.
function Write-SetupBoxTop {
  param (
    [string]$Title = ''
  )

  if ([string]::IsNullOrEmpty($Title)) {
    Write-Host ('╭' + ('─' * (Get-SetupBoxRuleWidth))) -ForegroundColor DarkGray
    return
  }

  $ruleLength = [Math]::Max(1, (Get-SetupBoxRuleWidth) - $Title.Length - 4)
  Write-Host '╭─ ' -ForegroundColor DarkGray -NoNewline
  Write-Host $Title -ForegroundColor Blue -NoNewline
  Write-Host (' ' + ('─' * $ruleLength)) -ForegroundColor DarkGray
}

function Get-SetupBoxRuleWidth {
  return 64
}

function Write-SetupBoxRow {
  param (
    [string]$Text,
    [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor
  )

  Write-Host '│ ' -ForegroundColor DarkGray -NoNewline
  Write-Host $Text -ForegroundColor $ForegroundColor
}

function Write-SetupBoxDivider {
  Write-Host ('├' + ('─' * (Get-SetupBoxRuleWidth))) -ForegroundColor DarkGray
}

function Write-SetupBoxBottom {
  Write-Host ('╰' + ('─' * (Get-SetupBoxRuleWidth))) -ForegroundColor DarkGray
}

function Write-SetupBoxClose {
  param (
    [string]$Text,
    [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor
  )

  Write-Host '╰─ ' -ForegroundColor DarkGray -NoNewline
  Write-Host $Text -ForegroundColor $ForegroundColor
}

function Format-SetupDuration {
  param (
    [int]$TotalSeconds
  )

  if ($TotalSeconds -ge 60) {
    return ('{0}m {1:00}s' -f [Math]::Floor($TotalSeconds / 60), ($TotalSeconds % 60))
  }

  return "${TotalSeconds}s"
}

function Get-SetupMenuItemBadges {
  param (
    [PSCustomObject]$menuItem
  )

  $badges = ''
  if ($menuItem.RequiresAdmin) {
    $badges += " $(Get-SetupIcon 'Admin')"
  }
  if ($menuItem.RequiresRestart) {
    $badges += " $(Get-SetupIcon 'Restart')"
  }
  return $badges
}

function Write-SetupBanner {
  param (
    [PSCustomObject[]]$menuCatalog,
    [bool]$DryRun = $false
  )

  $modeText = if ($DryRun) { "$(Get-SetupIcon 'DryRun') simulacion: no se instalara nada" } else { "$(Get-SetupIcon 'RealRun') instalacion" }
  $recommendedCount = @($menuCatalog | Where-Object { $_.DefaultSelected }).Count

  Write-SetupBoxTop
  Write-Host '│ ' -ForegroundColor DarkGray -NoNewline
  Write-Host "$(Get-SetupIcon 'App') setup del sistema" -ForegroundColor Magenta -NoNewline
  Write-Host ' · ' -ForegroundColor DarkGray -NoNewline
  Write-Host $modeText
  Write-SetupBoxRow -Text "$(Get-SetupIcon 'Platform') Windows · $(Get-SetupIcon 'Catalog') $($menuCatalog.Count) items · $(Get-SetupIcon 'Recommended') $recommendedCount recomendados" -ForegroundColor DarkGray
  Write-SetupBoxBottom
}

function New-SetupTemporaryDirectory {
  $temporaryDirectoryPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $temporaryDirectoryPath -Force | Out-Null
  return $temporaryDirectoryPath
}

function Remove-SetupTemporaryDirectory {
  param (
    [string]$Path
  )

  if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

function Invoke-SetupLatestOfficialScript {
  param (
    [string]$Uri,
    [string]$FileName
  )

  $temporaryDirectoryPath = New-SetupTemporaryDirectory
  try {
    $scriptPath = Join-Path $temporaryDirectoryPath $FileName
    Invoke-RestMethod -Uri $Uri -OutFile $scriptPath -ErrorAction Stop
    & $scriptPath
    if ($LASTEXITCODE -ne 0) {
      throw "El instalador oficial terminó con código $LASTEXITCODE."
    }
  } finally {
    Remove-SetupTemporaryDirectory -Path $temporaryDirectoryPath
  }
}


function Install-Choco {
  if (-Not (Test-Path 'C:\ProgramData\chocolatey\bin\choco.exe')) {
    LogInfo 'Instalando la última versión estable oficial de Chocolatey.'
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-SetupLatestOfficialScript -Uri 'https://community.chocolatey.org/install.ps1' -FileName 'chocolatey-install.ps1'
    if ($LASTEXITCODE -ne 0) {
      throw "Chocolatey terminó con código $LASTEXITCODE."
    }
    LogSuccess "Chocolatey se instaló correctamente."
  } else {
    LogInfo "Chocolatey ya está instalado. Actualizando paquetes del propio gestor a la última versión estable oficial disponible."
    choco upgrade chocolatey --confirm --no-progress
    if ($LASTEXITCODE -ne 0) {
      throw "Chocolatey no pudo actualizarse. Código: $LASTEXITCODE."
    }
  }
}

function Install-Scoop {
  if (-Not (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    LogInfo 'Instalando la última versión estable oficial de Scoop.'
    Invoke-SetupLatestOfficialScript -Uri 'https://get.scoop.sh' -FileName 'scoop-install.ps1'
    LogSuccess "Scoop se instaló correctamente."
  } else {
    LogInfo "Scoop ya está instalado. Actualizando buckets para resolver últimas versiones estables."
    scoop update
    if ($LASTEXITCODE -ne 0) {
      throw "Scoop no pudo actualizar sus metadatos. Código: $LASTEXITCODE."
    }
  }
}

function Test-ScoopPackageInstalled {
  param (
    [string]$Package
  )

  return Test-Path -LiteralPath "$env:USERPROFILE\scoop\apps\$Package\current"
}

function Install-ScoopPackage {
  param (
    [string[]]$packages
  )

  Install-Scoop

  foreach ($package in $packages) {
    if (Test-ScoopPackageInstalled -Package $package) {
      LogInfo "El paquete '$package' ya está instalado con Scoop. Actualizando a la última versión estable oficial disponible..."
      scoop update $package
      if ($LASTEXITCODE -ne 0) {
        throw "Scoop no pudo actualizar '$package'. Código: $LASTEXITCODE."
      }
      LogSuccess "El paquete '$package' se actualizó correctamente con Scoop."
    } else {
      LogInfo "Instalando el paquete '$package' con Scoop..."
      scoop install $package
      if ($LASTEXITCODE -ne 0) {
        throw "Scoop no pudo instalar '$package'. Código: $LASTEXITCODE."
      }
      LogSuccess "El paquete '$package' se instaló correctamente con Scoop."
    }
  }
}

function Test-ChocoPackageInstalled {
  param (
    [string]$Package
  )

  $installedPackage = choco list --local-only --exact $Package --limit-output 2>$null | Select-Object -First 1
  return -not [string]::IsNullOrWhiteSpace($installedPackage)
}

function Install-ChocoPackage {
  param (
    [string[]]$packages
  )
  foreach ($package in $packages) {
    if (Test-ChocoPackageInstalled -Package $package) {
      LogWarning "El paquete '$package' ya está instalado. Actualizando..."
      choco upgrade $package --confirm --no-progress
      if ($LASTEXITCODE -ne 0) {
        throw "Chocolatey no pudo actualizar '$package'. Código: $LASTEXITCODE."
      }
      LogSuccess "El paquete '$package' se actualizó correctamente."
    } else {
      LogInfo "Instalando el paquete '$package'..."
      choco install $package --confirm --no-progress
      if ($LASTEXITCODE -ne 0) {
        throw "Chocolatey no pudo instalar '$package'. Código: $LASTEXITCODE."
      }
      LogSuccess "El paquete '$package' se instaló correctamente."
    }
  }
}

function Test-WingetPackageInstalled {
  param (
    [string]$AppId
  )

  winget list --exact --id $AppId --accept-source-agreements 1>$null 2>$null
  return $LASTEXITCODE -eq 0
}

function Test-WingetIdempotentSuccessExitCode {
  param (
    [int]$ExitCode
  )

  $wingetIdempotentSuccessExitCodes = @(
    -1978335189,
    -1978334964
  )

  return $ExitCode -in $wingetIdempotentSuccessExitCodes
}

function Install-WingetPackage {
  param (
    [string[]]$appIds
  )
  foreach ($appId in $appIds) {
    if (Test-WingetPackageInstalled -AppId $appId) {
      LogInfo "El paquete '$appId' ya está instalado. Actualizando a la última versión estable oficial disponible..."
      winget upgrade --exact --id $appId --accept-package-agreements --accept-source-agreements --disable-interactivity 1>$null 2>$null
      if ($LASTEXITCODE -ne 0) {
        $upgradeExitCode = $LASTEXITCODE
        if (Test-WingetIdempotentSuccessExitCode -ExitCode $upgradeExitCode) {
          $global:LASTEXITCODE = 0
          LogSuccess "El paquete '$appId' ya está actualizado."
          continue
        }
        LogWarning "Winget no pudo actualizar '$appId' (código: $upgradeExitCode). Intentando instalación idempotente para recuperar..."
        winget install --exact --id $appId --accept-package-agreements --accept-source-agreements --disable-interactivity 1>$null 2>$null
        if ($LASTEXITCODE -ne 0) {
          if (Test-WingetIdempotentSuccessExitCode -ExitCode $LASTEXITCODE) {
            $global:LASTEXITCODE = 0
            LogSuccess "El paquete '$appId' ya está actualizado."
            continue
          }
          throw "Winget no pudo actualizar '$appId' y el intento de recuperación con instalación también falló. Códigos: upgrade=$upgradeExitCode, install=$LASTEXITCODE."
        }
        LogSuccess "El paquete '$appId' quedó instalado/actualizado tras recuperación."
        continue
      }
      LogSuccess "El paquete '$appId' quedó actualizado."
      continue
    }

    LogInfo "Instalando el paquete '$appId'..."
    winget install --exact --id $appId --accept-package-agreements --accept-source-agreements --disable-interactivity 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
      if (Test-WingetIdempotentSuccessExitCode -ExitCode $LASTEXITCODE) {
        $global:LASTEXITCODE = 0
        LogSuccess "El paquete '$appId' ya está actualizado."
        continue
      }
      throw "Winget no pudo instalar '$appId'. Código: $LASTEXITCODE."
    }
    LogSuccess "El paquete '$appId' se instaló correctamente."
  }
}

function Install-Fonts {
  $fonts = @(
    'nerd-fonts-jetbrainsmono',
    'nerd-fonts-iosevkaterm',
    'nerd-fonts-cascadiamono',
    'nerd-fonts-dejavusansmono',
    'nerd-fonts-victormono'
  )
  Install-ChocoPackage -packages $fonts
}

function _espanso {
  & "$env:USERPROFILE\AppData\Local\Programs\Espanso\espanso.cmd" @args
}

function Test-EspansoAlreadyRunningExitCode {
  param (
    [int]$ExitCode
  )

  return $ExitCode -eq 3
}

function Install-Espanso {
  Install-WingetPackage Espanso.Espanso

  _espanso service register
  if ($LASTEXITCODE -ne 0) {
    throw "Espanso no pudo registrar el servicio. Código: $LASTEXITCODE."
  }

  _espanso start
  if ($LASTEXITCODE -ne 0) {
    if (Test-EspansoAlreadyRunningExitCode -ExitCode $LASTEXITCODE) {
      $global:LASTEXITCODE = 0
      LogSuccess 'Espanso ya está en ejecución.'
      return
    }

    throw "Espanso no pudo iniciar. Código: $LASTEXITCODE."
  }
}

function Install-Git {
  Install-WingetPackage Git.Git
}

function Install-Gh {
  Install-WingetPackage GitHub.cli
}

function Resolve-FnmExecutable {
  $fnmCommand = Get-Command fnm -ErrorAction SilentlyContinue
  if ($fnmCommand) {
    return $fnmCommand.Source
  }

  $candidatePaths = @()
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $candidatePaths += Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\fnm.exe'
  }
  if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
    $candidatePaths += Join-Path $env:ProgramFiles 'fnm\fnm.exe'
  }

  foreach ($candidatePath in $candidatePaths) {
    if (Test-Path -LiteralPath $candidatePath) {
      return $candidatePath
    }
  }

  return $null
}

function Invoke-FnmEnvironment {
  param (
    [string]$FnmExecutable
  )

  & $FnmExecutable env --use-on-cd --shell powershell | Out-String | Invoke-Expression
  if ($LASTEXITCODE -ne 0) {
    throw "fnm no pudo activar el entorno de Node.js para esta sesión. Código: $LASTEXITCODE."
  }
}

function Resolve-NpmExecutable {
  $npmCommand = Get-Command npm -ErrorAction SilentlyContinue
  if ($npmCommand) {
    if ($npmCommand.CommandType -eq [System.Management.Automation.CommandTypes]::ExternalScript -and
        [System.IO.Path]::GetExtension($npmCommand.Source) -eq '.ps1') {
      $npmCmdShim = [System.IO.Path]::ChangeExtension($npmCommand.Source, '.cmd')
      if (Test-Path -LiteralPath $npmCmdShim) {
        return $npmCmdShim
      }
    }

    return $npmCommand.Source
  }

  return $null
}

function Install-NodeWithFnm {
  Install-fnm

  $fnmExecutable = Resolve-FnmExecutable
  if ([string]::IsNullOrWhiteSpace($fnmExecutable)) {
    throw 'fnm se instaló, pero no se encontró el ejecutable en PATH ni en WinGet Links.'
  }

  & $fnmExecutable install latest
  if ($LASTEXITCODE -ne 0) {
    throw "fnm no pudo instalar la última versión estable oficial de Node.js. Código: $LASTEXITCODE."
  }

  & $fnmExecutable default latest
  if ($LASTEXITCODE -ne 0) {
    throw "fnm no pudo configurar la última versión estable oficial de Node.js como versión predeterminada. Código: $LASTEXITCODE."
  }

  Invoke-FnmEnvironment -FnmExecutable $fnmExecutable

  $npmExecutable = Resolve-NpmExecutable
  if ([string]::IsNullOrWhiteSpace($npmExecutable)) {
    throw 'npm no quedó disponible en la sesión actual después de activar fnm.'
  }

  return $npmExecutable
}

function Resolve-SetupNpmExecutable {
  $npmExecutable = Resolve-NpmExecutable
  if (-not [string]::IsNullOrWhiteSpace($npmExecutable)) {
    return $npmExecutable
  }

  return Install-NodeWithFnm
}

function Install-Hunk {
  $npmExecutable = Resolve-SetupNpmExecutable

  & $npmExecutable i -g hunkdiff
  if ($LASTEXITCODE -ne 0) {
    throw "npm no pudo instalar 'hunkdiff'. Código: $LASTEXITCODE."
  }
}

function Install-VsCode {
  Install-WingetPackage Microsoft.VisualStudioCode
}

function Install-Vlc {
  Install-WingetPackage VideoLAN.VLC
}

function Install-FdFind {
  Install-WingetPackage sharkdp.fd
}

function Install-Curl {
  Install-WingetPackage cURL.cURL
}

function Install-Fzf {
  Install-WingetPackage junegunn.fzf
}

function Install-RipGrep {
  # Scoop instala ripgrep como un binario/shim de usuario normal. Winget puede crear
  # aliases o stubs en WindowsApps/WinGet Links que Codex Sandbox no puede ejecutar.
  Install-ScoopPackage ripgrep
}

function Install-Bitwarden {
  Install-WingetPackage Bitwarden.Bitwarden
}

function Install-Bat {
  Install-WingetPackage sharkdp.bat
}

function Install-Eza {
  # https://eza.rocks/
  Install-WingetPackage eza-community.eza
}

function Install-WSL {
  LogInfo "Verificando si WSL está instalado..."
  wsl --list --quiet 1>$null 2>$null
  if ($LASTEXITCODE -eq 0) {
    LogInfo "WSL ya está instalado. Actualizando a la última versión estable oficial disponible..."
    wsl --update
    if ($LASTEXITCODE -ne 0) {
      throw "WSL no pudo actualizarse. Código: $LASTEXITCODE."
    }
  } else {
    LogInfo "Instalando WSL..."
    wsl --install
    if ($LASTEXITCODE -ne 0) {
      throw "WSL no pudo instalarse. Código: $LASTEXITCODE."
    }
    LogSuccess "WSL se instaló correctamente."
  }
}

function Install-Python {
  Install-WingetPackage 9PNRBTZXMB4Z
}

function Install-WhatsApp {
  Install-WingetPackage 9NKSQGP7F2NH
}

function Test-HyperVAvailability {
  try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    return $feature.State -ne 'NotPresent'
  } catch {
    return $false
  }
}

function Enable-HyperV {
  LogInfo "Habilitando Hyper-V..."
  if (-not (Test-HyperVAvailability)) {
    LogWarning "Hyper-V no está disponible en esta edición de Windows."
    return
  }
  try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    if ($feature.State -eq 'Enabled') {
      LogWarning "Hyper-V ya está habilitado."
      return
    }
    $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) {
      LogSuccess "Hyper-V se habilitó correctamente. Se requiere reiniciar para completar la instalación."
    } else {
      LogSuccess "Hyper-V se habilitó correctamente."
    }
  } catch {
    LogError ("No se pudo habilitar Hyper-V. {0}" -f $_.Exception.Message)
  }
}

function Install-PowerToys {
  Install-WingetPackage Microsoft.PowerToys
}

function Install-7z {
  Install-WingetPackage 7zip.7zip
}

function Install-Mise-In-Place {
  # https://github.com/jdx/mise?tab=readme-ov-file#what-is-it
  # Like asdf (or nvm or pyenv but for any language)
  Install-WingetPackage jdx.mise
}

function Install-Ghq {
  Install-WingetPackage x-motemen.ghq
}

function Install-AutoHotkey {
  Install-WingetPackage AutoHotkey.AutoHotkey
}

function Install-fnm {
  Install-WingetPackage Schniz.fnm
}

function Install-PowerShell {
  Install-WingetPackage Microsoft.PowerShell
}

function Install-Pester {
  $minimumSupportedPesterVersion = [Version]'5.0.0'
  $installedPesterModule = Get-InstalledModule -Name Pester -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending |
    Select-Object -First 1

  if ($null -ne $installedPesterModule -and $installedPesterModule.Version.Major -eq 5 -and $installedPesterModule.Version -ge $minimumSupportedPesterVersion) {
    LogInfo "Pester ya está instalado en versión $($installedPesterModule.Version). Actualizando a la última estable de la rama 5.x..."
  } elseif ($null -ne $installedPesterModule) {
    LogInfo "Pester está en versión $($installedPesterModule.Version). Actualizando a la rama 5.x..."
  } else {
    LogInfo 'Instalando Pester 5.x desde PSGallery...'
  }

  try {
    $latestPesterFiveModule = Find-Module -Name Pester -AllVersions -ErrorAction Stop |
      Where-Object { $_.Version.Major -eq 5 -and $_.Version -ge $minimumSupportedPesterVersion } |
      Sort-Object Version -Descending |
      Select-Object -First 1

    if ($null -eq $latestPesterFiveModule) {
      throw 'No se encontró una versión estable disponible de Pester 5.x en PSGallery.'
    }

    Install-Module -Name Pester -RequiredVersion $latestPesterFiveModule.Version -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
  } catch {
    throw "No se pudo instalar/actualizar Pester 5.x: $($_.Exception.Message)"
  }

  LogSuccess 'Pester 5.x quedó instalado/actualizado correctamente.'
}

function Install-Zoxide {
  Install-WingetPackage ajeetdsouza.zoxide
}

function New-SetupMenuItem {
  param (
    [string]$Id,
    [string]$Label,
    [string]$FunctionName,
    [bool]$DefaultSelected = $false,
    [bool]$RequiresAdmin = $false,
    [string]$Platforms = 'windows',
    [bool]$RequiresRestart = $false
  )

  return [PSCustomObject]@{
    Id = $Id
    Label = $Label
    FunctionName = $FunctionName
    DefaultSelected = $DefaultSelected
    RequiresAdmin = $RequiresAdmin
    Platforms = $Platforms
    RequiresRestart = $RequiresRestart
  }
}

function Test-SetupMenuItemSupportsCurrentPlatform {
  param (
    [string]$Platforms
  )

  return [string]::IsNullOrWhiteSpace($Platforms) -or $Platforms -eq 'all' -or (",${Platforms}," -like '*,windows,*')
}

function Test-SetupPlatformTokenIsSupported {
  param (
    [string]$PlatformToken
  )

  return @('all', 'linux', 'wsl', 'darwin', 'windows').Contains($PlatformToken)
}

function Get-SetupMenuCatalog {
  param (
    [string]$CatalogPath = (Join-Path $PSScriptRoot 'setup.catalog.csv')
  )

  if (-not (Test-Path $CatalogPath)) {
    throw "No se encontró el catálogo de setup: $CatalogPath"
  }

  $expectedCatalogHeader = 'Id|Label|BashFunctionName|PowerShellFunctionName|DefaultSelected|RequiresAdmin|Platforms|RequiresRestart'
  $catalogHeader = Get-Content -Path $CatalogPath -TotalCount 1
  if ($catalogHeader -ne $expectedCatalogHeader) {
    throw "El catálogo de setup debe usar el encabezado común: $expectedCatalogHeader"
  }

  $catalogRows = Import-Csv -Path $CatalogPath -Delimiter '|'
  return @(
    foreach ($catalogRow in $catalogRows) {
      if ([string]::IsNullOrWhiteSpace($catalogRow.PowerShellFunctionName)) {
        continue
      }

      if (-not (Test-SetupMenuItemSupportsCurrentPlatform -Platforms $catalogRow.Platforms)) {
        continue
      }

      $supportsCurrentPlatform = Test-SetupMenuItemSupportsCurrentPlatform -Platforms $catalogRow.Platforms
      New-SetupMenuItem `
        -Id $catalogRow.Id `
        -Label $catalogRow.Label `
        -FunctionName $catalogRow.PowerShellFunctionName `
        -DefaultSelected (($catalogRow.DefaultSelected -eq '1') -and $supportsCurrentPlatform) `
        -RequiresAdmin ($catalogRow.RequiresAdmin -eq '1') `
        -Platforms $catalogRow.Platforms `
        -RequiresRestart ($catalogRow.RequiresRestart -eq '1')
    }
  )
}

function Test-SetupMenuCatalog {
  param (
    [PSCustomObject[]]$menuCatalog
  )

  $duplicatedLabels = @($menuCatalog | Group-Object Label | Where-Object { $_.Count -gt 1 } | ForEach-Object Name)
  if ($duplicatedLabels.Count -gt 0) {
    throw "Hay etiquetas duplicadas en el catálogo: $($duplicatedLabels -join ', ')."
  }

  $duplicatedIds = @($menuCatalog | Group-Object Id | Where-Object { $_.Count -gt 1 } | ForEach-Object Name)
  if ($duplicatedIds.Count -gt 0) {
    throw "Hay identificadores duplicados en el catálogo: $($duplicatedIds -join ', ')."
  }

  $missingFunctions = @($menuCatalog | Where-Object { -not (Get-Command -Name $_.FunctionName -CommandType Function -ErrorAction SilentlyContinue) } | ForEach-Object FunctionName)
  if ($missingFunctions.Count -gt 0) {
    throw "Hay funciones inexistentes en el catálogo: $($missingFunctions -join ', ')."
  }

  $foundNonDefault = $false
  foreach ($menuItem in $menuCatalog) {
    if (-not $menuItem.DefaultSelected) {
      $foundNonDefault = $true
      continue
    }

    if ($foundNonDefault) {
      throw "Los elementos seleccionados por defecto deben estar al inicio del catálogo."
    }
  }

  foreach ($menuItem in $menuCatalog) {
    $platformTokens = if ([string]::IsNullOrWhiteSpace($menuItem.Platforms)) { @('all') } else { @($menuItem.Platforms.Split(',')) }
    $unsupportedPlatformTokens = @($platformTokens | Where-Object { -not (Test-SetupPlatformTokenIsSupported -PlatformToken $_) })
    if ($unsupportedPlatformTokens.Count -gt 0) {
      throw "Hay plataformas no soportadas en '$($menuItem.Label)': $($unsupportedPlatformTokens -join ', ')."
    }
  }
}

function Test-SetupFunctionAllowed {
  param (
    [PSCustomObject[]]$menuCatalog,
    [string]$FunctionName
  )

  return @($menuCatalog | Where-Object { $_.FunctionName -eq $FunctionName }).Count -gt 0
}

function Find-SetupMenuCatalogItemIndex {
  param (
    [PSCustomObject[]]$menuCatalog,
    [string]$ItemIdentifier
  )

  for ($menuIndex = 0; $menuIndex -lt $menuCatalog.Count; $menuIndex++) {
    if ($menuCatalog[$menuIndex].FunctionName -eq $ItemIdentifier -or $menuCatalog[$menuIndex].Id -eq $ItemIdentifier) {
      return $menuIndex
    }
  }

  return -1
}

function Test-SetupMenuIndexesRequireAdmin {
  param (
    [PSCustomObject[]]$menuCatalog,
    [int[]]$selectedIndexes
  )

  foreach ($selectedIndex in $selectedIndexes) {
    if ($menuCatalog[$selectedIndex].RequiresAdmin) {
      return $true
    }
  }

  return $false
}

function Test-CurrentUserIsAdministrator {
  return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function Assert-SetupAdminRequirement {
  param (
    [PSCustomObject[]]$menuCatalog,
    [int[]]$selectedIndexes,
    [bool]$DryRun = $false
  )

  if ($DryRun) {
    return
  }

  if ((Test-SetupMenuIndexesRequireAdmin -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes) -and -not (Test-CurrentUserIsAdministrator)) {
    throw "La selección incluye ítems que requieren ejecutar PowerShell como Administrador."
  }
}

function Get-SetupMenuDisplayLabel {
  param (
    [PSCustomObject]$menuItem
  )

  $recommendedPrefix = if ($menuItem.DefaultSelected) { Get-SetupIcon 'Recommended' } else { ' ' }
  return "$recommendedPrefix $($menuItem.Label)$(Get-SetupMenuItemBadges -menuItem $menuItem)"
}

function New-SetupMenuRowSegment {
  param (
    [string]$Text,
    [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor,
    [ConsoleColor]$BackgroundColor = [Console]::BackgroundColor
  )

  return [PSCustomObject]@{
    Text = $Text
    ForegroundColor = $ForegroundColor
    BackgroundColor = $BackgroundColor
  }
}

# Row segments: scrollbar, cursor pointer, checkbox, recommended marker, label
# and badges. The cursor row gets a gray background across the whole row
# (except the scrollbar), padded to a fixed width.
function Get-SetupMenuRowSegments {
  param (
    [PSCustomObject]$menuItem,
    [bool]$IsSelected,
    [bool]$IsCursor,
    [string]$ScrollbarGlyph = ' ',
    [ConsoleColor]$ScrollbarColor = [ConsoleColor]::DarkGray,
    [string]$HighlightQuery = ''
  )

  $markerBlank = Get-SetupMarkerBlank
  $pointer = if ($IsCursor) { Get-SetupIcon 'Pointer' } else { $markerBlank }
  $selectionMarker = if ($IsSelected) { Get-SetupIcon 'Selected' } else { $markerBlank }
  $labelColor = if ($IsCursor) { [ConsoleColor]::Cyan } else { [Console]::ForegroundColor }

  $rowBackground = if ($IsCursor) { [ConsoleColor]::DarkGray } else { [Console]::BackgroundColor }
  $defaultForeground = [Console]::ForegroundColor

  $segments = @(
    New-SetupMenuRowSegment -Text $ScrollbarGlyph -ForegroundColor $ScrollbarColor
    New-SetupMenuRowSegment -Text ' '
    New-SetupMenuRowSegment -Text $pointer -ForegroundColor Cyan -BackgroundColor $rowBackground
    New-SetupMenuRowSegment -Text ' [' -ForegroundColor $defaultForeground -BackgroundColor $rowBackground
    New-SetupMenuRowSegment -Text $selectionMarker -ForegroundColor DarkGreen -BackgroundColor $rowBackground
    New-SetupMenuRowSegment -Text ']  ' -ForegroundColor $defaultForeground -BackgroundColor $rowBackground
  )

  $recommendedColor = if ($IsCursor) { [ConsoleColor]::Gray } else { [ConsoleColor]::DarkGray }
  $recommendedText = if ($menuItem.DefaultSelected) { Get-SetupIcon 'Recommended' } else { ' ' }
  $segments += New-SetupMenuRowSegment -Text $recommendedText -ForegroundColor $recommendedColor -BackgroundColor $rowBackground
  $segments += New-SetupMenuRowSegment -Text ' ' -BackgroundColor $rowBackground
  $segments += @(Get-SetupMenuLabelSegments -Label $menuItem.Label -HighlightQuery $HighlightQuery -ForegroundColor $labelColor -BackgroundColor $rowBackground)
  $segments += New-SetupMenuRowSegment -Text (Get-SetupMenuItemBadges -menuItem $menuItem) -ForegroundColor $defaultForeground -BackgroundColor $rowBackground

  if ($IsCursor) {
    $segments += New-SetupMenuRowSegment -Text (' ' * (Get-SetupMenuHighlightPadding -Segments $segments)) -ForegroundColor $defaultForeground -BackgroundColor $rowBackground
  }

  return $segments
}

# Splits the label so the part matching the search query is shown in yellow.
function Get-SetupMenuLabelSegments {
  param (
    [string]$Label,
    [string]$HighlightQuery,
    [ConsoleColor]$ForegroundColor,
    [ConsoleColor]$BackgroundColor
  )

  $matchStart = if ([string]::IsNullOrEmpty($HighlightQuery)) { -1 } else { $Label.IndexOf($HighlightQuery, [System.StringComparison]::OrdinalIgnoreCase) }
  if ($matchStart -lt 0) {
    return @(New-SetupMenuRowSegment -Text $Label -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor)
  }

  $segments = @()
  if ($matchStart -gt 0) {
    $segments += New-SetupMenuRowSegment -Text $Label.Substring(0, $matchStart) -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
  }
  $segments += New-SetupMenuRowSegment -Text $Label.Substring($matchStart, $HighlightQuery.Length) -ForegroundColor Yellow -BackgroundColor $BackgroundColor
  $matchEnd = $matchStart + $HighlightQuery.Length
  if ($matchEnd -lt $Label.Length) {
    $segments += New-SetupMenuRowSegment -Text $Label.Substring($matchEnd) -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
  }
  return $segments
}

function Get-SetupMenuHighlightWidth {
  return 58
}

# Columns left to reach the highlight width. Astral emojis already count as two
# UTF-16 units; the BMP check mark is two columns but one unit.
function Get-SetupMenuHighlightPadding {
  param (
    [PSCustomObject[]]$Segments
  )

  $rowText = (@($Segments | Select-Object -Skip 2) | ForEach-Object Text) -join ''
  $visibleColumns = $rowText.Length + ([regex]::Matches($rowText, '✅')).Count
  return [Math]::Max(1, (Get-SetupMenuHighlightWidth) - $visibleColumns)
}

# Scrollbar for a visible row: thumb where the window sits, track elsewhere,
# blank when the whole list fits.
function Get-SetupMenuScrollbarGlyph {
  param (
    [int]$RowPosition,
    [int]$WindowStartIndex,
    [int]$VisibleItemCount,
    [int]$ItemCount
  )

  if ($ItemCount -le $VisibleItemCount -or $VisibleItemCount -le 0) {
    return [PSCustomObject]@{ Glyph = ' '; Color = [ConsoleColor]::DarkGray }
  }

  $thumbSize = [Math]::Max(1, [Math]::Floor($VisibleItemCount * $VisibleItemCount / $ItemCount))
  $maxWindowStart = $ItemCount - $VisibleItemCount
  $thumbStart = [Math]::Floor($WindowStartIndex * ($VisibleItemCount - $thumbSize) / $maxWindowStart)

  if ($RowPosition -ge $thumbStart -and $RowPosition -lt ($thumbStart + $thumbSize)) {
    return [PSCustomObject]@{ Glyph = '┃'; Color = [ConsoleColor]::Cyan }
  }

  return [PSCustomObject]@{ Glyph = '│'; Color = [ConsoleColor]::DarkGray }
}

function Get-DefaultSetupMenuIndexes {
  param (
    [PSCustomObject[]]$menuCatalog
  )

  $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()
  for ($menuIndex = 0; $menuIndex -lt $menuCatalog.Count; $menuIndex++) {
    if ($menuCatalog[$menuIndex].DefaultSelected) {
      [void]$selectedIndexes.Add($menuIndex)
    }
  }

  return ,$selectedIndexes
}

function Write-SetupMenuRow {
  param (
    [PSCustomObject]$menuItem,
    [bool]$IsSelected,
    [bool]$IsCursor,
    [string]$ScrollbarGlyph = ' ',
    [ConsoleColor]$ScrollbarColor = [ConsoleColor]::DarkGray,
    [string]$HighlightQuery = ''
  )

  Write-ClearedSetupMenuLineStart
  $rowSegments = Get-SetupMenuRowSegments -menuItem $menuItem -IsSelected $IsSelected -IsCursor $IsCursor -ScrollbarGlyph $ScrollbarGlyph -ScrollbarColor $ScrollbarColor -HighlightQuery $HighlightQuery
  foreach ($rowSegment in $rowSegments) {
    Write-Host $rowSegment.Text -ForegroundColor $rowSegment.ForegroundColor -BackgroundColor $rowSegment.BackgroundColor -NoNewline
  }
  Write-Host ''
}

function New-SetupMenuReferenceRow {
  param (
    [string]$Shortcut,
    [string]$Description,
    [ConsoleColor]$ShortcutColor = [ConsoleColor]::DarkCyan
  )

  return [PSCustomObject]@{
    Shortcut = $Shortcut
    Description = $Description
    ShortcutColor = $ShortcutColor
  }
}

function Get-SetupMenuReferenceRows {
  return @(
    New-SetupMenuReferenceRow -Shortcut 'Arriba/Abajo/j/k' -Description 'navegar'
    New-SetupMenuReferenceRow -Shortcut 'PgUp/PgDn/Home/End' -Description 'saltar'
    New-SetupMenuReferenceRow -Shortcut '/' -Description 'buscar'
    New-SetupMenuReferenceRow -Shortcut 'ESPACIO' -Description 'alternar'
    New-SetupMenuReferenceRow -Shortcut 'a' -Description 'alternar todo'
    New-SetupMenuReferenceRow -Shortcut 'r' -Description 'restaurar defaults'
    New-SetupMenuReferenceRow -Shortcut 'ENTER' -Description 'confirmar'
    New-SetupMenuReferenceRow -Shortcut 'q/ESC/Ctrl+C/D' -Description 'cancelar'
  )
}

function Get-SetupMenuDefaultMarkerSegments {
  return @(
    New-SetupMenuRowSegment -Text '  '
    New-SetupMenuRowSegment -Text (Get-SetupIcon 'Recommended') -ForegroundColor DarkGray
    New-SetupMenuRowSegment -Text " recomendado · $(Get-SetupIcon 'Admin') requiere admin · $(Get-SetupIcon 'Restart') requiere reinicio"
  )
}

function Write-SetupMenuDefaultMarkerLegend {
  Write-ClearedSetupMenuLineStart
  $defaultMarkerSegments = Get-SetupMenuDefaultMarkerSegments
  foreach ($defaultMarkerSegment in $defaultMarkerSegments) {
    Write-Host $defaultMarkerSegment.Text -ForegroundColor $defaultMarkerSegment.ForegroundColor -BackgroundColor $defaultMarkerSegment.BackgroundColor -NoNewline
  }
  Write-Host ''
}

function Get-SetupMenuReferenceFrameColor {
  return [ConsoleColor]::DarkGray
}


function Write-SetupMenuReference {
  Write-Host ''
  Write-SetupBoxTop -Title "$(Get-SetupIcon 'Shortcuts') Atajos"

  $referenceRows = @(Get-SetupMenuReferenceRows)
  for ($rowIndex = 0; $rowIndex -lt $referenceRows.Count; $rowIndex += 2) {
    Write-Host '│ ' -ForegroundColor (Get-SetupMenuReferenceFrameColor) -NoNewline
    foreach ($referenceRow in @($referenceRows[$rowIndex..([Math]::Min($rowIndex + 1, $referenceRows.Count - 1))])) {
      Write-Host ('{0,-18}' -f $referenceRow.Shortcut) -ForegroundColor $referenceRow.ShortcutColor -NoNewline
      Write-Host (' {0,-20}' -f $referenceRow.Description) -NoNewline
    }
    Write-Host ''
  }

  Write-SetupBoxBottom
  Write-Host ''
}

function Get-SetupMenuRangeSegments {
  param (
    [int]$FirstVisibleItemNumber,
    [int]$LastVisibleItemNumber,
    [int]$TotalItemCount,
    [int]$SelectedItemCount = -1
  )

  $segments = @(
    New-SetupMenuRowSegment -Text "  $(Get-SetupIcon 'Catalog') Elementos "
    New-SetupMenuRowSegment -Text $FirstVisibleItemNumber -ForegroundColor DarkCyan
    New-SetupMenuRowSegment -Text '-'
    New-SetupMenuRowSegment -Text $LastVisibleItemNumber -ForegroundColor DarkCyan
    New-SetupMenuRowSegment -Text ' de '
    New-SetupMenuRowSegment -Text $TotalItemCount -ForegroundColor DarkCyan
  )

  if ($SelectedItemCount -ge 0) {
    $segments += New-SetupMenuRowSegment -Text " · $(Get-SetupIcon 'Selected') "
    $segments += New-SetupMenuRowSegment -Text $SelectedItemCount -ForegroundColor DarkCyan
    $segments += New-SetupMenuRowSegment -Text ' seleccionados'
  }

  return $segments
}

function Write-SetupMenuRange {
  param (
    [int]$FirstVisibleItemNumber,
    [int]$LastVisibleItemNumber,
    [int]$TotalItemCount,
    [int]$SelectedItemCount = -1
  )

  Write-ClearedSetupMenuLineStart
  $rangeSegments = Get-SetupMenuRangeSegments -FirstVisibleItemNumber $FirstVisibleItemNumber -LastVisibleItemNumber $LastVisibleItemNumber -TotalItemCount $TotalItemCount -SelectedItemCount $SelectedItemCount
  foreach ($rangeSegment in $rangeSegments) {
    Write-Host $rangeSegment.Text -ForegroundColor $rangeSegment.ForegroundColor -BackgroundColor $rangeSegment.BackgroundColor -NoNewline
  }
  Write-Host ''
}

function Write-ClassicSetupMenu {
  param (
    [PSCustomObject[]]$menuCatalog,
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$cursorIndex,
    [int]$windowStartIndex,
    [int]$visibleItemCount
  )

  $windowEndIndex = $windowStartIndex + $visibleItemCount
  Write-SetupMenuRange -FirstVisibleItemNumber ($windowStartIndex + 1) -LastVisibleItemNumber $windowEndIndex -TotalItemCount $menuCatalog.Count -SelectedItemCount $selectedIndexes.Count
  Write-SetupMenuDefaultMarkerLegend
  Write-ClearedSetupMenuLine -text ''

  if ($windowStartIndex -gt 0) {
    Write-ClearedSetupMenuLine -text '  ↑ Hay mas elementos arriba'
  } else {
    Write-ClearedSetupMenuLine -text ''
  }

  for ($menuIndex = $windowStartIndex; $menuIndex -lt $windowEndIndex; $menuIndex++) {
    $scrollbar = Get-SetupMenuScrollbarGlyph -RowPosition ($menuIndex - $windowStartIndex) -WindowStartIndex $windowStartIndex -VisibleItemCount $visibleItemCount -ItemCount $menuCatalog.Count
    Write-SetupMenuRow -menuItem $menuCatalog[$menuIndex] -IsSelected $selectedIndexes.Contains($menuIndex) -IsCursor ($menuIndex -eq $cursorIndex) -ScrollbarGlyph $scrollbar.Glyph -ScrollbarColor $scrollbar.Color
  }

  if ($windowEndIndex -lt $menuCatalog.Count) {
    Write-ClearedSetupMenuLine -text '  ↓ Hay mas elementos abajo'
  } else {
    Write-ClearedSetupMenuLine -text ''
  }
}

# Rows start after range, legend, spacer and top indicator.
function Get-ClassicSetupMenuItemRowOffset {
  param (
    [int]$menuIndex,
    [int]$windowStartIndex
  )

  return (Get-ClassicSetupMenuHeaderLineCount) + ($menuIndex - $windowStartIndex)
}

function Get-ClassicSetupMenuHeaderLineCount {
  return 4
}

function Test-ClassicSetupMenuRequiresFullRender {
  param (
    [int]$previousWindowStartIndex,
    [int]$windowStartIndex,
    [int]$previousVisibleItemCount,
    [int]$visibleItemCount,
    [bool]$ForceFullRender
  )

  return $ForceFullRender -or $previousWindowStartIndex -ne $windowStartIndex -or $previousVisibleItemCount -ne $visibleItemCount
}

function Write-ClassicSetupMenuItemRowAt {
  param (
    [PSCustomObject[]]$menuCatalog,
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$menuIndex,
    [int]$cursorIndex,
    [int]$windowStartIndex,
    [int]$menuTop,
    [int]$visibleItemCount = 0
  )

  $rowTop = $menuTop + (Get-ClassicSetupMenuItemRowOffset -menuIndex $menuIndex -windowStartIndex $windowStartIndex)
  [Console]::SetCursorPosition(0, $rowTop)
  $scrollbar = Get-SetupMenuScrollbarGlyph -RowPosition ($menuIndex - $windowStartIndex) -WindowStartIndex $windowStartIndex -VisibleItemCount $visibleItemCount -ItemCount $menuCatalog.Count
  Write-SetupMenuRow -menuItem $menuCatalog[$menuIndex] -IsSelected $selectedIndexes.Contains($menuIndex) -IsCursor ($menuIndex -eq $cursorIndex) -ScrollbarGlyph $scrollbar.Glyph -ScrollbarColor $scrollbar.Color
}

# Search screen: input box with prompt, cursor and match counter, one hint
# line, and the filtered results with the main menu rows.
function Write-SearchSetupMenu {
  param (
    [PSCustomObject[]]$menuCatalog,
    [int[]]$filteredIndexes,
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$filteredCursorIndex,
    [string]$query,
    [int]$visibleItemCount
  )

  $visibleSearchCount = [Math]::Min($visibleItemCount, $filteredIndexes.Count)
  $counterText = "$($filteredIndexes.Count) de $($menuCatalog.Count)"
  $inputText = if ([string]::IsNullOrEmpty($query)) { 'escribi para filtrar...' } else { $query }
  $inputPadding = [Math]::Max(1, (Get-SetupBoxRuleWidth) - $inputText.Length - $counterText.Length - 6)

  Write-ClearedSetupMenuLineStart
  Write-SetupBoxTop -Title "$(Get-SetupIcon 'Search') Buscar paquetes"
  Write-ClearedSetupMenuLineStart
  Write-Host '│ ' -ForegroundColor DarkGray -NoNewline
  Write-Host "$(Get-SetupIcon 'Prompt') " -ForegroundColor Magenta -NoNewline
  if ([string]::IsNullOrEmpty($query)) {
    Write-Host (Get-SetupIcon 'InputCursor') -ForegroundColor Cyan -NoNewline
    Write-Host $inputText -ForegroundColor DarkGray -NoNewline
  } else {
    Write-Host $inputText -ForegroundColor White -NoNewline
    Write-Host (Get-SetupIcon 'InputCursor') -ForegroundColor Cyan -NoNewline
  }
  Write-Host (' ' * $inputPadding) -NoNewline
  Write-Host $counterText -ForegroundColor DarkGray
  Write-ClearedSetupMenuLineStart
  Write-SetupBoxBottom

  Write-ClearedSetupMenuLineStart
  foreach ($hint in @(@('↑/↓', 'mover'), @('ESPACIO', 'alternar'), @('ENTER', 'volver'), @('ESC', 'cancelar'))) {
    Write-Host "  $($hint[0])" -ForegroundColor DarkCyan -NoNewline
    Write-Host " $($hint[1])" -ForegroundColor DarkGray -NoNewline
  }
  Write-Host ''
  Write-ClearedSetupMenuLine -text ''

  if ($filteredIndexes.Count -eq 0) {
    for ($emptyLineIndex = 0; $emptyLineIndex -lt $visibleItemCount; $emptyLineIndex++) {
      if ($emptyLineIndex -eq 0) {
        Write-ClearedSetupMenuLine -text ("  {0} Sin coincidencias para '{1}'" -f (Get-SetupIcon 'NoResults'), $query)
      } elseif ($emptyLineIndex -eq 1) {
        Write-ClearedSetupMenuLine -text '  Proba con menos letras o parte del nombre.' -ForegroundColor DarkGray
      } else {
        Write-ClearedSetupMenuLine -text ''
      }
    }
    return
  }

  $searchWindowStartIndex = Get-SetupMenuWindowStartIndex -cursorIndex $filteredCursorIndex -windowStartIndex 0 -visibleItemCount $visibleSearchCount -itemCount $filteredIndexes.Count
  $searchWindowEndIndex = $searchWindowStartIndex + $visibleSearchCount

  for ($visibleIndex = $searchWindowStartIndex; $visibleIndex -lt $searchWindowEndIndex; $visibleIndex++) {
    $menuIndex = $filteredIndexes[$visibleIndex]
    $scrollbar = Get-SetupMenuScrollbarGlyph -RowPosition ($visibleIndex - $searchWindowStartIndex) -WindowStartIndex $searchWindowStartIndex -VisibleItemCount $visibleSearchCount -ItemCount $filteredIndexes.Count
    Write-SetupMenuRow -menuItem $menuCatalog[$menuIndex] -IsSelected $selectedIndexes.Contains($menuIndex) -IsCursor ($visibleIndex -eq $filteredCursorIndex) -ScrollbarGlyph $scrollbar.Glyph -ScrollbarColor $scrollbar.Color -HighlightQuery $query
  }

  for ($emptyLineIndex = $visibleSearchCount; $emptyLineIndex -lt $visibleItemCount; $emptyLineIndex++) {
    Write-ClearedSetupMenuLine -text ''
  }
}

function Write-ClearedSetupMenuLineStart {
  [Console]::Write("`r")
  [Console]::Write((' ' * ([Console]::WindowWidth - 1)))
  [Console]::Write("`r")
}

function Write-ClearedSetupMenuLine {
  param (
    [string]$text,
    [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor,
    [ConsoleColor]$BackgroundColor = [Console]::BackgroundColor
  )

  Write-ClearedSetupMenuLineStart
  Write-Host $text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

function Test-SetupMenuLabelMatchesQuery {
  param (
    [string]$Label,
    [string]$Query
  )

  return [string]::IsNullOrWhiteSpace($Query) -or $Label.IndexOf($Query, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-FilteredSetupMenuIndexes {
  param (
    [PSCustomObject[]]$menuCatalog,
    [string]$query
  )

  $filteredIndexes = @()
  for ($menuIndex = 0; $menuIndex -lt $menuCatalog.Count; $menuIndex++) {
    if (Test-SetupMenuLabelMatchesQuery -Label $menuCatalog[$menuIndex].Label -Query $query) {
      $filteredIndexes += $menuIndex
    }
  }

  return ,$filteredIndexes
}

# Fills the window down to its last line; the list scrolls when it is taller.
# Reserved lines: leading blank + banner (5), shortcuts box with blank lines
# around it (8), window header (4), bottom indicator (1) and the resting
# cursor line (1).
function Get-SetupMenuVisibleItemCount {
  param (
    [int]$itemCount,
    [int]$WindowHeight = [Console]::WindowHeight
  )

  $visibleItemCount = $WindowHeight - 19
  if ($visibleItemCount -lt 5) {
    $visibleItemCount = 5
  }

  if ($visibleItemCount -gt $itemCount) {
    $visibleItemCount = $itemCount
  }

  return $visibleItemCount
}

function Get-ClassicSetupMenuRenderedLineCount {
  param (
    [int]$visibleItemCount
  )

  return $visibleItemCount + (Get-ClassicSetupMenuHeaderLineCount) + 1
}

function Get-SetupMenuWindowStartIndex {
  param (
    [int]$cursorIndex,
    [int]$windowStartIndex,
    [int]$visibleItemCount,
    [int]$itemCount
  )

  if ($cursorIndex -lt $windowStartIndex) {
    $windowStartIndex = $cursorIndex
  } elseif ($cursorIndex -ge ($windowStartIndex + $visibleItemCount)) {
    $windowStartIndex = $cursorIndex - $visibleItemCount + 1
  }

  if ($windowStartIndex -lt 0) {
    $windowStartIndex = 0
  }

  $maxWindowStartIndex = $itemCount - $visibleItemCount
  if ($maxWindowStartIndex -lt 0) {
    $maxWindowStartIndex = 0
  }

  if ($windowStartIndex -gt $maxWindowStartIndex) {
    $windowStartIndex = $maxWindowStartIndex
  }

  return $windowStartIndex
}

function Read-SetupMenuKey {
  $key = [Console]::ReadKey($true)

  if ($key.Key -eq [ConsoleKey]::UpArrow -or $key.KeyChar -eq 'k') {
    return 'Up'
  }

  if ($key.Key -eq [ConsoleKey]::DownArrow -or $key.KeyChar -eq 'j') {
    return 'Down'
  }

  if ($key.Key -eq [ConsoleKey]::PageUp) {
    return 'PageUp'
  }

  if ($key.Key -eq [ConsoleKey]::PageDown) {
    return 'PageDown'
  }

  if ($key.Key -eq [ConsoleKey]::Home) {
    return 'Home'
  }

  if ($key.Key -eq [ConsoleKey]::End) {
    return 'End'
  }

  if ($key.Key -eq [ConsoleKey]::Spacebar) {
    return 'Toggle'
  }

  if ($key.Key -eq [ConsoleKey]::Enter) {
    return 'Enter'
  }

  if ($key.KeyChar -eq 'a' -or $key.KeyChar -eq 'A') {
    return 'All'
  }

  if ($key.KeyChar -eq 'r' -or $key.KeyChar -eq 'R') {
    return 'Defaults'
  }

  if ($key.KeyChar -eq '/') {
    return 'Search'
  }

  if ($key.Key -eq [ConsoleKey]::Escape -or $key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
    return 'Cancel'
  }

  if (($key.Key -eq [ConsoleKey]::C -or $key.Key -eq [ConsoleKey]::D) -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
    return 'Cancel'
  }

  return 'Other'
}

function Find-SetupMenuItemIndex {
  param (
    [PSCustomObject[]]$menuCatalog,
    [string]$query,
    [int]$startIndex
  )

  if ([string]::IsNullOrWhiteSpace($query)) {
    return $startIndex
  }

  for ($offset = 1; $offset -le $menuCatalog.Count; $offset++) {
    $candidateIndex = ($startIndex + $offset) % $menuCatalog.Count
    if (Test-SetupMenuLabelMatchesQuery -Label $menuCatalog[$candidateIndex].Label -Query $query) {
      return $candidateIndex
    }
  }

  return $startIndex
}

function Update-SetupMenuSelectionForToggle {
  param (
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$cursorIndex,
    [ref]$HasManualSelection
  )

  if (-not $HasManualSelection.Value) {
    $HasManualSelection.Value = $true
  }

  if ($selectedIndexes.Contains($cursorIndex)) {
    [void]$selectedIndexes.Remove($cursorIndex)
  } else {
    [void]$selectedIndexes.Add($cursorIndex)
  }
}

function Update-SetupMenuSelectionForAll {
  param (
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$menuItemCount,
    [ref]$HasManualSelection
  )

  $HasManualSelection.Value = $true
  if ($selectedIndexes.Count -eq $menuItemCount) {
    $selectedIndexes.Clear()
    return
  }

  for ($menuIndex = 0; $menuIndex -lt $menuItemCount; $menuIndex++) {
    [void]$selectedIndexes.Add($menuIndex)
  }
}

function Get-SetupSelectedIndexArray {
  param (
    [System.Collections.Generic.HashSet[int]]$selectedIndexes
  )

  return @($selectedIndexes | Sort-Object)
}

function Invoke-SetupMenuSearch {
  param (
    [PSCustomObject[]]$menuCatalog,
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$cursorIndex,
    [int]$visibleItemCount,
    [bool]$HasManualSelection = $false
  )

  $query = ''
  $filteredIndexes = Get-FilteredSetupMenuIndexes -menuCatalog $menuCatalog -query $query
  $filteredCursorIndex = 0

  # Clear once and redraw from the top on each key to avoid flickering.
  Clear-Host
  while ($true) {
    [Console]::SetCursorPosition(0, 0)
    Write-ClearedSetupMenuLine -text ''
    Write-SearchSetupMenu -menuCatalog $menuCatalog -filteredIndexes $filteredIndexes -selectedIndexes $selectedIndexes -filteredCursorIndex $filteredCursorIndex -query $query -visibleItemCount $visibleItemCount
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::Escape -or (($key.Key -eq [ConsoleKey]::C -or $key.Key -eq [ConsoleKey]::D) -and ($key.Modifiers -band [ConsoleModifiers]::Control))) {
      return [PSCustomObject]@{ Cancelled = $true; CursorIndex = $cursorIndex; HasManualSelection = $HasManualSelection }
    }

    if ($key.Key -eq [ConsoleKey]::Enter) {
      if ($filteredIndexes.Count -eq 0) {
        return [PSCustomObject]@{ Cancelled = $false; CursorIndex = $cursorIndex; HasManualSelection = $HasManualSelection }
      }

      return [PSCustomObject]@{ Cancelled = $false; CursorIndex = $filteredIndexes[$filteredCursorIndex]; HasManualSelection = $HasManualSelection }
    }

    if ($key.Key -eq [ConsoleKey]::UpArrow -or $key.KeyChar -eq 'k') {
      if ($filteredCursorIndex -gt 0) {
        $filteredCursorIndex--
      }
    } elseif ($key.Key -eq [ConsoleKey]::DownArrow -or $key.KeyChar -eq 'j') {
      if ($filteredCursorIndex -lt ($filteredIndexes.Count - 1)) {
        $filteredCursorIndex++
      }
    } elseif ($key.Key -eq [ConsoleKey]::Home) {
      $filteredCursorIndex = 0
    } elseif ($key.Key -eq [ConsoleKey]::End) {
      $filteredCursorIndex = [Math]::Max(0, $filteredIndexes.Count - 1)
    } elseif ($key.Key -eq [ConsoleKey]::Spacebar) {
      if ($filteredIndexes.Count -gt 0) {
        $menuIndex = $filteredIndexes[$filteredCursorIndex]
        Update-SetupMenuSelectionForToggle -selectedIndexes $selectedIndexes -cursorIndex $menuIndex -HasManualSelection ([ref]$HasManualSelection)
      }
    } elseif ($key.Key -eq [ConsoleKey]::Backspace) {
      if ($query.Length -gt 0) {
        $query = $query.Substring(0, $query.Length - 1)
      }
    } elseif (-not [char]::IsControl($key.KeyChar)) {
      $query += $key.KeyChar
    }

    $filteredIndexes = Get-FilteredSetupMenuIndexes -menuCatalog $menuCatalog -query $query
    if ($filteredCursorIndex -ge $filteredIndexes.Count) {
      $filteredCursorIndex = [Math]::Max(0, $filteredIndexes.Count - 1)
    }

  }
}

function Select-SetupMenuClassic {
  param (
    [PSCustomObject[]]$menuCatalog
  )

  $previousTreatControlCAsInput = [Console]::TreatControlCAsInput
  [Console]::TreatControlCAsInput = $true
  $cursorIndex = 0
  $windowStartIndex = 0
  $visibleItemCount = Get-SetupMenuVisibleItemCount -itemCount $menuCatalog.Count
  $renderedLineCount = Get-ClassicSetupMenuRenderedLineCount -visibleItemCount $visibleItemCount
  $selectedIndexes = Get-DefaultSetupMenuIndexes -menuCatalog $menuCatalog
  $hasManualSelection = $false
  $menuTop = 0

  try {
    Write-SetupMenuReference
    Write-ClassicSetupMenu -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -visibleItemCount $visibleItemCount
    $menuTop = [Math]::Max(0, [Console]::CursorTop - $renderedLineCount)

    while ($true) {
      $pressedKey = Read-SetupMenuKey
      $previousCursorIndex = $cursorIndex
      $previousWindowStartIndex = $windowStartIndex
      $previousVisibleItemCount = $visibleItemCount
      $forceFullRender = $false

      switch ($pressedKey) {
        'Up' {
          if ($cursorIndex -gt 0) {
            $cursorIndex--
          }
        }
        'Down' {
          if ($cursorIndex -lt ($menuCatalog.Count - 1)) {
            $cursorIndex++
          }
        }
        'PageUp' {
          $cursorIndex = [Math]::Max(0, $cursorIndex - $visibleItemCount)
        }
        'PageDown' {
          $cursorIndex = [Math]::Min($menuCatalog.Count - 1, $cursorIndex + $visibleItemCount)
        }
        'Home' {
          $cursorIndex = 0
        }
        'End' {
          $cursorIndex = $menuCatalog.Count - 1
        }
        'Toggle' {
          Update-SetupMenuSelectionForToggle -selectedIndexes $selectedIndexes -cursorIndex $cursorIndex -HasManualSelection ([ref]$hasManualSelection)
          $forceFullRender = $true
        }
        'All' {
          Update-SetupMenuSelectionForAll -selectedIndexes $selectedIndexes -menuItemCount $menuCatalog.Count -HasManualSelection ([ref]$hasManualSelection)
          $forceFullRender = $true
        }
        'Defaults' {
          $selectedIndexes = Get-DefaultSetupMenuIndexes -menuCatalog $menuCatalog
          $hasManualSelection = $false
          $forceFullRender = $true
        }
        'Search' {
          $searchResult = Invoke-SetupMenuSearch -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -cursorIndex $cursorIndex -visibleItemCount $visibleItemCount -HasManualSelection $hasManualSelection
          if (-not $searchResult.Cancelled) {
            $cursorIndex = $searchResult.CursorIndex
          }
          $hasManualSelection = $searchResult.HasManualSelection
          Clear-Host
          Write-SetupMenuReference
          $forceFullRender = $true
          $menuTop = [Console]::CursorTop
        }
        'Enter' {
          Write-Host ''
          return [PSCustomObject]@{ Cancelled = $false; SelectedIndexes = (Get-SetupSelectedIndexArray -selectedIndexes $selectedIndexes) }
        }
        'Cancel' {
          Write-Host ''
          return [PSCustomObject]@{ Cancelled = $true; SelectedIndexes = @() }
        }
      }

      $visibleItemCount = Get-SetupMenuVisibleItemCount -itemCount $menuCatalog.Count
      $renderedLineCount = Get-ClassicSetupMenuRenderedLineCount -visibleItemCount $visibleItemCount
      $windowStartIndex = Get-SetupMenuWindowStartIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -visibleItemCount $visibleItemCount -itemCount $menuCatalog.Count

      if (Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex $previousWindowStartIndex -windowStartIndex $windowStartIndex -previousVisibleItemCount $previousVisibleItemCount -visibleItemCount $visibleItemCount -ForceFullRender $forceFullRender) {
        [Console]::SetCursorPosition(0, $menuTop)
        Write-ClassicSetupMenu -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -visibleItemCount $visibleItemCount
        $menuTop = [Math]::Max(0, [Console]::CursorTop - $renderedLineCount)
        continue
      }

      if ($pressedKey -eq 'Toggle') {
        Write-ClassicSetupMenuItemRowAt -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -menuIndex $cursorIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -menuTop $menuTop -visibleItemCount $visibleItemCount
      } elseif ($previousCursorIndex -ne $cursorIndex) {
        Write-ClassicSetupMenuItemRowAt -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -menuIndex $previousCursorIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -menuTop $menuTop -visibleItemCount $visibleItemCount
        Write-ClassicSetupMenuItemRowAt -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -menuIndex $cursorIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -menuTop $menuTop -visibleItemCount $visibleItemCount
      }

      [Console]::SetCursorPosition(0, $menuTop + $renderedLineCount)
    }
  } finally {
    [Console]::TreatControlCAsInput = $previousTreatControlCAsInput
  }
}

# Runs each selected item inside its own frame. Installer output stays visible
# (it may prompt), so there is no progress animation around it.
function Invoke-SelectedSetupMenuItems {
  param (
    [PSCustomObject[]]$menuCatalog,
    [int[]]$selectedIndexes,
    [bool]$DryRun = $false
  )

  $results = @()
  $sortedIndexes = @($selectedIndexes | Sort-Object)
  $position = 0

  if ($DryRun) {
    Write-Host ''
    Write-SetupBoxTop -Title "$(Get-SetupIcon 'DryRun') Simulacion"
  }

  foreach ($selectedIndex in $sortedIndexes) {
    $position++
    $menuItem = $menuCatalog[$selectedIndex]
    $positionText = "[$position/$($sortedIndexes.Count)]"

    if ($DryRun) {
      Write-SetupBoxRow -Text "$positionText se ejecutaria $($menuItem.Label)$(Get-SetupMenuItemBadges -menuItem $menuItem)"
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Dry-run'; Detail = 'No ejecutado'; RequiresRestart = $menuItem.RequiresRestart; DurationSeconds = 0 }
      continue
    }

    Write-Host ''
    if (-not (Test-SetupMenuItemSupportsCurrentPlatform -Platforms $menuItem.Platforms)) {
      Write-SetupBoxClose -Text "$(Get-SetupIcon 'Skipped') $positionText $($menuItem.Label) omitido por plataforma" -ForegroundColor Yellow
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Omitido'; Detail = 'Plataforma no soportada'; RequiresRestart = $false; DurationSeconds = 0 }
      continue
    }

    Write-SetupBoxTop -Title "$(Get-SetupIcon 'Package') $positionText $($menuItem.Label)"
    $startedAt = Get-Date
    try {
      $global:LASTEXITCODE = 0
      & $menuItem.FunctionName | Out-Host
      if ($global:LASTEXITCODE -ne 0) {
        throw "La función '$($menuItem.FunctionName)' terminó con código $global:LASTEXITCODE."
      }

      $durationSeconds = [int]((Get-Date) - $startedAt).TotalSeconds
      Write-SetupBoxClose -Text "$(Get-SetupIcon 'Ok') $($menuItem.Label) listo · $(Get-SetupIcon 'Time') $(Format-SetupDuration -TotalSeconds $durationSeconds)" -ForegroundColor Green
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'OK'; Detail = ''; RequiresRestart = $menuItem.RequiresRestart; DurationSeconds = $durationSeconds }
    } catch {
      $durationSeconds = [int]((Get-Date) - $startedAt).TotalSeconds
      Write-SetupBoxClose -Text "$(Get-SetupIcon 'FailedItem') $($menuItem.Label) fallo: $($_.Exception.Message)" -ForegroundColor Red
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Falló'; Detail = $_.Exception.Message; RequiresRestart = $false; DurationSeconds = $durationSeconds }
    }
  }

  if ($DryRun) {
    Write-SetupBoxBottom
  }

  return $results
}

function Confirm-SetupMenuSelection {
  param (
    [PSCustomObject[]]$menuCatalog,
    [int[]]$selectedIndexes,
    [bool]$DryRun = $false
  )

  Write-Host ''
  Write-SetupBoxTop -Title "$(Get-SetupIcon 'Catalog') Se van a procesar ($($selectedIndexes.Count))"
  foreach ($selectedIndex in $selectedIndexes | Sort-Object) {
    Write-SetupBoxRow -Text (Get-SetupMenuDisplayLabel -menuItem $menuCatalog[$selectedIndex])
  }
  Write-SetupBoxDivider
  if ($DryRun) {
    Write-SetupBoxRow -Text "$(Get-SetupIcon 'DryRun') Simulacion: no se instalara nada." -ForegroundColor Yellow
  }
  Write-SetupBoxRow -Text 'ENTER continuar · q/ESC/Ctrl+C/D cancelar'
  Write-SetupBoxBottom

  $previousTreatControlCAsInput = [Console]::TreatControlCAsInput
  [Console]::TreatControlCAsInput = $true
  try {
    while ($true) {
      $key = [Console]::ReadKey($true)
      if ($key.Key -eq [ConsoleKey]::Enter) {
        return $true
      }

      if ($key.Key -eq [ConsoleKey]::Escape -or $key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q' -or (($key.Key -eq [ConsoleKey]::C -or $key.Key -eq [ConsoleKey]::D) -and ($key.Modifiers -band [ConsoleModifiers]::Control))) {
        return $false
      }
    }
  } finally {
    [Console]::TreatControlCAsInput = $previousTreatControlCAsInput
  }
}

function Write-SetupExecutionSummary {
  param (
    [PSCustomObject[]]$results
  )

  $okCount = @($results | Where-Object { $_.Status -eq 'OK' }).Count
  $skippedCount = @($results | Where-Object { $_.Status -eq 'Omitido' }).Count
  $dryRunCount = @($results | Where-Object { $_.Status -eq 'Dry-run' }).Count
  $failedResults = @($results | Where-Object { $_.Status -ne 'OK' -and $_.Status -ne 'Dry-run' -and $_.Status -ne 'Omitido' })
  $totalSeconds = ($results | Measure-Object -Property DurationSeconds -Sum).Sum
  if ($null -eq $totalSeconds) { $totalSeconds = 0 }

  Write-Host ''
  Write-SetupBoxTop -Title "$(Get-SetupIcon 'Summary') Resumen"
  foreach ($result in $results) {
    $label = '{0,-32}' -f $result.Label
    $durationText = Format-SetupDuration -TotalSeconds ([int]$result.DurationSeconds)
    if ($result.Status -eq 'OK') {
      Write-SetupBoxRow -Text "$(Get-SetupIcon 'Ok') $label $durationText" -ForegroundColor Green
    } elseif ($result.Status -eq 'Omitido') {
      Write-SetupBoxRow -Text "$(Get-SetupIcon 'Skipped') $label omitido por plataforma" -ForegroundColor Yellow
    } elseif ($result.Status -ne 'Dry-run') {
      Write-SetupBoxRow -Text "$(Get-SetupIcon 'FailedItem') $(Get-SetupFailureSummaryMessage -Label $result.Label -Detail $result.Detail)" -ForegroundColor Red
    }
  }

  Write-SetupBoxDivider
  if ($dryRunCount -gt 0) {
    Write-SetupBoxRow -Text "$(Get-SetupIcon 'DryRun') $dryRunCount en simulacion · no se instalo nada"
  } else {
    Write-SetupBoxRow -Text "$(Get-SetupIcon 'Ok') $okCount ok · $(Get-SetupIcon 'FailedItem') $($failedResults.Count) fallaron · $(Get-SetupIcon 'Skipped') $skippedCount omitidos · $(Get-SetupIcon 'Time') $(Format-SetupDuration -TotalSeconds ([int]$totalSeconds))"
  }

  $restartRequired = @($results | Where-Object { $_.Status -eq 'OK' -and $_.RequiresRestart }).Count -gt 0
  if ($restartRequired) {
    Write-SetupBoxRow -Text "$(Get-SetupIcon 'Restart') Algunos cambios requieren reiniciar o abrir una nueva sesión para aplicarse." -ForegroundColor Yellow
  }

  if ($failedResults.Count -gt 0) {
    Write-SetupBoxRow -Text "$(Get-SetupIcon 'FailedRun') Proceso con $($failedResults.Count) error(es)." -ForegroundColor Red
  } else {
    Write-SetupBoxRow -Text "$(Get-SetupIcon 'Done') Proceso completo." -ForegroundColor Green
  }
  Write-SetupBoxBottom
}

function Get-SetupFailureSummaryMessage {
  param (
    [string]$Label,
    [string]$Detail
  )

  if ([string]::IsNullOrWhiteSpace($Detail)) {
    return "$Label`: falló"
  }

  return "$Label`: falló ($Detail)"
}

function Test-SetupExecutionResultsHaveFailures {
  param (
    [PSCustomObject[]]$results
  )

  return @($results | Where-Object { $_.Status -ne 'OK' -and $_.Status -ne 'Dry-run' -and $_.Status -ne 'Omitido' }).Count -gt 0
}

function Invoke-InteractiveSetupMenu {
  param (
    [bool]$DryRun = $false,
    [bool]$AssumeYes = $false
  )

  $menuCatalog = Get-SetupMenuCatalog
  Test-SetupMenuCatalog -menuCatalog $menuCatalog

  Clear-Host
  Write-Host ''
  Write-SetupBanner -menuCatalog $menuCatalog -DryRun $DryRun

  $menuSelection = Select-SetupMenuClassic -menuCatalog $menuCatalog

  if ($menuSelection.Cancelled) {
    LogWarning 'Instalación cancelada.'
    return
  }

  $selectedIndexes = @($menuSelection.SelectedIndexes)
  if ($selectedIndexes.Count -eq 0) {
    LogWarning 'No se seleccionaron elementos. No se instalará nada.'
    return
  }

  if (-not $AssumeYes -and -not (Confirm-SetupMenuSelection -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun)) {
    LogWarning 'Instalación cancelada.'
    return
  }

  Assert-SetupAdminRequirement -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  $results = Invoke-SelectedSetupMenuItems -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  Write-SetupExecutionSummary -results $results
  if (Test-SetupExecutionResultsHaveFailures -results $results) {
    throw 'Uno o más ítems de setup fallaron.'
  }
}

function Get-SetupUsage {
  return @'
Uso:
  setup.ps1 [--dry-run] [--yes] [--list] [id|función ...]

Opciones:
  --dry-run  Muestra qué se ejecutaría sin instalar nada.
  --yes      Omite la confirmación antes de ejecutar los ítems seleccionados.
  --list     Lista los ítems del catálogo (tabla en consola, TSV al redirigir).
  --help     Muestra esta ayuda.
'@
}

function ConvertTo-SetupArguments {
  param (
    [string[]]$Arguments
  )

  $commandArguments = @()
  $parsedArguments = [PSCustomObject]@{
    DryRun = $false
    AssumeYes = $false
    ShowHelp = $false
    ListItems = $false
    CommandArguments = @()
  }

  for ($argumentIndex = 0; $argumentIndex -lt $Arguments.Count; $argumentIndex++) {
    $argument = $Arguments[$argumentIndex]
    switch ($argument) {
      '--dry-run' { $parsedArguments.DryRun = $true }
      '--yes' { $parsedArguments.AssumeYes = $true }
      '-y' { $parsedArguments.AssumeYes = $true }
      '--help' { $parsedArguments.ShowHelp = $true }
      '-h' { $parsedArguments.ShowHelp = $true }
      '--list' { $parsedArguments.ListItems = $true }
      '--' {
        if ($argumentIndex + 1 -lt $Arguments.Count) {
          $commandArguments += @($Arguments[($argumentIndex + 1)..($Arguments.Count - 1)])
        }
        $argumentIndex = $Arguments.Count
      }
      default {
        if ($argument.StartsWith('--')) {
          throw "Opción no reconocida: $argument"
        }
        $commandArguments += $argument
      }
    }
  }

  $parsedArguments.CommandArguments = @($commandArguments)
  return $parsedArguments
}

function Write-SetupCatalogList {
  param (
    [PSCustomObject[]]$menuCatalog
  )

  # Redirected output keeps the tab-separated format for scripts.
  if ([Console]::IsOutputRedirected) {
    foreach ($menuItem in $menuCatalog) {
      Write-Output ("{0}`t{1}`t{2}" -f $menuItem.Id, $menuItem.FunctionName, $menuItem.Label)
    }
    return
  }

  Write-SetupBoxTop -Title "$(Get-SetupIcon 'Catalog') Catalogo · Windows ($($menuCatalog.Count))"
  foreach ($menuItem in $menuCatalog) {
    Write-Host '│ ' -ForegroundColor DarkGray -NoNewline
    Write-Host ('{0,-22} ' -f $menuItem.Id) -ForegroundColor DarkCyan -NoNewline
    Write-Host (Get-SetupMenuDisplayLabel -menuItem $menuItem)
  }
  Write-SetupBoxDivider
  Write-SetupBoxRow -Text "$(Get-SetupIcon 'Recommended') recomendado · $(Get-SetupIcon 'Admin') requiere admin · $(Get-SetupIcon 'Restart') requiere reinicio" -ForegroundColor DarkGray
  Write-SetupBoxBottom
}

function Invoke-SetupItemsByIdentifier {
  param (
    [PSCustomObject[]]$menuCatalog,
    [string[]]$itemIdentifiers,
    [bool]$DryRun = $false,
    [bool]$AssumeYes = $false
  )

  $selectedIndexes = @()
  foreach ($itemIdentifier in $itemIdentifiers) {
    $menuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $menuCatalog -ItemIdentifier $itemIdentifier
    if ($menuIndex -lt 0) {
      throw "El ítem '$itemIdentifier' no está permitido por el catálogo de setup."
    }
    $selectedIndexes += $menuIndex
  }

  Write-SetupBanner -menuCatalog $menuCatalog -DryRun $DryRun
  Assert-SetupAdminRequirement -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  if (-not $AssumeYes -and -not (Confirm-SetupMenuSelection -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun)) {
    LogWarning 'Instalación cancelada.'
    return
  }

  $results = Invoke-SelectedSetupMenuItems -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  Write-SetupExecutionSummary -results $results
  if (Test-SetupExecutionResultsHaveFailures -results $results) {
    throw 'Uno o más ítems de setup fallaron.'
  }
}

$parsedArguments = ConvertTo-SetupArguments -Arguments $args

if ($parsedArguments.ShowHelp) {
  Write-Host (Get-SetupUsage)
  exit
}

$menuCatalog = Get-SetupMenuCatalog
Test-SetupMenuCatalog -menuCatalog $menuCatalog

if ($parsedArguments.ListItems) {
  Write-SetupCatalogList -menuCatalog $menuCatalog
  exit
}

if ($parsedArguments.CommandArguments.Count -gt 0) {
  try {
    Invoke-SetupItemsByIdentifier -menuCatalog $menuCatalog -itemIdentifiers $parsedArguments.CommandArguments -DryRun $parsedArguments.DryRun -AssumeYes $parsedArguments.AssumeYes
  } catch {
    LogError $_.Exception.Message
    exit 1
  }
} else {
  try {
    Invoke-InteractiveSetupMenu -DryRun $parsedArguments.DryRun -AssumeYes $parsedArguments.AssumeYes
  } catch {
    LogError $_.Exception.Message
    exit 1
  }
}
