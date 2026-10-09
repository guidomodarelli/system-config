@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"

where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
	set "PS_EXE=pwsh.exe"
)

rem Allow local scripts (e.g. the PowerShell profile) in normal sessions too.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force"
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
	pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force"
)

%PS_EXE% -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%dotfiler.ps1" %*