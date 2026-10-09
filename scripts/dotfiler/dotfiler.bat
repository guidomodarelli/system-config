@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"

where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
	set "PS_EXE=pwsh.exe"
)

rem Allow local scripts (e.g. the PowerShell profile) in normal sessions too.
rem Clear PSModulePath so powershell.exe does not load pwsh 7 modules inherited
rem from the calling session; each edition rebuilds its own default paths.
set "PSModulePath="
rem The -ExecutionPolicy Bypass process scope overrides CurrentUser, so ignore
rem only the ExecutionPolicyOverride error raised after the policy is saved.
set "EP_CMD=if ((Get-ExecutionPolicy -Scope CurrentUser) -notin 'RemoteSigned','Unrestricted','Bypass') { try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop } catch { if ($_.FullyQualifiedErrorId -notlike 'ExecutionPolicyOverride*') { throw } } }"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "%EP_CMD%"
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
	pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "%EP_CMD%"
)

%PS_EXE% -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%dotfiler.ps1" %*