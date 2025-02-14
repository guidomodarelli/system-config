# NOTE: Run this script as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

function Install-Choco {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-ChocoPackage {
	param (
		[string]$package
	)
	choco install $package --confirm --no-progress
}

function Install-Fonts {
	Install-ChocoPackage nerd-fonts-jetbrainsmono
	Install-ChocoPackage nerd-fonts-iosevkaterm
	Install-ChocoPackage nerd-fonts-cascadiamono
	Install-ChocoPackage nerd-fonts-dejavusansmono
	Install-ChocoPackage nerd-fonts-victormono
}

function Install-Espanso {
	Install-ChocoPackage espanso

	Remove-Item -Recurse -Force C:\Users\Guido\AppData\Roaming\espanso\
	New-Item -ItemType SymbolicLink -Path C:\Users\Guido\AppData\Roaming\espanso\ -Target C:\Users\Guido\system-config\files\.config\espanso\
	espanso restart
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
