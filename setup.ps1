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

function Install-Choco {
	if (-Not (Test-Path 'C:\ProgramData\chocolatey\bin\choco.exe')) {
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
		iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
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
		} else {
			Write-InfoMessage "Installing the package $package..."
			choco install $package --confirm --no-progress
		}
	}
}

function Install-WingetPackages {
	param (
		[string[]]$appIds
	)
	foreach ($appId in $appIds) {
		$appName = (winget show $appId | Select-String -Pattern 'Name' | ForEach-Object { $_.Line.Split(':')[1].Trim() })
		if (winget show $appId) {
			Write-InfoMessage "The package $appName is already installed. Upgrading..."
			winget upgrade -e --id $appId
		} else {
			Write-InfoMessage "Installing the package $appName..."
			winget install -e --id $appId
		}
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
	winget install -e --id Git.Git
}

function Install-VsCode {
	winget install -e --id Microsoft.VisualStudioCode
}

function Install-Vlc {
	winget install -e --id VideoLAN.VLC
}

function Install-ObsStudio {
	winget install -e --id OBSProject.OBSStudio
}

function Install-PeekScreenRecorder {
	winget install -e --id XP8CD3D3Q50MS2
}

function Install-Lazygit {
	winget install -e --id JesseDuffield.lazygit
}

function Install-GitDelta {
	winget install -e --id dandavison.delta
}

function Install-NeoVim {
	winget install -e --id Neovim.Neovim
}

function Install-FdFind {
	winget install -e --id sharkdp.fd
}

function Install-Btop {
	winget install -e --id aristocratos.btop4win
}

function Install-Jq {
	winget install -e --id jqlang.jq
}

function Install-Curl {
	winget install -e --id cURL.cURL
}

function Install-Fzf {
	winget install -e --id junegunn.fzf
}

function Install-RipGrep {
	winget install -e --id BurntSushi.ripgrep.GNU
}

function Install-Bitwarden {
	winget install -e --id Bitwarden.Bitwarden
}

function Install-Bat {
	winget install -e --id sharkdp.bat
}

function Install-Eza {
	# https://eza.rocks/
	winget install -e --id eza-community.eza
}

function Install-WSL {
	wsl --install
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
	Write-ErrorMessage "Por favor, ejecute este script como Administrador."
	exit
}

if ($args.Count -gt 0) {
	$functionName = $args[0]
	if (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue) {
		Write-Host "Invoking function: $functionName"
		Invoke-Expression $functionName
	} else {
		Write-Host "Function "$functionName" does not exist."
	}
} else {
	Write-Host "No arguments were passed. Running default functions."
	Main
}
