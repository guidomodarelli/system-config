# NOTE: Run this script as Administrator

function Write-ErrorMessage {
  param (
    [string]$message
  )
  Write-Host "[ ERROR ] $message" -ForegroundColor Red
}

function Write-InfoMessage {
  param (
    [string]$message
  )
  Write-Host "[ INFO ] $message" -ForegroundColor Blue
}

function Write-WarningMessage {
  param (
    [string]$message
  )
  Write-Host "[ WARNING ] $message" -ForegroundColor Yellow
}

function Write-SuccessMessage {
  param (
    [string]$message
  )
  Write-Host "[ SUCCESS ] $message" -ForegroundColor Green
}


function Install-Choco {
  if (-Not (Test-Path 'C:\ProgramData\chocolatey\bin\choco.exe')) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-SuccessMessage "Chocolatey has been installed successfully."
  } else {
    Write-WarningMessage "Chocolatey is already installed."
  }
}

function Install-Scoop {
  if (-Not (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Write-SuccessMessage "Scoop has been installed successfully."
  } else {
    Write-WarningMessage "Scoop is already installed."
  }
}

function Install-ChocoPackages {
  param (
    [string[]]$packages
  )
  foreach ($package in $packages) {
    if (choco list | Select-String -Pattern $package) {
      Write-WarningMessage "The package '$package' is already installed. Upgrading..."
      choco upgrade $package --confirm --no-progress
      Write-SuccessMessage "The package '$package' has been upgraded successfully."
    } else {
      Write-InfoMessage "Installing the package '$package'..."
      choco install $package --confirm --no-progress
      Write-SuccessMessage "The package '$package' has been installed successfully."
    }
  }
}

function Install-WingetPackages {
  param (
    [string[]]$appIds
  )
  foreach ($appId in $appIds) {
    $appName = (winget search -e --id $appId | Select-Object -Last 1 | ForEach-Object { $_.Split(" ")[0] })
    Write-InfoMessage "Installing the package '$appName'..."
    winget install -e --id $appId
    Write-SuccessMessage "The package '$appName' has been installed successfully."
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
  Install-ChocoPackages -packages $fonts
}

function _espanso {
  & "$env:USERPROFILE\AppData\Local\Programs\Espanso\espanso.cmd" @args
}

function Install-Espanso {
  Install-WingetPackages Espanso.Espanso

  _espanso service register
  _espanso start
}

function Install-Git {
  Install-WingetPackages Git.Git
}

function Install-VsCode {
  Install-WingetPackages Microsoft.VisualStudioCode
}

function Install-Vlc {
  Install-WingetPackages VideoLAN.VLC
}

function Install-ObsStudio {
  Install-WingetPackages OBSProject.OBSStudio
}

function Install-Lazygit {
  Install-WingetPackages JesseDuffield.lazygit
}

function Install-GitDelta {
  Install-WingetPackages dandavison.delta
}

function Install-FdFind {
  Install-WingetPackages sharkdp.fd
}

function Install-Curl {
  Install-WingetPackages cURL.cURL
}

function Install-Fzf {
  Install-WingetPackages junegunn.fzf
}

function Install-RipGrep {
  Install-WingetPackages BurntSushi.ripgrep.GNU
}

function Install-Bitwarden {
  Install-WingetPackages Bitwarden.Bitwarden
}

function Install-Bat {
  Install-WingetPackages sharkdp.bat
}

function Install-Eza {
  # https://eza.rocks/
  Install-WingetPackages eza-community.eza
}

function Install-WSL {
  Write-InfoMessage "Checking if WSL is installed..."
  if (wsl --list --quiet) {
    Write-WarningMessage "WSL is already installed."
  } else {
    Write-InfoMessage "Installing WSL..."
    wsl --install
    Write-SuccessMessage "WSL has been installed successfully."
  }
}

function Install-Python {
  Install-WingetPackages 9PNRBTZXMB4Z
}

function Install-WhatsApp {
  Install-WingetPackages 9NKSQGP7F2NH
}

function Install-Vagrant {
  Install-WingetPackages Hashicorp.Vagrant
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
  Write-InfoMessage "Enabling Hyper-V..."
  if (-not (Test-HyperVAvailability)) {
    Write-WarningMessage "Hyper-V is not available on this Windows edition."
    return
  }
  try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    if ($feature.State -eq 'Enabled') {
      Write-WarningMessage "Hyper-V is already enabled."
      return
    }
    $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) {
      Write-SuccessMessage "Hyper-V has been enabled successfully. A restart is required to complete the installation."
    } else {
      Write-SuccessMessage "Hyper-V has been enabled successfully."
    }
  } catch {
    Write-ErrorMessage ("Failed to enable Hyper-V. {0}" -f $_.Exception.Message)
  }
}

function Install-PowerToys {
  Install-WingetPackages Microsoft.PowerToys
}

function Install-Flameshot {
  Install-WingetPackages Flameshot.Flameshot
}

function Install-7z {
  Install-WingetPackages 7zip.7zip
}

function Install-Volta {
  Install-WingetPackages Volta.Volta
}

function Install-Ghq {
  Install-WingetPackages x-motemen.ghq
}

function Install-AutoHotkey {
  Install-WingetPackages AutoHotkey.AutoHotkey
}

function Main {
  # Package Managers
  # Install-Scoop
  Install-Choco

  # Development Tools
  Install-Git
  Install-Lazygit
  Install-GitDelta
  Install-Ghq
  Install-VsCode
  Install-Volta

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
  Install-Flameshot

  # Media & Entertainment
  Install-Vlc
  Install-ObsStudio

  # Communication
  Install-WhatsApp

  # Security & Password Management
  Install-Bitwarden

  # Utilities
  Install-7z

  # Virtualization
  Install-Vagrant

  # Always run this function last
  Enable-HyperV
}

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-ErrorMessage "Please run this script as Administrator."
  exit
}

if ($args.Count -gt 0) {
  $functionName = $args[0]
  if (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue) {
    Write-InfoMessage "Invoking function: $functionName"
    Invoke-Expression $functionName
  } else {
    Write-InfoMessage "Function "$functionName" does not exist."
  }
} else {
  Write-InfoMessage "No arguments were passed. Running default functions."
  Main
}
