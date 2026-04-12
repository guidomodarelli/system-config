$previousSkipMain = $env:DOTFILER_PS1_SKIP_MAIN
$env:DOTFILER_PS1_SKIP_MAIN = '1'
. (Join-Path -Path $PSScriptRoot -ChildPath 'dotfiler.ps1')

if ($null -eq $previousSkipMain) {
  Remove-Item Env:DOTFILER_PS1_SKIP_MAIN -ErrorAction SilentlyContinue
} else {
  $env:DOTFILER_PS1_SKIP_MAIN = $previousSkipMain
}

Describe 'dotfiler.ps1' {
  BeforeEach {
    $script:DryRun = $false
    $script:Quiet = $false
    $script:VerboseMode = $false
    $script:IsElevatedSymlinkMode = $false
    $script:CountCreated = 0
    $script:CountReplaced = 0
    $script:CountBackups = 0
    $script:CountSimulated = 0
    $script:CountErrors = 0
    $script:CountPlannedCreated = 0
    $script:CountPlannedReplaced = 0
    $script:CountPlannedBackups = 0
    $script:Diagnostics = [System.Collections.Generic.List[object]]::new()
  }

  It 'detecta errores de permisos insuficientes para symlinks' {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.UnauthorizedAccessException]::new('The required privilege is not held by the client'),
      'PrivilegeError',
      [System.Management.Automation.ErrorCategory]::PermissionDenied,
      $null
    )

    (Test-IsPrivilegeElevationError -ErrorRecord $errorRecord) | Should Be $true
  }

  It 'reintenta con elevacion cuando falla New-Item por permisos' {
    $script:elevatedInvocation = $null

    Mock Test-IsSymlink { $false }
    Mock Test-PathEntry { $false }
    Mock Test-Path { $true }
    Mock Write-Info {}
    Mock Write-Success {}
    Mock Add-Diagnostic {}
    Mock Invoke-ElevatedSymlinkCreation {
      param([string]$SourcePath, [string]$TargetPath)
      $script:elevatedInvocation = [PSCustomObject]@{
        Source = $SourcePath
        Target = $TargetPath
      }
    }
    Mock New-Item {
      throw [System.UnauthorizedAccessException]::new('The required privilege is not held by the client')
    } -ParameterFilter { $ItemType -eq 'SymbolicLink' }

    New-DotfileSymlink -SourcePath 'C:\fuente' -TargetPath 'C:\destino'

    $script:elevatedInvocation.Source | Should Be 'C:\fuente'
    $script:elevatedInvocation.Target | Should Be 'C:\destino'
    $script:CountErrors | Should Be 0
  }

  It 'cita argumentos con espacios antes de relanzar el proceso elevado' {
    $processArguments = Get-ElevatedSymlinkProcessArguments `
      -ScriptPath 'C:\Users\guido\Source Repos\system-config\scripts\dotfiler\dotfiler.ps1' `
      -SourcePath 'C:\Users\guido\Source Repos\config file.ps1' `
      -TargetPath 'C:\Users\guido\AppData\Roaming\My Folder\profile.ps1'

    $processArguments | Should Be @(
      '-NoLogo',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      '"C:\Users\guido\Source Repos\system-config\scripts\dotfiler\dotfiler.ps1"',
      '--internal-create-link',
      '--internal-source',
      '"C:\Users\guido\Source Repos\config file.ps1"',
      '--internal-target',
      '"C:\Users\guido\AppData\Roaming\My Folder\profile.ps1"'
    )
  }

  It 'no clasifica errores genericos como problemas de elevacion' {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new('Generic failure'),
      'GenericError',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $null
    )

    (Test-IsPrivilegeElevationError -ErrorRecord $errorRecord) | Should Be $false
  }

  It 'incluye entradas Windows con onlyFor win32 legacy' {
    $entry = [PSCustomObject]@{
      path = 'PowerShell/Microsoft.PowerShell_profile.ps1'
      onlyFor = @(
        [PSCustomObject]@{
          win32 = $true
        }
      )
    }

    (Test-EntryIncluded -Entry $entry) | Should Be $true
  }

  It 'resuelve overrides Windows con alias documentados' {
    $entry = [PSCustomObject]@{
      target = 'Documents'
      overrides = @(
        [PSCustomObject]@{
          windows = $true
          target = 'AppData/Roaming'
        }
      )
    }

    (Get-OverrideTarget -Entry $entry) | Should Be 'AppData/Roaming'
  }
}
