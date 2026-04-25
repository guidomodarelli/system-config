# NOTE: Run this script as Administrator

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


function Install-Choco {
  if (-Not (Test-Path 'C:\ProgramData\chocolatey\bin\choco.exe')) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    LogSuccess "Chocolatey has been installed successfully."
  } else {
    LogWarning "Chocolatey is already installed."
  }
}

function Install-Scoop {
  if (-Not (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    LogSuccess "Scoop has been installed successfully."
  } else {
    LogWarning "Scoop is already installed."
  }
}

function Install-ChocoPackage {
  param (
    [string[]]$packages
  )
  foreach ($package in $packages) {
    if (choco list | Select-String -Pattern $package) {
      LogWarning "The package '$package' is already installed. Upgrading..."
      choco upgrade $package --confirm --no-progress
      LogSuccess "The package '$package' has been upgraded successfully."
    } else {
      LogInfo "Installing the package '$package'..."
      choco install $package --confirm --no-progress
      LogSuccess "The package '$package' has been installed successfully."
    }
  }
}

function Install-WingetPackage {
  param (
    [string[]]$appIds
  )
  foreach ($appId in $appIds) {
    $appName = (winget search -e --id $appId | Select-Object -Last 1 | ForEach-Object { $_.Split(" ")[0] })
    LogInfo "Installing the package '$appName'..."
    winget install -e --id $appId
    LogSuccess "The package '$appName' has been installed successfully."
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

function Install-Espanso {
  Install-WingetPackage Espanso.Espanso

  _espanso service register
  _espanso start
}

function Install-Git {
  Install-WingetPackage Git.Git
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
  LogInfo "Checking if WSL is installed..."
  if (wsl --list --quiet) {
    LogWarning "WSL is already installed."
  } else {
    LogInfo "Installing WSL..."
    wsl --install
    LogSuccess "WSL has been installed successfully."
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
  LogInfo "Enabling Hyper-V..."
  if (-not (Test-HyperVAvailability)) {
    LogWarning "Hyper-V is not available on this Windows edition."
    return
  }
  try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    if ($feature.State -eq 'Enabled') {
      LogWarning "Hyper-V is already enabled."
      return
    }
    $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) {
      LogSuccess "Hyper-V has been enabled successfully. A restart is required to complete the installation."
    } else {
      LogSuccess "Hyper-V has been enabled successfully."
    }
  } catch {
    LogError ("Failed to enable Hyper-V. {0}" -f $_.Exception.Message)
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

function New-SetupMenuItem {
  param (
    [string]$Label,
    [string]$FunctionName,
    [bool]$DefaultSelected = $false
  )

  return [PSCustomObject]@{
    Label = $Label
    FunctionName = $FunctionName
    DefaultSelected = $DefaultSelected
  }
}

function Get-SetupMenuCatalog {
  return @(
    New-SetupMenuItem -Label 'Chocolatey' -FunctionName 'Install-Choco' -DefaultSelected $true
    New-SetupMenuItem -Label 'Git' -FunctionName 'Install-Git' -DefaultSelected $true
    New-SetupMenuItem -Label 'fzf' -FunctionName 'Install-Fzf' -DefaultSelected $true
    New-SetupMenuItem -Label 'ripgrep' -FunctionName 'Install-RipGrep' -DefaultSelected $true
    New-SetupMenuItem -Label 'fd-find' -FunctionName 'Install-FdFind' -DefaultSelected $true
    New-SetupMenuItem -Label 'curl' -FunctionName 'Install-Curl' -DefaultSelected $true
    New-SetupMenuItem -Label 'bat' -FunctionName 'Install-Bat' -DefaultSelected $true
    New-SetupMenuItem -Label 'eza' -FunctionName 'Install-Eza' -DefaultSelected $true
    New-SetupMenuItem -Label 'ghq' -FunctionName 'Install-Ghq' -DefaultSelected $true
    New-SetupMenuItem -Label 'Visual Studio Code' -FunctionName 'Install-VsCode' -DefaultSelected $true
    New-SetupMenuItem -Label 'mise-en-place' -FunctionName 'Install-Mise-In-Place' -DefaultSelected $true
    New-SetupMenuItem -Label 'fnm' -FunctionName 'Install-fnm' -DefaultSelected $true
    New-SetupMenuItem -Label 'Python' -FunctionName 'Install-Python' -DefaultSelected $true
    New-SetupMenuItem -Label 'Fuentes' -FunctionName 'Install-Fonts' -DefaultSelected $true
    New-SetupMenuItem -Label 'Espanso' -FunctionName 'Install-Espanso' -DefaultSelected $true
    New-SetupMenuItem -Label 'PowerToys' -FunctionName 'Install-PowerToys' -DefaultSelected $true
    New-SetupMenuItem -Label 'Scoop' -FunctionName 'Install-Scoop'
    New-SetupMenuItem -Label 'WSL' -FunctionName 'Install-WSL'
    New-SetupMenuItem -Label 'AutoHotkey' -FunctionName 'Install-AutoHotkey'
    New-SetupMenuItem -Label 'VLC' -FunctionName 'Install-Vlc'
    New-SetupMenuItem -Label 'WhatsApp' -FunctionName 'Install-WhatsApp'
    New-SetupMenuItem -Label 'Bitwarden' -FunctionName 'Install-Bitwarden'
    New-SetupMenuItem -Label '7-Zip' -FunctionName 'Install-7z'
    New-SetupMenuItem -Label 'Hyper-V' -FunctionName 'Enable-HyperV'
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

function Write-ClassicSetupMenu {
  param (
    [PSCustomObject[]]$menuCatalog,
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$cursorIndex,
    [int]$windowStartIndex,
    [int]$visibleItemCount
  )

  $windowEndIndex = $windowStartIndex + $visibleItemCount
  Write-ClearedSetupMenuLine -text ("  Elementos {0}-{1} de {2}" -f ($windowStartIndex + 1), $windowEndIndex, $menuCatalog.Count)

  if ($windowStartIndex -gt 0) {
    Write-ClearedSetupMenuLine -text '  Hay mas elementos arriba'
  } else {
    Write-ClearedSetupMenuLine -text ''
  }

  for ($menuIndex = $windowStartIndex; $menuIndex -lt $windowEndIndex; $menuIndex++) {
    $selectionMarker = if ($selectedIndexes.Contains($menuIndex)) { 'x' } else { ' ' }
    $cursorMarker = if ($menuIndex -eq $cursorIndex) { '>' } else { ' ' }
    $displayLabel = Get-SetupMenuDisplayLabel -menuItem $menuCatalog[$menuIndex]

    if ($menuIndex -eq $cursorIndex) {
      Write-ClearedSetupMenuLine -text (" {0} [{1}] {2}" -f $cursorMarker, $selectionMarker, $displayLabel) -ForegroundColor Black -BackgroundColor Gray
    } else {
      Write-ClearedSetupMenuLine -text (" {0} [{1}] {2}" -f $cursorMarker, $selectionMarker, $displayLabel)
    }
  }

  if ($windowEndIndex -lt $menuCatalog.Count) {
    Write-ClearedSetupMenuLine -text '  Hay mas elementos abajo'
  } else {
    Write-ClearedSetupMenuLine -text ''
  }
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
    $selectionMarker = if ($selectedIndexes.Contains($menuIndex)) { 'x' } else { ' ' }
    $cursorMarker = if ($visibleIndex -eq $filteredCursorIndex) { '>' } else { ' ' }
    $displayLabel = Get-SetupMenuDisplayLabel -menuItem $menuCatalog[$menuIndex]

    if ($visibleIndex -eq $filteredCursorIndex) {
      Write-ClearedSetupMenuLine -text (" {0} [{1}] {2}" -f $cursorMarker, $selectionMarker, $displayLabel) -ForegroundColor Black -BackgroundColor Gray
    } else {
      Write-ClearedSetupMenuLine -text (" {0} [{1}] {2}" -f $cursorMarker, $selectionMarker, $displayLabel)
    }
  }

  for ($emptyLineIndex = $visibleSearchCount; $emptyLineIndex -lt $visibleItemCount; $emptyLineIndex++) {
    Write-ClearedSetupMenuLine -text ''
  }

}

function Write-ClearedSetupMenuLine {
  param (
    [string]$text,
    [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor,
    [ConsoleColor]$BackgroundColor = [Console]::BackgroundColor
  )

  [Console]::Write("`r")
  [Console]::Write((' ' * ([Console]::WindowWidth - 1)))
  [Console]::Write("`r")
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

function Invoke-SetupMenuSearch {
  param (
    [PSCustomObject[]]$menuCatalog,
    [System.Collections.Generic.HashSet[int]]$selectedIndexes,
    [int]$cursorIndex,
    [int]$visibleItemCount
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
      return [PSCustomObject]@{ Cancelled = $true; CursorIndex = $cursorIndex }
    }

    if ($key.Key -eq [ConsoleKey]::Enter) {
      if ($filteredIndexes.Count -eq 0) {
        return [PSCustomObject]@{ Cancelled = $false; CursorIndex = $cursorIndex }
      }

      return [PSCustomObject]@{ Cancelled = $false; CursorIndex = $filteredIndexes[$filteredCursorIndex] }
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
        if ($selectedIndexes.Contains($menuIndex)) {
          [void]$selectedIndexes.Remove($menuIndex)
        } else {
          [void]$selectedIndexes.Add($menuIndex)
        }
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
  $renderedLineCount = $visibleItemCount + 3
  $selectedIndexes = Get-DefaultSetupMenuIndexes -menuCatalog $menuCatalog

  try {
    Write-Host ''
    Write-Host '  +--------------------+--------------------------+'
    Write-Host '  | Referencia del menu                           |'
    Write-Host '  +--------------------+--------------------------+'
    Write-Host '  | @                  | seleccionado por defecto |'
    Write-Host '  | Arriba/Abajo/j/k   | navegar                  |'
    Write-Host '  | PgUp/PgDn/Home/End | saltar                   |'
    Write-Host '  | /                  | buscar                   |'
    Write-Host '  | ESPACIO            | alternar                 |'
    Write-Host '  | a                  | alternar todo            |'
    Write-Host '  | r                  | restaurar defaults       |'
    Write-Host '  | ENTER              | confirmar                |'
    Write-Host '  | q/ESC/Ctrl+C       | cancelar                 |'
    Write-Host '  +--------------------+--------------------------+'
    Write-Host ''

    while ($true) {
      Write-ClassicSetupMenu -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -visibleItemCount $visibleItemCount

      $pressedKey = Read-SetupMenuKey
      $shouldSkipCursorReposition = $false

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
          if ($selectedIndexes.Contains($cursorIndex)) {
            [void]$selectedIndexes.Remove($cursorIndex)
          } else {
            [void]$selectedIndexes.Add($cursorIndex)
          }
        }
        'All' {
          if ($selectedIndexes.Count -eq $menuCatalog.Count) {
            $selectedIndexes.Clear()
          } else {
            for ($menuIndex = 0; $menuIndex -lt $menuCatalog.Count; $menuIndex++) {
              [void]$selectedIndexes.Add($menuIndex)
            }
          }
        }
        'Defaults' {
          $selectedIndexes = Get-DefaultSetupMenuIndexes -menuCatalog $menuCatalog
        }
        'Search' {
          $searchResult = Invoke-SetupMenuSearch -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -cursorIndex $cursorIndex -visibleItemCount $visibleItemCount
          if (-not $searchResult.Cancelled) {
            $cursorIndex = $searchResult.CursorIndex
          }
          Clear-Host
          Write-Host ''
          Write-Host '  +--------------------+--------------------------+'
          Write-Host '  | Referencia del menu                           |'
          Write-Host '  +--------------------+--------------------------+'
          Write-Host '  | @                  | seleccionado por defecto |'
          Write-Host '  | Arriba/Abajo/j/k   | navegar                  |'
          Write-Host '  | PgUp/PgDn/Home/End | saltar                   |'
          Write-Host '  | /                  | buscar                   |'
          Write-Host '  | ESPACIO            | alternar                 |'
          Write-Host '  | a                  | alternar todo            |'
          Write-Host '  | r                  | restaurar defaults       |'
          Write-Host '  | ENTER              | confirmar                |'
          Write-Host '  | q/ESC/Ctrl+C       | cancelar                 |'
          Write-Host '  +--------------------+--------------------------+'
          Write-Host ''
          $shouldSkipCursorReposition = $true
        }
        'Enter' {
          Write-Host ''
          return [PSCustomObject]@{ Cancelled = $false; SelectedIndexes = @($selectedIndexes) }
        }
        'Cancel' {
          Write-Host ''
          return [PSCustomObject]@{ Cancelled = $true; SelectedIndexes = @() }
        }
      }

      $windowStartIndex = Get-SetupMenuWindowStartIndex -cursorIndex $cursorIndex -windowStartIndex $windowStartIndex -visibleItemCount $visibleItemCount -itemCount $menuCatalog.Count
      if ($shouldSkipCursorReposition) {
        continue
      }

      $redrawTop = [Math]::Max(0, [Console]::CursorTop - $renderedLineCount)
      [Console]::SetCursorPosition(0, $redrawTop)
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
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Dry-run'; Detail = 'No ejecutado' }
      continue
    }

    LogInfo "Instalando: $($menuItem.Label)"
    try {
      $global:LASTEXITCODE = 0
      & $menuItem.FunctionName
      if ($global:LASTEXITCODE -ne 0) {
        throw "La función '$($menuItem.FunctionName)' terminó con código $global:LASTEXITCODE."
      }

      LogSuccess "OK: $($menuItem.Label)"
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'OK'; Detail = '' }
    } catch {
      LogError "Falló $($menuItem.Label): $($_.Exception.Message)"
      $results += [PSCustomObject]@{ Label = $menuItem.Label; Status = 'Falló'; Detail = $_.Exception.Message }
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
    } else {
      LogError "$($result.Label): falló ($($result.Detail))"
    }
  }
}

function Invoke-InteractiveSetupMenu {
  param (
    [bool]$DryRun = $false
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

  if (-not (Confirm-SetupMenuSelection -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun)) {
    LogWarning 'Instalación cancelada.'
    return
  }

  LogInfo "Se procesarán $($selectedIndexes.Count) elemento(s) seleccionado(s)."
  $results = Invoke-SelectedSetupMenuItems -menuCatalog $menuCatalog -selectedIndexes $selectedIndexes -DryRun $DryRun
  Write-SetupExecutionSummary -results $results
  LogSuccess 'Proceso completo.'
}

function Main {
  # Package Managers
  # Install-Scoop
  Install-Choco

  # Development Tools
  Install-Git
  Install-Ghq
  Install-VsCode
  Install-Mise-In-Place
  Install-fnm

  # Programming Languages & Environments
  Install-Python
  Install-WSL

  # Command Line Utilities
  Install-FdFind
  Install-Curl
  Install-Fzf
  Install-RipGrep
  Install-Bat
  Install-Eza

  # Fonts
  Install-Fonts

  # Productivity Tools
  Install-Espanso
  Install-PowerToys
  Install-AutoHotkey

  # Media & Entertainment
  Install-Vlc

  # Communication
  Install-WhatsApp

  # Security & Password Management
  Install-Bitwarden

  # Utilities
  Install-7z

  # Always run this function last
  Enable-HyperV
}

$dryRun = $args -contains '--dry-run'
$commandArguments = @($args | Where-Object { $_ -ne '--dry-run' })

if (-not $dryRun -and -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  LogError "Please run this script as Administrator."
  exit
}

if ($args.Count -gt 0) {
  if ($commandArguments.Count -eq 0) {
    Invoke-InteractiveSetupMenu -DryRun $dryRun
    exit
  }

  $functionName = $commandArguments[0]
  if (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue) {
    if ($dryRun) {
      LogWarning "Dry-run: se ejecutaría la función '$functionName'."
      exit
    }

    LogInfo "Invocando función: $functionName"
    & $functionName
  } else {
    LogInfo "La función '$functionName' no existe."
  }
} else {
  Invoke-InteractiveSetupMenu
}
