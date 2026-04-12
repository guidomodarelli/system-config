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

  It 'remueve comentarios inline de YAML sin romper hashes dentro de comillas' {
    (Remove-YamlInlineComment -Line "target: value # comment") | Should Be 'target: value'
    (Remove-YamlInlineComment -Line "target: 'value # keep' # comment") | Should Be "target: 'value # keep'"
    (Remove-YamlInlineComment -Line 'target: "value # keep" # comment') | Should Be 'target: "value # keep"'
  }

  It 'divide key y value YAML ignorando dos puntos dentro de comillas' {
    $pair = Split-YamlKeyValue -Text 'target: "C:\Users\name:with-colon\file.txt"'

    $pair.HasValue | Should Be $true
    $pair.Key | Should Be 'target'
    $pair.Value | Should Be '"C:\Users\name:with-colon\file.txt"'
  }

  It 'convierte escalares YAML simples a sus tipos esperados' {
    (ConvertFrom-YamlScalar -Text 'true') | Should BeOfType [bool]
    (ConvertFrom-YamlScalar -Text 'true') | Should Be $true
    (ConvertFrom-YamlScalar -Text 'false') | Should Be $false
    (ConvertFrom-YamlScalar -Text 'null') | Should Be $null
    (ConvertFrom-YamlScalar -Text "'quoted value'") | Should Be 'quoted value'
    (ConvertFrom-YamlScalar -Text '"quoted \"value\""') | Should Be 'quoted "value"'
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

  It 'expande ~, $HOME y $USER en rutas de usuario' {
    $script:HomeDir = 'C:\Users\tester'
    $script:WindowsUser = 'windows-user'

    (Expand-UserPath -Path '~') | Should Be 'C:\Users\tester'
    (Expand-UserPath -Path '~\Documents') | Should Be 'C:\Users\tester\Documents'
    (Expand-UserPath -Path '$HOME\AppData\$USER\file.txt') | Should Be 'C:\Users\tester\AppData\windows-user\file.txt'
  }

  It 'resuelve targets base por defecto, absolutos y relativos' {
    $script:HomeDir = 'C:\Users\tester'

    (Resolve-TargetBase -Target $null) | Should Be 'C:\Users\tester'
    (Resolve-TargetBase -Target 'Documents\PowerShell') | Should Be 'C:\Users\tester\Documents\PowerShell'
    (Resolve-TargetBase -Target 'D:\dotfiles\target') | Should Be 'D:\dotfiles\target'
  }

  It 'ordena resultados wildcard y devuelve vacio para fuentes inexistentes' {
    $testRootDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
    $script:ConfigsDir = Join-Path -Path $testRootDirectory -ChildPath 'configs'
    New-Item -ItemType Directory -Path (Join-Path -Path $script:ConfigsDir -ChildPath 'wild') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $script:ConfigsDir -ChildPath 'wild\b-file.txt') -Value 'b'
    Set-Content -LiteralPath (Join-Path -Path $script:ConfigsDir -ChildPath 'wild\a-file.txt') -Value 'a'

    $resolvedSources = @(Get-ResolvedSources -OriginalPath 'wild\*')
    $missingSources = @(Get-ResolvedSources -OriginalPath 'missing*')

    $resolvedSources.Count | Should Be 2
    $resolvedSources[0].Name | Should Be 'a-file.txt'
    $resolvedSources[1].Name | Should Be 'b-file.txt'
    $missingSources.Count | Should Be 0

    Remove-Item -LiteralPath $testRootDirectory -Recurse -Force
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

  It 'omite targets con esquema invalido en Resolve-Operations' {
    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'example.conf'
          target = 'WSL://Desktop'
        }
      )
    }
    Mock Get-ResolvedSources { @([PSCustomObject]@{ Name = 'example.conf'; FullName = 'C:\repo\configs\example.conf' }) }

    $operations = Resolve-Operations

    $operations.Count | Should Be 0
    $script:CountErrors | Should Be 0
  }

  It 'registra diagnostico cuando falta una ruta de origen sin wildcard' {
    $script:HomeDir = 'C:\Users\tester'

    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'missing.conf'
          target = 'Documents'
        }
      )
    }
    Mock Get-ResolvedSources { @() } -ParameterFilter { $OriginalPath -eq 'missing.conf' }
    Mock Add-Diagnostic {
      param(
        [string]$Target,
        [string]$Reason
      )

      $script:Diagnostics.Add([PSCustomObject]@{
          Target = $Target
          Reason = $Reason
        })
    }

    $operations = Resolve-Operations

    $operations.Count | Should Be 0
    $script:CountErrors | Should Be 1
    $script:Diagnostics.Count | Should Be 1
    $script:Diagnostics[0].Reason | Should Match 'Ruta de origen inexistente'
  }

  It 'omite entradas excluidas por onlyFor cuando no matchean Windows' {
    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'linux-only.conf'
          onlyFor = @(
            [PSCustomObject]@{
              platform = 'linux'
            }
          )
        }
      )
    }

    $operations = Resolve-Operations

    $operations.Count | Should Be 0
    $script:CountErrors | Should Be 0
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

  It 'Parse-Args activa flags y captura argumentos internos elevados' {
    $script:DryRun = $false
    $script:UseColor = $true
    $script:UseIcons = $true
    $script:VerboseMode = $false
    $script:Quiet = $false
    $script:IsElevatedSymlinkMode = $false
    $script:ElevatedSymlinkSource = $null
    $script:ElevatedSymlinkTarget = $null

    Parse-Args -CliArgs @(
      '--dry-run',
      '--plain',
      '--verbose',
      '--quiet',
      '--internal-create-link',
      '--internal-source', 'C:\source',
      '--internal-target', 'C:\target'
    )

    $script:DryRun | Should Be $true
    $script:UseColor | Should Be $false
    $script:UseIcons | Should Be $false
    $script:VerboseMode | Should Be $true
    $script:Quiet | Should Be $true
    $script:IsElevatedSymlinkMode | Should Be $true
    $script:ElevatedSymlinkSource | Should Be 'C:\source'
    $script:ElevatedSymlinkTarget | Should Be 'C:\target'
  }

  It 'el modo interno elevado devuelve false cuando no fue solicitado' {
    (Invoke-InternalElevatedSymlinkMode) | Should Be $false
  }
}
