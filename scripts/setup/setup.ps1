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

function Winget-Install {
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
  Winget-Install Espanso.Espanso

  _espanso service register
  _espanso start
}

function Install-Git {
  Winget-Install Git.Git
}

function Install-VsCode {
  Winget-Install Microsoft.VisualStudioCode
}

function Install-Vlc {
  Winget-Install VideoLAN.VLC
}

function Install-ObsStudio {
  Winget-Install OBSProject.OBSStudio
}

function Install-Lazygit {
  Winget-Install JesseDuffield.lazygit
}

function Install-GitDelta {
  Winget-Install dandavison.delta
}

function Install-FdFind {
  Winget-Install sharkdp.fd
}

function Install-Curl {
  Winget-Install cURL.cURL
}

function Install-Fzf {
  Winget-Install junegunn.fzf
}

function Install-RipGrep {
  Winget-Install BurntSushi.ripgrep.GNU
}

function Install-Bitwarden {
  Winget-Install Bitwarden.Bitwarden
}

function Install-Bat {
  Winget-Install sharkdp.bat
}

function Install-Eza {
  # https://eza.rocks/
  Winget-Install eza-community.eza
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
  Winget-Install 9PNRBTZXMB4Z
}

function Install-WhatsApp {
  Winget-Install 9NKSQGP7F2NH
}

function Install-Vagrant {
  Winget-Install Hashicorp.Vagrant
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
  Winget-Install Microsoft.PowerToys
}

function Install-Flameshot {
  Winget-Install Flameshot.Flameshot
}

function Install-7z {
  Winget-Install 7zip.7zip
}

function Install-Mise-In-Place {
  # https://github.com/jdx/mise?tab=readme-ov-file#what-is-it
  # Like asdf (or nvm or pyenv but for any language)
  Winget-Install jdx.mise
}

function Install-Ghq {
  Winget-Install x-motemen.ghq
}

function Install-AutoHotkey {
  Winget-Install AutoHotkey.AutoHotkey
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
  Install-Mise-In-Place

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
  LogError "Please run this script as Administrator."
  exit
}

if ($args.Count -gt 0) {
  $functionName = $args[0]
  if (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue) {
    LogInfo "Invoking function: $functionName"
    Invoke-Expression $functionName
  } else {
    LogInfo "Function "$functionName" does not exist."
  }
} else {
  LogInfo "No arguments were passed. Running default functions."
  Main
}
