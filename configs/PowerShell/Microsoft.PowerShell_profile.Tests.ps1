Describe 'Microsoft.PowerShell_profile ghq repository scan' {
  BeforeAll {
    Set-StrictMode -Version Latest

    # El profile completo depende de Windows y de binarios externos: se cargan solo las
    # funciones bajo prueba, en el scope del test para que compartan sus variables $script:.
    $profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
    $tokens = $null
    $parseErrors = $null
    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
      throw "Profile script has parse errors: $($parseErrors.Message -join '; ')"
    }

    $functionNamesUnderTest = @(
      'Test-CacheEntryIsFresh',
      'Get-GhqRepositoryScanExcludedDirectoryNames',
      'Test-IsReparsePointDirectory',
      'Test-IsBareGitRepositoryDirectory',
      'Test-IsGitRepositoryDirectory',
      'Get-ChildDirectoryInfos',
      'Get-GhqRootFingerprint',
      'Get-CachedGhqRepositoryList',
      'Get-CachedGhqRootPath',
      'Get-CachedGhqCommandInfo',
      'Resolve-CxCodexExecutable',
      'cx',
      'cxd'
    )
    foreach ($functionName in $functionNamesUnderTest) {
      $functionDefinition = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
      if (-not $functionDefinition) {
        throw "Function '$functionName' was not found in profile script."
      }
      . ([scriptblock]::Create($functionDefinition.Extent.Text))
    }

    $scriptVariableNamesUnderTest = @(
      '$script:CxCommitSkillPrompt',
      '$script:CxCommitModel',
      '$script:CxCommitReasoning'
    )
    foreach ($scriptVariableName in $scriptVariableNamesUnderTest) {
      $assignment = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
          $node.Left.Extent.Text -eq $scriptVariableName
        }, $true)
      if (-not $assignment) {
        throw "Assignment '$scriptVariableName' was not found in profile script."
      }
      . ([scriptblock]::Create($assignment.Extent.Text))
    }

    # Borde externo: el binario ghq. Existe como función para que Mock pueda reemplazarlo
    # aunque ghq no esté instalado donde corren los tests.
    function ghq { }
    function codex { }

    function New-TestGitRepository {
      param([string]$RepositoryPath)
      New-Item -Path (Join-Path $RepositoryPath '.git') -ItemType Directory -Force | Out-Null
    }

    function Reset-GhqRepositoryListCache {
      $script:GhqRepositoryListCache = $null
      $script:GhqRepositoryListCacheTimestamp = $null
      $script:GhqRepositoryListCacheRootFingerprint = $null
    }

    $script:OriginalGhqRoot = [Environment]::GetEnvironmentVariable('GHQ_ROOT')
    $script:OriginalGhqScanExcludes = [Environment]::GetEnvironmentVariable('GHQ_SCAN_EXCLUDES')
  }

  AfterAll {
    [Environment]::SetEnvironmentVariable('GHQ_ROOT', $script:OriginalGhqRoot)
    [Environment]::SetEnvironmentVariable('GHQ_SCAN_EXCLUDES', $script:OriginalGhqScanExcludes)
  }

  BeforeEach {
    $script:GhqSelectionCacheTtlSeconds = 300
    $script:GhqRootCache = $null
    $script:GhqRootCacheTimestamp = $null
    $script:GhqRepositoryScanDefaultExcludedDirectoryNames = @('.cache', '.npm', '.pnpm-store', '.yarn', '.terraform', 'node_modules')
    $script:GhqRepositoryScanExcludedDirectoryNames = @()
    Reset-GhqRepositoryListCache
    [Environment]::SetEnvironmentVariable('GHQ_SCAN_EXCLUDES', $null)

    Mock Get-CachedGhqCommandInfo { [pscustomobject]@{ Source = 'ghq' } }
    Mock ghq { @() }
  }

  Context 'exclusiones del escaneo' {
    It 'combina las exclusiones por defecto con GHQ_SCAN_EXCLUDES' {
      [Environment]::SetEnvironmentVariable('GHQ_SCAN_EXCLUDES', 'tmp-cache,custom_large_dir')

      $mergedExclusions = @(Get-GhqRepositoryScanExcludedDirectoryNames)

      $mergedExclusions | Should -Contain 'node_modules'
      $mergedExclusions | Should -Contain 'custom_large_dir'
    }

    It 'detecta directorios reparse point' {
      $simulatedReparseDirectory = [pscustomobject]@{
        Attributes = [System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::ReparsePoint
      }

      Test-IsReparsePointDirectory -DirectoryInfo $simulatedReparseDirectory | Should -BeTrue
    }
  }

  Context 'escaneo del root de ghq' {
    BeforeEach {
      $script:TestRootPath = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
      New-TestGitRepository -RepositoryPath (Join-Path $script:TestRootPath 'github.com/acme/alpha')

      $worktreeRepositoryPath = Join-Path $script:TestRootPath 'github.com/acme/beta-worktree'
      New-Item -Path $worktreeRepositoryPath -ItemType Directory -Force | Out-Null
      Set-Content -Path (Join-Path $worktreeRepositoryPath '.git') -Value 'gitdir: C:\tmp\linked-worktree' -NoNewline

      $bareRepositoryPath = Join-Path $script:TestRootPath 'github.com/acme/gamma-bare'
      New-Item -Path (Join-Path $bareRepositoryPath 'objects') -ItemType Directory -Force | Out-Null
      New-Item -Path (Join-Path $bareRepositoryPath 'refs') -ItemType Directory -Force | Out-Null
      Set-Content -Path (Join-Path $bareRepositoryPath 'HEAD') -Value 'ref: refs/heads/main' -NoNewline

      New-TestGitRepository -RepositoryPath (Join-Path $script:TestRootPath 'node_modules/ignored/repo')
      New-TestGitRepository -RepositoryPath (Join-Path $script:TestRootPath 'GitHub.com/Acme/ALPHA')

      $script:FakeGhqRootPath = $script:TestRootPath
      Mock Get-CachedGhqRootPath { $script:FakeGhqRootPath }
    }

    It 'detecta repos con .git directorio, .git archivo (worktree) y bare' {
      $detectedRepositories = @(Get-CachedGhqRepositoryList)

      $detectedRepositories | Should -Contain 'github.com/acme/alpha'
      $detectedRepositories | Should -Contain 'github.com/acme/beta-worktree'
      $detectedRepositories | Should -Contain 'github.com/acme/gamma-bare'
    }

    It 'omite directorios excluidos y deduplica rutas sin distinguir mayúsculas' {
      $detectedRepositories = @(Get-CachedGhqRepositoryList)

      $detectedRepositories | Should -Not -Contain 'node_modules/ignored/repo'
      $detectedRepositories | Should -HaveCount 3
    }

    It 'devuelve la cache caliente sin volver a escanear' {
      $null = Get-CachedGhqRepositoryList
      Remove-Item -LiteralPath (Join-Path $script:TestRootPath 'github.com/acme/gamma-bare/HEAD')

      @(Get-CachedGhqRepositoryList) | Should -HaveCount 3
    }

    It 'invalida la cache cuando cambia la metadata del root' {
      $null = Get-CachedGhqRepositoryList
      Start-Sleep -Milliseconds 1200
      New-TestGitRepository -RepositoryPath (Join-Path $script:TestRootPath 'github.com/new-owner/delta-new')

      $repositoriesAfterChange = @(Get-CachedGhqRepositoryList)

      $repositoriesAfterChange | Should -Contain 'github.com/new-owner/delta-new'
      $repositoriesAfterChange | Should -HaveCount 4
    }

    It 'construye rutas relativas aunque el root termine en separador' {
      $script:FakeGhqRootPath = $script:TestRootPath + [System.IO.Path]::DirectorySeparatorChar

      $detectedRepositories = @(Get-CachedGhqRepositoryList)

      $detectedRepositories | Should -Contain 'github.com/acme/alpha'
      $detectedRepositories | Should -HaveCount 3
    }

    It 'usa ghq list como fallback cuando el root no existe' {
      $script:FakeGhqRootPath = Join-Path $script:TestRootPath 'missing-root'
      Mock ghq { @('github.com/acme/from-ghq-list') } -ParameterFilter { $args[0] -eq 'list' }

      $fallbackRepositories = @(Get-CachedGhqRepositoryList)

      $fallbackRepositories | Should -Be @('github.com/acme/from-ghq-list')
      Should -Invoke ghq -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'list' }
    }
  }

  Context 'resolución del root de ghq' {
    It 'usa la primera entrada absoluta de GHQ_ROOT sin ejecutar ghq' {
      $primaryRootPath = Join-Path $TestDrive 'primary-root'
      $secondaryRootPath = Join-Path $TestDrive 'secondary-root'
      [Environment]::SetEnvironmentVariable('GHQ_ROOT', $primaryRootPath + [System.IO.Path]::PathSeparator + $secondaryRootPath)

      Get-CachedGhqRootPath | Should -Be $primaryRootPath
      Should -Invoke ghq -Times 0 -Exactly
    }

    It 'delega en ghq root cuando GHQ_ROOT es relativo' {
      [Environment]::SetEnvironmentVariable('GHQ_ROOT', 'relative-root')
      $resolvedRootPath = Join-Path $TestDrive 'resolved-by-ghq'
      Mock ghq { $resolvedRootPath } -ParameterFilter { $args[0] -eq 'root' }

      Get-CachedGhqRootPath | Should -Be $resolvedRootPath
      Should -Invoke ghq -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'root' }
    }
  }

  Context 'modelo predeterminado del wrapper Codex' {
    BeforeEach {
      Mock Resolve-CxCodexExecutable { 'codex' }
      Mock codex { }
    }

    It 'usa gpt-6-luna con esfuerzo max en cx' {
      cx

      Should -Invoke codex -Times 1 -Exactly -ParameterFilter {
        $args[0] -eq '-m' -and
        $args[1] -eq 'gpt-6-luna' -and
        $args[2] -eq '-c' -and
        $args[3] -eq 'model_reasoning_effort=max'
      }
    }

    It 'usa mismo modelo y esfuerzo en cxd' {
      cxd

      Should -Invoke codex -Times 1 -Exactly -ParameterFilter {
        $args[0] -eq '-m' -and
        $args[1] -eq 'gpt-6-luna' -and
        $args[2] -eq '-c' -and
        $args[3] -eq 'model_reasoning_effort=max'
      }
    }

    It 'usa gpt-6-luna y max en modo commit' {
      cx --commit

      Should -Invoke codex -Times 1 -Exactly -ParameterFilter {
        $args[0] -eq '-m' -and
        $args[1] -eq 'gpt-6-luna' -and
        $args[2] -eq '-c' -and
        $args[3] -eq 'model_reasoning_effort=max'
      }
    }
  }
}
