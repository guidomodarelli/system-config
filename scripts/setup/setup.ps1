# NOTA: Ejecutar este script como Administrador.

$SetupLatestVersionPolicy = 'latest-stable-official'

function LogError {
  param (
    [string]$message
  )
  Write-Host "[ ERROR ] $message" -ForegroundColor Red
}

function LogInfo {
  param (
    [string]$message
  )
  Write-Host "[ INFO ] $message" -ForegroundColor Blue
}

function LogWarning {
  param (
    [string]$message
  )
  Write-Host "[ WARNING ] $message" -ForegroundColor Yellow
}

function LogSuccess {
  param (
    [string]$message
  )
  Write-Host "[ SUCCESS ] $message" -ForegroundColor Green
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
  Install-WingetPackage BurntSushi.ripgrep.GNU
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
  $installedPesterModule = Get-InstalledModule -Name Pester -ErrorAction SilentlyContinue

  if ($null -ne $installedPesterModule -and $installedPesterModule.Version -ge $minimumSupportedPesterVersion) {
    LogInfo "Pester ya está instalado en versión $($installedPesterModule.Version). Actualizando a la última estable de la rama 5.x..."
  } elseif ($null -ne $installedPesterModule) {
    LogInfo "Pester está en versión $($installedPesterModule.Version). Actualizando a la rama 5.x..."
  } else {
    LogInfo 'Instalando Pester 5.x desde PSGallery...'
  }

  try {
    Install-Module -Name Pester -MinimumVersion '5.0.0' -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
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

  if ($menuItem.DefaultSelected) {
    return "@ $($menuItem.Label)"
  }

  return $menuItem.Label
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

function Get-SetupMenuRowSegments {
  param (
    [PSCustomObject]$menuItem,
    [bool]$IsSelected,
    [bool]$IsCursor
  )

  $foregroundColor = if ($IsCursor) { [ConsoleColor]::Black } else { [Console]::ForegroundColor }
  $backgroundColor = if ($IsCursor) { [ConsoleColor]::Gray } else { [Console]::BackgroundColor }
  $cursorMarker = if ($IsCursor) { '>' } else { ' ' }
  $selectionMarker = if ($IsSelected) { 'x' } else { ' ' }
  $cursorMarkerColor = if ($IsCursor) { [ConsoleColor]::Black } else { $foregroundColor }

  $segments = @(
    New-SetupMenuRowSegment -Text ' ' -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
    New-SetupMenuRowSegment -Text $cursorMarker -ForegroundColor $cursorMarkerColor -BackgroundColor $backgroundColor
    New-SetupMenuRowSegment -Text ' ' -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
    New-SetupMenuRowSegment -Text '[' -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
    New-SetupMenuRowSegment -Text $selectionMarker -ForegroundColor DarkGreen -BackgroundColor $backgroundColor
    New-SetupMenuRowSegment -Text '] ' -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
  )

  if ($menuItem.DefaultSelected) {
    $segments += New-SetupMenuRowSegment -Text '@' -ForegroundColor DarkYellow -BackgroundColor $backgroundColor
    $segments += New-SetupMenuRowSegment -Text " $($menuItem.Label)" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
  } else {
    $segments += New-SetupMenuRowSegment -Text $menuItem.Label -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
  }

  return $segments
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
    [bool]$IsCursor
  )

  Write-ClearedSetupMenuLineStart
  $rowSegments = Get-SetupMenuRowSegments -menuItem $menuItem -IsSelected $IsSelected -IsCursor $IsCursor
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
    New-SetupMenuReferenceRow -Shortcut 'q/ESC/Ctrl+C' -Description 'cancelar'
  )
}

function Get-SetupMenuDefaultMarkerSegments {
  return @(
    New-SetupMenuRowSegment -Text '  '
    New-SetupMenuRowSegment -Text '@' -ForegroundColor DarkYellow
    New-SetupMenuRowSegment -Text ' seleccionado por defecto'
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
  return [ConsoleColor]::DarkMagenta
}

function Write-SetupMenuReferenceFrameLine {
  param (
    [string]$Text
  )

  Write-Host $Text -ForegroundColor (Get-SetupMenuReferenceFrameColor)
}

function Write-SetupMenuReference {
  Write-Host ''
  Write-SetupMenuReferenceFrameLine -Text '  +--------------------+--------------------------+'
  Write-SetupMenuReferenceFrameLine -Text '  | Atajos del menu                               |'
  Write-SetupMenuReferenceFrameLine -Text '  +--------------------+--------------------------+'

  foreach ($referenceRow in Get-SetupMenuReferenceRows) {
    Write-Host '  | ' -ForegroundColor (Get-SetupMenuReferenceFrameColor) -NoNewline
    Write-Host ('{0,-18}' -f $referenceRow.Shortcut) -ForegroundColor $referenceRow.ShortcutColor -NoNewline
    Write-Host ' | ' -ForegroundColor (Get-SetupMenuReferenceFrameColor) -NoNewline
    Write-Host ('{0,-24}' -f $referenceRow.Description) -NoNewline
    Write-Host ' |' -ForegroundColor (Get-SetupMenuReferenceFrameColor)
  }

  Write-SetupMenuReferenceFrameLine -Text '  +--------------------+--------------------------+'
  Write-Host ''
}

function Get-SetupMenuRangeSegments {
  param (
    [int]$FirstVisibleItemNumber,
    [int]$LastVisibleItemNumber,
    [int]$TotalItemCount
  )

  return @(
    New-SetupMenuRowSegment -Text '  Elementos '
    New-SetupMenuRowSegment -Text $FirstVisibleItemNumber -ForegroundColor DarkCyan
    New-SetupMenuRowSegment -Text '-'
    New-SetupMenuRowSegment -Text $LastVisibleItemNumber -ForegroundColor DarkCyan
    New-SetupMenuRowSegment -Text ' de '
    New-SetupMenuRowSegment -Text $TotalItemCount -ForegroundColor DarkCyan
  )
}

function Write-SetupMenuRange {
  param (
    [int]$FirstVisibleItemNumber,
    [int]$LastVisibleItemNumber,
    [int]$TotalItemCount
  )

  Write-ClearedSetupMenuLineStart
  $rangeSegments = Get-SetupMenuRangeSegments -FirstVisibleItemNumber $FirstVisibleItemNumber -LastVisibleItemNumber $LastVisibleItemNumber -TotalItemCount $TotalItemCount
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
  Write-SetupMenuRange -FirstVisibleItemNumber ($windowStartIndex + 1) -LastVisibleItemNumber $windowEndIndex -TotalItemCount $menuCatalog.Count
  Write-SetupMenuDefaultMarkerLegend

  if ($windowStartIndex -gt 0) {
    Write-ClearedSetupMenuLine -text '  Hay mas elementos arriba'
  } else {
    Write-ClearedSetupMenuLine -text ''
  }

  for ($menuIndex = $windowStartIndex; $menuIndex -lt $windowEndIndex; $menuIndex++) {
    Write-SetupMenuRow -menuItem $menuCatalog[$menuIndex] -IsSelected $selectedIndexes.Contains($menuIndex) -IsCursor ($menuIndex -eq $cursorIndex)
  }

  if ($windowEndIndex -lt $menuCatalog.Count) {
    Write-ClearedSetupMenuLine -text '  Hay mas elementos abajo'
  } else {
    Write-ClearedSetupMenuLine -text ''
  }
}

function Get-ClassicSetupMenuItemRowOffset {
  param (
    [int]$menuIndex,
    [int]$windowStartIndex
  )

  return 3 + ($menuIndex - $windowStartIndex)
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
    [int]$menuTop
  )

  $rowTop = $menuTop + (Get-ClassicSetupMenuItemRowOffset -menuIndex $menuIndex -windowStartIndex $windowStartIndex)
  [Console]::SetCursorPosition(0, $rowTop)
  Write-SetupMenuRow -menuItem $menuCatalog[$menuIndex] -IsSelected $selectedIndexes.Contains($menuIndex) -IsCursor ($menuIndex -eq $cursorIndex)
}

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
  Write-ClearedSetupMenuLine -text ("  Buscar: {0}" -f $query)
  Write-ClearedSetupMenuLine -text ("  Coincidencias: {0}" -f $filteredIndexes.Count)
  Write-ClearedSetupMenuLine -text '  ENTER: volver'
  Write-ClearedSetupMenuLine -text '  ESPACIO: alternar'
  Write-ClearedSetupMenuLine -text '  ESC: cancelar'

  if ($filteredIndexes.Count -eq 0) {
    for ($emptyLineIndex = 0; $emptyLineIndex -lt $visibleItemCount; $emptyLineIndex++) {
      if ($emptyLineIndex -eq 0) {
        Write-ClearedSetupMenuLine -text '  Sin coincidencias'
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
    Write-SetupMenuRow -menuItem $menuCatalog[$menuIndex] -IsSelected $selectedIndexes.Contains($menuIndex) -IsCursor ($visibleIndex -eq $filteredCursorIndex)
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

function Get-SetupMenuVisibleItemCount {
  param (
    [int]$itemCount
  )

  $visibleItemCount = [Console]::WindowHeight - 18
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

  return $visibleItemCount + 4
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

  if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
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

  while ($true) {
    Clear-Host
    Write-Host ''
    Write-Host '  Busqueda de paquetes'
    Write-Host '  Escribi para filtrar en vivo. Backspace borra.'
    Write-Host ''
    Write-SearchSetupMenu -menuCatalog $menuCatalog -filteredIndexes $filteredIndexes -selectedIndexes $selectedIndexes -filteredCursorIndex $filteredCursorIndex -query $query -visibleItemCount $visibleItemCount
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::Escape -or ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control))) {
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
        Write-ClassicSetupMenuItemRowAt -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -menuIndex $cursorIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -menuTop $menuTop
      } elseif ($previousCursorIndex -ne $cursorIndex) {
        Write-ClassicSetupMenuItemRowAt -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -menuIndex $previousCursorIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -menuTop $menuTop
        Write-ClassicSetupMenuItemRowAt -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -menuIndex $cursorIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -menuTop $menuTop
      }

      [Console]::SetCursorPosition(0, $menuTop + $renderedLineCount)
    }
  } finally {
    [Console]::TreatControlCAsInput = $previousTreatControlCAsInput
  }
}

function Invoke-SelectedSetupMenuItems {
  param (
    [PSCustomObject[]]$menuCatalog,
    [int[]]$selectedIndexes,
    [bool]$DryRun = $false
  )

  $results = @()

  foreach ($selectedIndex in $selectedIndexes | Sort-Object) {
    $menuItem = $menuCatalog[$selectedIndex]
    Write-Host ''
    if ($DryRun) {
      LogInfo "Dry-run: se ejecutaría $($menuItem.Label)."
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Dry-run'; Detail = 'No ejecutado'; RequiresRestart = $menuItem.RequiresRestart }
      continue
    }

    LogInfo "Instalando: $($menuItem.Label)"
    try {
      if (-not (Test-SetupMenuItemSupportsCurrentPlatform -Platforms $menuItem.Platforms)) {
        LogWarning "Omitido por plataforma: $($menuItem.Label)"
        $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Omitido'; Detail = 'Plataforma no soportada'; RequiresRestart = $false }
        continue
      }

      $global:LASTEXITCODE = 0
      & $menuItem.FunctionName | Out-Host
      if ($global:LASTEXITCODE -ne 0) {
        throw "La función '$($menuItem.FunctionName)' terminó con código $global:LASTEXITCODE."
      }

      LogSuccess "OK: $($menuItem.Label)"
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'OK'; Detail = ''; RequiresRestart = $menuItem.RequiresRestart }
    } catch {
      LogError "Falló $($menuItem.Label): $($_.Exception.Message)"
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Falló'; Detail = $_.Exception.Message; RequiresRestart = $false }
    }
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
  if ($DryRun) {
    LogWarning 'Modo dry-run activo: no se instalará nada.'
  }

  LogInfo "Elementos seleccionados ($($selectedIndexes.Count)):"
  foreach ($selectedIndex in $selectedIndexes | Sort-Object) {
    Write-Host "  - $($menuCatalog[$selectedIndex].Label)"
  }

  Write-Host ''
  Write-Host '  ENTER: continuar'
  Write-Host '  q/Ctrl+C: cancelar'

  $previousTreatControlCAsInput = [Console]::TreatControlCAsInput
  [Console]::TreatControlCAsInput = $true
  try {
    while ($true) {
      $key = [Console]::ReadKey($true)
      if ($key.Key -eq [ConsoleKey]::Enter) {
        return $true
      }

      if ($key.Key -eq [ConsoleKey]::Escape -or $key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q' -or ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control))) {
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

  Write-Host ''
  LogInfo 'Resumen de instalación:'
  foreach ($result in $results) {
    if ($result.Status -eq 'OK') {
      LogSuccess "$($result.Label): OK"
    } elseif ($result.Status -eq 'Dry-run') {
      LogWarning "$($result.Label): dry-run"
    } elseif ($result.Status -eq 'Omitido') {
      LogWarning "$($result.Label): omitido"
    } else {
      LogError (Get-SetupFailureSummaryMessage -Label $result.Label -Detail $result.Detail)
    }
  }

  $restartRequired = @($results | Where-Object { $_.Status -eq 'OK' -and $_.RequiresRestart }).Count -gt 0
  if ($restartRequired) {
    LogWarning 'Algunos cambios requieren reiniciar o abrir una nueva sesión para aplicarse.'
  }
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
  Write-Host '  ======================================'
  Write-Host '      Instalador de setup del sistema'
  Write-Host '  ======================================'

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

  LogInfo "Se procesarán $($selectedIndexes.Count) elemento(s) seleccionado(s)."
  Assert-SetupAdminRequirement -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  $results = Invoke-SelectedSetupMenuItems -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  Write-SetupExecutionSummary -results $results
  if (Test-SetupExecutionResultsHaveFailures -results $results) {
    throw 'Uno o más ítems de setup fallaron.'
  }
  LogSuccess 'Proceso completo.'
}

function Get-SetupUsage {
  return @'
Uso:
  setup.ps1 [--dry-run] [--yes] [--list] [id|función ...]

Opciones:
  --dry-run  Muestra qué se ejecutaría sin instalar nada.
  --yes      Omite la confirmación antes de ejecutar los ítems seleccionados.
  --list     Lista los ítems disponibles del catálogo.
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

  foreach ($menuItem in $menuCatalog) {
    Write-Host ("{0}`t{1}`t{2}" -f $menuItem.Id, $menuItem.FunctionName, $menuItem.Label)
  }
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
