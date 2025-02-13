# NOTE: Run this script as Administrator

function Install-Choco {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-Fonts {
	choco install jetbrainsmono --confirm --no-progress
}

function Install-Espanso {
	choco install espanso --confirm --no-progress
}

function Main {
	Install-Choco
	Install-Fonts
	Install-Espanso
}

Main
