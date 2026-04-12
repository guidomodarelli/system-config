@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"

where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
	set "PS_EXE=pwsh.exe"
)

%PS_EXE% -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%dotfiler.ps1" %*
