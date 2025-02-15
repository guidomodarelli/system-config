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
		Write-InfoMessage "Chocolatey is already installed."
	}
}

function Install-ChocoPackages {
	param (
		[string[]]$packages
	)
	foreach ($package in $packages) {
		if (choco list | Select-String -Pattern $package) {
			Write-InfoMessage "The package $package is already installed. Upgrading..."
			choco upgrade $package --confirm --no-progress
			Write-SuccessMessage "The package $package has been upgraded successfully."
		} else {
			Write-InfoMessage "Installing the package $package..."
			choco install $package --confirm --no-progress
			Write-SuccessMessage "The package $package has been installed successfully."
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

function Install-Espanso {
	Install-WingetPackages Espanso.Espanso

	Remove-Item -Recurse -Force C:\Users\Guido\AppData\Roaming\espanso\
	New-Item -ItemType SymbolicLink -Path C:\Users\Guido\AppData\Roaming\espanso\ -Target C:\Users\Guido\system-config\files\.config\espanso\

	espanso service register
	espanso start
}

function Install-LazyVim {
	if (Test-Path $env:LOCALAPPDATA\nvim) {
		# required
		Move-Item $env:LOCALAPPDATA\nvim $env:LOCALAPPDATA\nvim.bak
	}

	if (Test-Path $env:LOCALAPPDATA\nvim-data) {
		# optional but recommended
		Move-Item $env:LOCALAPPDATA\nvim-data $env:LOCALAPPDATA\nvim-data.bak
	}

	git clone https://github.com/LazyVim/starter $env:LOCALAPPDATA\nvim

	Remove-Item $env:LOCALAPPDATA\nvim\.git -Recurse -Force
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
	if (wsl --list --quiet) {
		Write-InfoMessage "WSL is already installed."
	} else {
		wsl --install
	}
}

function Main {
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
