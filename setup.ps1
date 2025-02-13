# NOTE: Run this script as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

function Install-Choco {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-Fonts {
	choco install jetbrainsmono --confirm --no-progress
}

function Install-Espanso {
	choco install espanso --confirm --no-progress

	Remove-Item -Recurse -Force C:\Users\Guido\AppData\Roaming\espanso\
	New-Item -ItemType SymbolicLink -Path C:\Users\Guido\AppData\Roaming\espanso\ -Target C:\Users\Guido\system-config\files\.config\espanso\
}

function Main {
	Install-Choco
	Install-Fonts
	Install-Espanso
}

Main
