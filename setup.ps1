# NOTE: Run this script as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

function Install-Choco {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-ChocoPackages {
	param (
		[string[]]$packages
	)
	foreach ($package in $packages) {
		choco install $package --confirm --no-progress
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
	if (-Not (Get-Command espanso -ErrorAction SilentlyContinue)) {
		Install-ChocoPackages -packages @('espanso')
	}

	Remove-Item -Recurse -Force C:\Users\Guido\AppData\Roaming\espanso\
	New-Item -ItemType SymbolicLink -Path C:\Users\Guido\AppData\Roaming\espanso\ -Target C:\Users\Guido\system-config\files\.config\espanso\

	espanso service register
}

function Main {
	Install-Choco
	Install-Fonts
	Install-Espanso
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
