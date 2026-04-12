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
    $script:ConfigPathsFile = ''
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

    $overrideTarget = Get-OverrideTarget -Entry $entry

    $overrideTarget.UsesExactTarget | Should Be $false
    $overrideTarget.ConfiguredTarget | Should Be 'AppData/Roaming'
  }

  It 'genera operaciones con exactTarget como ruta final del symlink' {
    $testRootDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
    $script:HomeDir = Join-Path -Path $testRootDirectory -ChildPath 'home'
    $script:ConfigsDir = Join-Path -Path $testRootDirectory -ChildPath 'configs'

    New-Item -ItemType Directory -Path $script:HomeDir -Force | Out-Null
    $sourceDirectory = Join-Path -Path $script:ConfigsDir -ChildPath '.codex/skills/.system'
    New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null

    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = '.codex/skills/.system'
          exactTarget = '.agents/.codex/skills/.system'
        }
      )
    }

    $operations = Resolve-Operations

    $operations.Count | Should Be 1
    $operations[0].Source | Should Be $sourceDirectory
    $operations[0].Target | Should Be (Join-Path -Path $script:HomeDir -ChildPath '.agents/.codex/skills/.system')
    $operations[0].Group | Should Be (Join-Path -Path $script:HomeDir -ChildPath '.agents/.codex/skills')

    Remove-Item -LiteralPath $testRootDirectory -Recurse -Force
  }

  It 'rechaza exactTarget con wildcard y registra diagnostico' {
    $testRootDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
    $script:HomeDir = Join-Path -Path $testRootDirectory -ChildPath 'home'
    $script:ConfigsDir = Join-Path -Path $testRootDirectory -ChildPath 'configs'

    New-Item -ItemType Directory -Path $script:HomeDir -Force | Out-Null
    $wildcardDirectory = Join-Path -Path $script:ConfigsDir -ChildPath 'wildcard'
    New-Item -ItemType Directory -Path $wildcardDirectory -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path -Path $wildcardDirectory -ChildPath 'example.conf') -Force | Out-Null

    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'wildcard/*.conf'
          exactTarget = 'single-target.conf'
        }
      )
    }

    $operations = Resolve-Operations

    $operations.Count | Should Be 0
    $script:CountErrors | Should Be 1
    if ($script:Diagnostics.Count -gt 0) {
      $script:Diagnostics[0].Reason | Should Match 'exactTarget no admite patrones wildcard'
    }

    Remove-Item -LiteralPath $testRootDirectory -Recurse -Force
  }

  It 'rechaza entradas que definen target y exactTarget al mismo tiempo' {
    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'example.conf'
          target = 'Documents'
          exactTarget = 'Documents/example.conf'
        }
      )
    }

    $operations = Resolve-Operations

    $operations.Count | Should Be 0
    $script:CountErrors | Should Be 1
    if ($script:Diagnostics.Count -gt 0) {
      $script:Diagnostics[0].Reason | Should Match 'target y exactTarget al mismo tiempo'
    }
  }

  It 'rechaza overrides que definen target y exactTarget al mismo tiempo' {
    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'example.conf'
          overrides = @(
            [PSCustomObject]@{
              windows = $true
              target = 'Documents'
              exactTarget = 'Documents/example.conf'
            }
          )
        }
      )
    }

    $operations = Resolve-Operations

    $operations.Count | Should Be 0
    $script:CountErrors | Should Be 1
    if ($script:Diagnostics.Count -gt 0) {
      $script:Diagnostics[0].Reason | Should Match 'override no puede definir target y exactTarget'
    }
  }
}
