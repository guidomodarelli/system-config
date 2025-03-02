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

	Remove-Item -Recurse -Force C:\Users\Guido\AppData\Roaming\espanso\
	New-Item -ItemType SymbolicLink -Path C:\Users\Guido\AppData\Roaming\espanso\ -Target C:\Users\Guido\system-config\files\.config\espanso\

	_espanso service register
	_espanso start
}

function Install-LazyVim {
	Write-InfoMessage "Installing LazyVim..."

	# Backup existing Neovim directory
	Write-InfoMessage "Checking for existing Neovim directory..."
	if (Test-Path $env:LOCALAPPDATA\nvim) {
		if (Test-Path $env:LOCALAPPDATA\nvim.bak) {
			Remove-Item -Recurse -Force $env:LOCALAPPDATA\nvim.bak
			Write-WarningMessage "Existing nvim.bak has been removed."
		}
		# required
		Move-Item $env:LOCALAPPDATA\nvim $env:LOCALAPPDATA\nvim.bak
		Write-SuccessMessage "Existing Neovim directory has been backed up."
	}

	# Backup existing Neovim data directory
	Write-InfoMessage "Checking for existing Neovim data directory..."
	if (Test-Path $env:LOCALAPPDATA\nvim-data) {
		if (Test-Path $env:LOCALAPPDATA\nvim-data.bak) {
			Remove-Item -Recurse -Force $env:LOCALAPPDATA\nvim-data.bak
			Write-WarningMessage "Existing nvim-data.bak has been removed."
		}
		# optional but recommended
		Move-Item $env:LOCALAPPDATA\nvim-data $env:LOCALAPPDATA\nvim-data.bak
		Write-SuccessMessage "Existing Neovim data directory has been backed up."
	}

	# Clone LazyVim repository
	Write-InfoMessage "Cloning LazyVim repository..."
	git clone https://github.com/LazyVim/starter $env:LOCALAPPDATA\nvim
	Write-SuccessMessage "LazyVim repository cloned successfully."

	Remove-Item $env:LOCALAPPDATA\nvim\.git -Recurse -Force
	Write-SuccessMessage "LazyVim has been installed successfully."
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

function Install-PeekScreenRecorder {
	Install-WingetPackages XP8CD3D3Q50MS2
}

function Install-Lazygit {
	Install-WingetPackages JesseDuffield.lazygit
}

function Install-GitDelta {
	Install-WingetPackages dandavison.delta
}

function Install-NeoVim {
	Install-WingetPackages Neovim.Neovim
}

function Install-FdFind {
	Install-WingetPackages sharkdp.fd
}

function Install-Btop {
	Install-WingetPackages aristocratos.btop4win
}

function Install-Jq {
	Install-WingetPackages jqlang.jq
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

function Install-Telegram {
	Install-WingetPackages Telegram.TelegramDesktop
}

function Install-WhatsApp {
	Install-WingetPackages 9NKSQGP7F2NH
}

function Install-Vagrant {
	Install-WingetPackages Hashicorp.Vagrant
}

function Enable-HyperV {
	Write-InfoMessage "Enabling Hyper-V..."
	# https://learn.microsoft.com/es-es/windows-server/virtualization/hyper-v/get-started/Install-Hyper-V?pivots=windows#enable-hyper-v-using-powershell
  try {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
    Write-SuccessMessage "Hyper-V has been enabled successfully."
  } catch {
    Write-ErrorMessage "Failed to enable Hyper-V. Please check your system settings."
  }
}

function Install-FlowLauncher {
  Install-WingetPackages Flow-Launcher.Flow-Launcher
}

function Main {
	Install-Python
	Install-WSL
	Install-Choco
	Install-Fonts
	Install-Espanso
	Install-Git
	Install-VsCode
	Install-Vlc
	Install-ObsStudio
	Install-PeekScreenRecorder
	Install-Lazygit
	Install-GitDelta
	Install-NeoVim
	Install-LazyVim
	Install-FdFind
	Install-Btop
	Install-Jq
	Install-Curl
	Install-Fzf
	Install-RipGrep
	Install-Bitwarden
	Install-Bat
	Install-Eza
	Install-Telegram
	Install-WhatsApp
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
