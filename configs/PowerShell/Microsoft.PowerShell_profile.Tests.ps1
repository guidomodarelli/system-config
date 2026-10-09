Describe 'Microsoft.PowerShell_profile cache de scripts por ejecutable' {
  BeforeAll {
    Set-StrictMode -Version Latest

    $profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
    $tokens = $null
    $parseErrors = $null
    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
      throw "El perfil tiene errores de sintaxis: $($parseErrors.Message -join '; ')"
    }

    foreach ($functionName in @('Get-ExecutableTargetInfo', 'Get-StableExecutablePath', 'Get-ExecutableFingerprint', 'Get-ExecutableInitCachePath', 'Get-CachedInitScriptPath')) {
      $functionDefinition = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
      . ([scriptblock]::Create($functionDefinition.Extent.Text))
    }

    # El CLI de prueba genera un init ejecutable. Los archivos y enlaces son reales;
    # no se reemplazan las APIs de PowerShell ni del sistema de archivos.
    function New-TestInitGenerator {
      param([string]$DirectoryPath, [string]$InitResult)

      New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null
      $executablePath = Join-Path $DirectoryPath 'codex.ps1'
      Set-Content -LiteralPath $executablePath -Value ('"''{0}''"' -f $InitResult)
      return Get-Command -Name $executablePath
    }
  }

  BeforeEach {
    $script:FirstGenerationCount = 0
    $script:SecondGenerationCount = 0
    $script:InitCacheBasePath = Join-Path $TestDrive ('cache-' + [guid]::NewGuid().ToString('N') + '/completion.ps1')
    $script:FirstExecutable = New-TestInitGenerator -DirectoryPath (Join-Path $TestDrive ('node-first-' + [guid]::NewGuid().ToString('N'))) -InitResult 'primer init'
    $script:SecondExecutable = New-TestInitGenerator -DirectoryPath (Join-Path $TestDrive ('node-second-' + [guid]::NewGuid().ToString('N'))) -InitResult 'segundo init'
  }

  It 'debe generar el init una sola vez cuando se reutiliza la misma instalación' {
    $cachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:FirstExecutable
    $fingerprint = Get-ExecutableFingerprint -CommandInfo $script:FirstExecutable
    $generator = {
      $script:FirstGenerationCount++
      & $script:FirstExecutable.Source
    }

    $firstCachePath = Get-CachedInitScriptPath -CachePath $cachePath -Fingerprint $fingerprint -GenerateScriptText $generator
    $secondCachePath = Get-CachedInitScriptPath -CachePath $cachePath -Fingerprint $fingerprint -GenerateScriptText $generator

    (. $firstCachePath) | Should -Be 'primer init'
    (. $secondCachePath) | Should -Be 'primer init'
    $script:FirstGenerationCount | Should -Be 1
  }

  It 'debe conservar ambos init cuando las sesiones alternan instalaciones' {
    $firstCachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:FirstExecutable
    $secondCachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:SecondExecutable
    $firstFingerprint = Get-ExecutableFingerprint -CommandInfo $script:FirstExecutable
    $secondFingerprint = Get-ExecutableFingerprint -CommandInfo $script:SecondExecutable
    $firstGenerator = { $script:FirstGenerationCount++; & $script:FirstExecutable.Source }
    $secondGenerator = { $script:SecondGenerationCount++; & $script:SecondExecutable.Source }

    foreach ($iteration in 1..2) {
      $firstInit = Get-CachedInitScriptPath -CachePath $firstCachePath -Fingerprint $firstFingerprint -GenerateScriptText $firstGenerator
      $secondInit = Get-CachedInitScriptPath -CachePath $secondCachePath -Fingerprint $secondFingerprint -GenerateScriptText $secondGenerator
      (. $firstInit) | Should -Be 'primer init'
      (. $secondInit) | Should -Be 'segundo init'
    }

    $script:FirstGenerationCount | Should -Be 1
    $script:SecondGenerationCount | Should -Be 1
  }

  It 'debe reutilizar el init cuando distintos enlaces apuntan a la misma instalación' {
    $installationPath = Split-Path -Parent $script:FirstExecutable.Source
    $firstLinkPath = Join-Path $TestDrive 'session-first'
    $secondLinkPath = Join-Path $TestDrive 'session-second'
    $linkType = if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $firstLinkPath -Target $installationPath | Out-Null
    New-Item -ItemType $linkType -Path $secondLinkPath -Target $installationPath | Out-Null
    $firstLinkedExecutable = Get-Command -Name (Join-Path $firstLinkPath 'codex.ps1')
    $secondLinkedExecutable = Get-Command -Name (Join-Path $secondLinkPath 'codex.ps1')
    $firstCachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $firstLinkedExecutable
    $secondCachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $secondLinkedExecutable
    $generator = { $script:FirstGenerationCount++; & $script:FirstExecutable.Source }

    $firstInit = Get-CachedInitScriptPath -CachePath $firstCachePath -Fingerprint (Get-ExecutableFingerprint -CommandInfo $firstLinkedExecutable) -GenerateScriptText $generator
    $secondInit = Get-CachedInitScriptPath -CachePath $secondCachePath -Fingerprint (Get-ExecutableFingerprint -CommandInfo $secondLinkedExecutable) -GenerateScriptText $generator

    (. $firstInit) | Should -Be 'primer init'
    (. $secondInit) | Should -Be 'primer init'
    $script:FirstGenerationCount | Should -Be 1
  }

  It 'debe regenerar solo el init actualizado cuando cambia el ejecutable' {
    $firstCachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:FirstExecutable
    $secondCachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:SecondExecutable
    $firstGenerator = { $script:FirstGenerationCount++; & $script:FirstExecutable.Source }
    $secondGenerator = { $script:SecondGenerationCount++; & $script:SecondExecutable.Source }
    $null = Get-CachedInitScriptPath -CachePath $firstCachePath -Fingerprint (Get-ExecutableFingerprint -CommandInfo $script:FirstExecutable) -GenerateScriptText $firstGenerator
    $null = Get-CachedInitScriptPath -CachePath $secondCachePath -Fingerprint (Get-ExecutableFingerprint -CommandInfo $script:SecondExecutable) -GenerateScriptText $secondGenerator
    $originalWriteTime = [System.IO.File]::GetLastWriteTimeUtc($script:FirstExecutable.Source)
    Set-Content -LiteralPath $script:FirstExecutable.Source -Value '"''init actualizado''"'
    [System.IO.File]::SetLastWriteTimeUtc($script:FirstExecutable.Source, $originalWriteTime.AddSeconds(1))

    $firstInit = Get-CachedInitScriptPath -CachePath $firstCachePath -Fingerprint (Get-ExecutableFingerprint -CommandInfo $script:FirstExecutable) -GenerateScriptText $firstGenerator
    $secondInit = Get-CachedInitScriptPath -CachePath $secondCachePath -Fingerprint (Get-ExecutableFingerprint -CommandInfo $script:SecondExecutable) -GenerateScriptText $secondGenerator

    (. $firstInit) | Should -Be 'init actualizado'
    (. $secondInit) | Should -Be 'segundo init'
    $script:FirstGenerationCount | Should -Be 2
    $script:SecondGenerationCount | Should -Be 1
  }

  It 'debe conservar el init anterior cuando el generador falla' {
    $cachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:FirstExecutable
    $fingerprint = Get-ExecutableFingerprint -CommandInfo $script:FirstExecutable
    $initPath = Get-CachedInitScriptPath -CachePath $cachePath -Fingerprint $fingerprint -GenerateScriptText { & $script:FirstExecutable.Source }

    { Get-CachedInitScriptPath -CachePath $cachePath -Fingerprint ($fingerprint + '-updated') -GenerateScriptText { throw 'No se pudo generar el init de prueba.' } } | Should -Throw 'No se pudo generar el init de prueba.'

    (. $initPath) | Should -Be 'primer init'
  }

  It 'debe rechazar un init vacío sin reemplazar el cache anterior' {
    $cachePath = Get-ExecutableInitCachePath -CachePath $script:InitCacheBasePath -CommandInfo $script:FirstExecutable
    $fingerprint = Get-ExecutableFingerprint -CommandInfo $script:FirstExecutable
    $initPath = Get-CachedInitScriptPath -CachePath $cachePath -Fingerprint $fingerprint -GenerateScriptText { & $script:FirstExecutable.Source }

    { Get-CachedInitScriptPath -CachePath $cachePath -Fingerprint ($fingerprint + '-updated') -GenerateScriptText { '' } } | Should -Throw '*returned no output*'

    (. $initPath) | Should -Be 'primer init'
  }
}

Describe 'Microsoft.PowerShell_profile inicialización al usar comandos' {
  BeforeAll {
    Set-StrictMode -Version Latest
    $profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
    $tokens = $null
    $parseErrors = $null
    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$parseErrors)
    foreach ($functionName in @(
        'Get-ExecutableTargetInfo', 'Get-StableExecutablePath', 'Get-ExecutableFingerprint',
        'Get-ExecutableInitCachePath', 'Get-CachedInitScriptPath', 'Initialize-Zoxide',
        'Invoke-LazyZoxideJump', 'Invoke-LazyZoxideInteractiveJump', 'Initialize-FnmEnvironment',
        'Add-FnmDefaultNodeDirectoryToPath', 'Get-FnmDataDirectory',
        'Set-LocationWithFnm', 'fnm', 'Initialize-CodexCompletion', 'Register-LazyCodexCompletion'
      )) {
      $definition = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
          ($node.Name -split ':')[-1] -eq $functionName
        }, $true)
      . ([scriptblock]::Create($definition.Extent.Text))
    }
    $script:OriginalPath = $env:PATH
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $script:OriginalLocation = (Get-Location).Path
    $script:OriginalPrompt = $function:prompt
    $setupPath = Join-Path $PSScriptRoot '../../scripts/setup/setup.ps1'
    $setupAst = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$parseErrors)
    $fnmResolverDefinition = $setupAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Resolve-FnmExecutable'
      }, $true)
    . ([scriptblock]::Create($fnmResolverDefinition.Extent.Text))
  }

  AfterAll {
    $env:PATH = $script:OriginalPath
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    Set-Location -LiteralPath $script:OriginalLocation
    Set-Item -LiteralPath Function:\global:prompt -Value $script:OriginalPrompt
    foreach ($functionName in @('Set-LocationWithFnm', 'Set-FnmOnLoad', '__zoxide_z', '__zoxide_zi')) {
      Remove-Item -LiteralPath ('Function:\global:' + $functionName) -ErrorAction SilentlyContinue
    }
    foreach ($aliasName in @('z', 'zi')) {
      Remove-Item -LiteralPath ('Alias:\' + $aliasName) -Force -ErrorAction SilentlyContinue
    }
  }

  BeforeEach {
    $script:FixtureDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:FixtureDirectory | Out-Null
    $env:LOCALAPPDATA = $script:FixtureDirectory
    $env:PATH = $script:FixtureDirectory + [IO.Path]::PathSeparator + $script:OriginalPath
    $script:CodexCompletionInitialized = $false
    $script:CodexCompletionAttempted = $false
    $script:ZoxideInitialized = $false
    $script:FnmInitialized = $false
    $script:FnmInitializationAttempted = $false
    $script:FnmCommandInfo = $null
    $global:FixtureZoxideArguments = @()
    $global:FixtureZoxideVisitedDirectories = @()
    $global:FixtureFnmUses = 0

    # Cada CLI escribe un registro observable de generación y devuelve su init.
    # PowerShell registra y ejecuta los completers y aliases reales.
    $script:GenerationLogPath = Join-Path $script:FixtureDirectory 'generation.log'
    $script:CodexExecutablePath = Join-Path $script:FixtureDirectory 'codex.ps1'
    # El here-string del CLI se construye sin anidar delimitadores del test.
    $codexFixtureLines = @(
      "[IO.File]::AppendAllText('$script:GenerationLogPath', 'codex' + [Environment]::NewLine)",
      "@'",
      "Register-ArgumentCompleter -Native -CommandName 'codex' -ScriptBlock {",
      '  param($wordToComplete, $commandAst, $cursorPosition)',
      '  if (''--help'' -like "$wordToComplete*") {',
      "    [System.Management.Automation.CompletionResult]::new('--help', '--help', [System.Management.Automation.CompletionResultType]::ParameterName, 'Ayuda')",
      '  }',
      '}',
      "'@"
    )
    Set-Content -LiteralPath $script:CodexExecutablePath -Value $codexFixtureLines
    Register-LazyCodexCompletion

    $fnmFixtureLines = @(
      'if ($args[0] -eq ''env'') {',
      "  [IO.File]::AppendAllText('$script:GenerationLogPath', 'fnm' + [Environment]::NewLine)",
      "  @'",
      'function global:Set-FnmOnLoad { $global:FixtureFnmUses++; $null = fnm use --silent-if-unchanged }',
      'function global:Set-LocationWithFnm { param($path); if ($null -eq $path) { Set-Location } else { Set-Location $path }; Set-FnmOnLoad }',
      "'@",
      '} else { $args -join ''|'' }'
    )
    $fnmExecutablePath = Join-Path $script:FixtureDirectory 'fnm.ps1'
    Set-Content -LiteralPath $fnmExecutablePath -Value $fnmFixtureLines
    $script:FnmCommandInfo = Get-Command -Name $fnmExecutablePath

    # El stub se restaura porque el init oficial reemplaza la función global.
    $fnmLocationDefinition = $profileAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        ($node.Name -split ':')[-1] -eq 'Set-LocationWithFnm'
      }, $true)
    . ([scriptblock]::Create($fnmLocationDefinition.Extent.Text))

    $zoxideFixtureLines = @(
      "[IO.File]::AppendAllText('$script:GenerationLogPath', 'zoxide' + [Environment]::NewLine)",
      'if ($args -notcontains ''--hook'' -or $args[-1] -ne ''none'') { ''function global:prompt { $global:FixtureZoxideVisitedDirectories += (Get-Location).Path; "prompt zoxide" }'' }',
      "@'",
      'function global:__zoxide_z { $global:FixtureZoxideArguments = @(''z'') + $args; ''salto z'' }',
      'function global:__zoxide_zi { $global:FixtureZoxideArguments = @(''zi'') + $args; ''salto zi'' }',
      'Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force',
      'Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force',
      "'@"
    )
    $zoxideExecutablePath = Join-Path $script:FixtureDirectory 'zoxide.ps1'
    Set-Content -LiteralPath $zoxideExecutablePath -Value $zoxideFixtureLines
    $script:ZoxideCommandInfo = Get-Command -Name $zoxideExecutablePath
    Set-Alias -Name z -Value Invoke-LazyZoxideJump -Option AllScope -Scope Global -Force
    Set-Alias -Name zi -Value Invoke-LazyZoxideInteractiveJump -Option AllScope -Scope Global -Force
  }

  It 'debe generar el completion al primer Tab y reutilizarlo después' {
    $script:CodexCompletionInitialized | Should -BeFalse
    Test-Path -LiteralPath $script:GenerationLogPath | Should -BeFalse

    $completionInput = 'codex --hel'
    $firstMatches = [System.Management.Automation.CommandCompletion]::CompleteInput($completionInput, $completionInput.Length, $null).CompletionMatches
    $secondMatches = [System.Management.Automation.CommandCompletion]::CompleteInput($completionInput, $completionInput.Length, $null).CompletionMatches

    $firstMatches.CompletionText | Should -Contain '--help'
    $secondMatches.CompletionText | Should -Contain '--help'
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('codex')
    $script:CodexCompletionInitialized | Should -BeTrue
  }

  It 'debe conservar el cursor cuando se completa después de otro comando o un espacio' -ForEach @(
    @{ CompletionInput = 'Write-Output ok; codex --hel' },
    @{ CompletionInput = 'codex ' }
  ) {
    $completionMatches = [System.Management.Automation.CommandCompletion]::CompleteInput($CompletionInput, $CompletionInput.Length, $null).CompletionMatches

    $completionMatches.CompletionText | Should -Contain '--help'
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('codex')
  }

  It 'debe evitar reintentos automáticos y permitir registrar nuevamente el completion' {
    Set-Content -LiteralPath $script:CodexExecutablePath -Value @(
      "[IO.File]::AppendAllText('$script:GenerationLogPath', 'codex' + [Environment]::NewLine)",
      "''"
    )
    $completionInput = 'codex --hel'

    $null = [System.Management.Automation.CommandCompletion]::CompleteInput($completionInput, $completionInput.Length, $null)
    $script:CodexCompletionInitialized | Should -BeFalse
    $null = [System.Management.Automation.CommandCompletion]::CompleteInput($completionInput, $completionInput.Length, $null)
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('codex')
    Set-Content -LiteralPath $script:CodexExecutablePath -Value $codexFixtureLines
    Register-LazyCodexCompletion
    $matchesAfterRetry = [System.Management.Automation.CommandCompletion]::CompleteInput($completionInput, $completionInput.Length, $null).CompletionMatches

    $matchesAfterRetry.CompletionText | Should -Contain '--help'
    $script:CodexCompletionInitialized | Should -BeTrue
  }

  It 'debe inicializar fnm al primer cambio de carpeta y preservar los cambios posteriores' {
    $targetDirectory = Join-Path $script:FixtureDirectory 'project'
    New-Item -ItemType Directory -Path $targetDirectory | Out-Null

    Set-LocationWithFnm $targetDirectory
    (Get-Location).Path | Should -Be $targetDirectory
    Set-LocationWithFnm $script:OriginalLocation

    (Get-Location).Path | Should -Be $script:OriginalLocation
    $global:FixtureFnmUses | Should -Be 2
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('fnm')
  }

  It 'debe inicializar fnm antes de ejecutar un comando y preservar sus argumentos' {
    $result = fnm use '24' '--silent-if-unchanged'
    $secondResult = fnm current

    $result | Should -Be 'use|24|--silent-if-unchanged'
    $secondResult | Should -Be 'current'
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('fnm')
  }

  It 'debe cambiar de carpeta cuando fnm no puede generar su entorno' {
    Set-Content -LiteralPath $script:FnmCommandInfo.Source -Value @(
      "[IO.File]::AppendAllText('$script:GenerationLogPath', 'fnm' + [Environment]::NewLine)",
      "''"
    )
    $targetDirectory = Join-Path $script:FixtureDirectory 'fallback-project'
    New-Item -ItemType Directory -Path $targetDirectory | Out-Null

    Set-LocationWithFnm $targetDirectory

    (Get-Location).Path | Should -Be $targetDirectory
    $script:FnmInitialized | Should -BeFalse
    Set-LocationWithFnm $script:OriginalLocation
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('fnm')
  }

  It 'debe cargar zoxide al usar z y conservar los argumentos de búsqueda' {
    $result = z 'primer proyecto' second
    $secondResult = z another

    $result | Should -Be 'salto z'
    $secondResult | Should -Be 'salto z'
    $global:FixtureZoxideArguments | Should -Be @('z', 'another')
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('zoxide')
  }

  It 'debe cargar zoxide al usar zi y mantener la selección interactiva' {
    $result = zi 'proyecto con espacios'

    $result | Should -Be 'salto zi'
    $global:FixtureZoxideArguments | Should -Be @('zi', 'proyecto con espacios')
    @(Get-Content -LiteralPath $script:GenerationLogPath) | Should -Be @('zoxide')
  }

  It 'debe conservar el prompt y LASTEXITCODE después del primer z y un cambio de carpeta' {
    function global:prompt { 'prompt conservado' }
    $null = z example
    Set-Location -LiteralPath $script:FixtureDirectory
    $global:LASTEXITCODE = 7

    $renderedPrompt = prompt

    $renderedPrompt | Should -Be 'prompt conservado'
    $global:LASTEXITCODE | Should -Be 7
    Set-Location -LiteralPath $script:OriginalLocation
  }

  It 'debe resolver una instalación legacy de fnm cuando no existe la moderna' {
    $originalFnmDirectory = $env:FNM_DIR
    $userDataDirectory = Join-Path $script:FixtureDirectory 'user-data'
    $legacyDirectory = Join-Path $script:FixtureDirectory '.fnm'
    New-Item -ItemType Directory -Path $legacyDirectory -Force | Out-Null
    try {
      $env:FNM_DIR = $null

      $resolvedDirectory = Get-FnmDataDirectory -UserDataDirectory $userDataDirectory -UserHomeDirectory $script:FixtureDirectory

      $resolvedDirectory | Should -Be $legacyDirectory
    } finally { $env:FNM_DIR = $originalFnmDirectory }
  }

  It 'debe preferir FNM_DIR sobre las instalaciones detectadas' {
    $originalFnmDirectory = $env:FNM_DIR
    $customDirectory = Join-Path $script:FixtureDirectory 'custom-fnm'
    try {
      $env:FNM_DIR = $customDirectory

      $resolvedDirectory = Get-FnmDataDirectory -UserDataDirectory $script:FixtureDirectory -UserHomeDirectory $script:FixtureDirectory

      $resolvedDirectory | Should -Be $customDirectory
    } finally { $env:FNM_DIR = $originalFnmDirectory }
  }

  It 'debe ofrecer Node antes del primer cd cuando falta el directorio de fnm en PATH' -Skip:([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    $fnmDirectory = Join-Path $script:FixtureDirectory 'fnm-root'
    $defaultDirectory = Join-Path $fnmDirectory 'aliases/default'
    New-Item -ItemType Directory -Path $defaultDirectory -Force | Out-Null
    $env:PATH = $script:FixtureDirectory
    $nodeExecutablePath = Join-Path $defaultDirectory 'node.cmd'
    Set-Content -LiteralPath $nodeExecutablePath -Value @('@echo off', 'echo v24-fixture')

    Add-FnmDefaultNodeDirectoryToPath -FnmDirectory $fnmDirectory
    $resolvedNode = Get-Command node -CommandType Application
    $nodeVersion = & $resolvedNode.Source --version

    $nodeVersion | Should -Be 'v24-fixture'
    $script:FnmInitialized | Should -BeFalse
  }

  It 'debe conservar la prioridad del PATH heredado y no duplicar el fallback de fnm' {
    $fnmDirectory = Join-Path $script:FixtureDirectory 'fnm-root'
    $defaultDirectory = Join-Path $fnmDirectory 'aliases/default'
    New-Item -ItemType Directory -Path $defaultDirectory -Force | Out-Null
    $originalPathEntries = @($env:PATH -split [IO.Path]::PathSeparator)

    Add-FnmDefaultNodeDirectoryToPath -FnmDirectory $fnmDirectory
    Add-FnmDefaultNodeDirectoryToPath -FnmDirectory $fnmDirectory
    $updatedPathEntries = @($env:PATH -split [IO.Path]::PathSeparator)

    $updatedPathEntries[0..($originalPathEntries.Count - 1)] | Should -Be $originalPathEntries
    @($updatedPathEntries | Where-Object { $_ -eq $defaultDirectory }) | Should -HaveCount 1
  }

  It 'debe resolver un fnm nativo invocable aunque el perfil defina la función fnm' -Skip:([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    $nativeFnmPath = Join-Path $script:FixtureDirectory 'fnm.cmd'
    Set-Content -LiteralPath $nativeFnmPath -Value @('@echo off', 'echo fnm-native %*')

    $resolvedExecutable = Resolve-FnmExecutable
    $nativeResult = & $resolvedExecutable --version

    $nativeResult | Should -Be 'fnm-native --version'
  }
}

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
      '$script:CxCommitReasoning',
      '$script:CxCodexInstallerUri'
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
    # Borde externo de `cx upgrade`: evita ejecutar el instalador real de Codex.
    function powershell.exe { }
    function npm { }

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

    It 'usa gpt-6.1-sol con esfuerzo medium en cx' {
      cx

      Should -Invoke codex -Times 1 -Exactly -ParameterFilter {
        $args[0] -eq '-m' -and
        $args[1] -eq 'gpt-6.1-sol' -and
        $args[2] -eq '-c' -and
        $args[3] -eq 'model_reasoning_effort=medium'
      }
    }

    It 'usa mismo modelo y esfuerzo en cxd' {
      cxd

      Should -Invoke codex -Times 1 -Exactly -ParameterFilter {
        $args[0] -eq '-m' -and
        $args[1] -eq 'gpt-6.1-sol' -and
        $args[2] -eq '-c' -and
        $args[3] -eq 'model_reasoning_effort=medium'
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

  Context 'cx upgrade' {
    BeforeEach {
      Mock Clear-Host { }
      Mock codex { }
      Mock npm { }
      Mock powershell.exe { }
    }

    It 'actualiza Codex con el instalador oficial en Windows PowerShell con Bypass, sin npm ni iniciar Codex' {
      cx upgrade

      Should -Invoke powershell.exe -Times 1 -Exactly -ParameterFilter {
        ($args -join ' ') -eq '-NoProfile -ExecutionPolicy Bypass -Command irm https://chatgpt.com/codex/install.ps1 | iex'
      }
      Should -Invoke npm -Times 0 -Exactly
      Should -Invoke codex -Times 0 -Exactly
    }
  }
}

Describe 'Microsoft.PowerShell_profile PR del prompt murilasso' {
  BeforeAll {
    $profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
    $tokens = $null
    $parseErrors = $null
    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$parseErrors)

    foreach ($variableName in @('MURILASSO_BASE_BRANCHES', 'MURILASSO_OPEN_PR_STATE')) {
      $assignment = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
          $node.Left.Extent.Text -eq ('$' + $variableName)
        }, $true)
      . ([scriptblock]::Create($assignment.Extent.Text))
    }

    foreach ($functionName in @('Test-MurilassoBaseBranch', 'Read-MurilassoPrCache')) {
      $functionDefinition = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
      . ([scriptblock]::Create($functionDefinition.Extent.Text))
    }

    function Write-TestPrCache {
      param([string]$PrState)

      $cachePath = Join-Path $TestDrive ('pr-' + [guid]::NewGuid().ToString('N'))
      Set-Content -LiteralPath $cachePath -Value ("https://github.com/owner/repo/pull/8`n{0}" -f $PrState) -NoNewline
      return $cachePath
    }
  }

  BeforeEach {
    $env:MURILASSO_PR_URL = ''
    $env:MURILASSO_PR_STATE = ''
    $env:MURILASSO_PR_NUMBER = ''
  }

  It 'debe ocultar un PR <PrState> en la branch base <Branch>' -ForEach @(
    @{ Branch = 'main'; PrState = 'MERGED' }
    @{ Branch = 'master'; PrState = 'CLOSED' }
    @{ Branch = 'develop'; PrState = 'MERGED' }
  ) {
    Read-MurilassoPrCache -CachePath (Write-TestPrCache -PrState $PrState) -Branch $Branch

    $env:MURILASSO_PR_URL | Should -BeNullOrEmpty
    $env:MURILASSO_PR_STATE | Should -BeNullOrEmpty
    $env:MURILASSO_PR_NUMBER | Should -BeNullOrEmpty
  }

  It 'debe mostrar un PR abierto en la branch base' {
    Read-MurilassoPrCache -CachePath (Write-TestPrCache -PrState 'OPEN') -Branch 'main'

    $env:MURILASSO_PR_URL | Should -Be 'https://github.com/owner/repo/pull/8'
    $env:MURILASSO_PR_STATE | Should -Be 'OPEN'
    $env:MURILASSO_PR_NUMBER | Should -Be '8'
  }

  It 'debe mostrar un PR mergeado en una feature branch' {
    Read-MurilassoPrCache -CachePath (Write-TestPrCache -PrState 'MERGED') -Branch 'feature/main-fix'

    $env:MURILASSO_PR_STATE | Should -Be 'MERGED'
    $env:MURILASSO_PR_NUMBER | Should -Be '8'
  }
}

Describe 'Microsoft.PowerShell_profile prompt murilasso nativo' {
  BeforeAll {
    $profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
    $tokens = $null
    $parseErrors = $null
    $profileAst = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$parseErrors)

    # El prompt resuelve el path estable de node con los helpers del cache de init.
    foreach ($functionName in @('Get-ExecutableTargetInfo', 'Resolve-FileSystemLinkTarget', 'Get-StableExecutablePath', 'Get-ExecutableFingerprint')) {
      $functionDefinition = $profileAst.Find({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
      . ([scriptblock]::Create($functionDefinition.Extent.Text))
    }

    # La sección del prompt se carga completa: define constantes, estado y el `prompt` global.
    $script:OriginalPrompt = $function:prompt
    $script:OriginalLocation = (Get-Location).Path
    $profileLines = [System.IO.File]::ReadAllLines($profilePath)
    $sectionStart = [Array]::FindIndex($profileLines, [Predicate[string]] { param($line) $line.StartsWith('# --- Prompt murilasso ') })
    $sectionEnd = [Array]::FindIndex($profileLines, [Predicate[string]] { param($line) $line.StartsWith('# --- Fin prompt murilasso') })
    . ([scriptblock]::Create(($profileLines[$sectionStart..$sectionEnd] -join [Environment]::NewLine)))

    function ConvertTo-PlainPromptText {
      param([string]$Text)

      return $Text -replace '\x1b\[[0-9;]*m', '' -replace '\x1b\]8;;[^\x07]*\x07', ''
    }

    function New-TestGitRepository {
      param([string]$BranchName)

      $repositoryPath = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $repositoryPath | Out-Null
      & git -C $repositoryPath init --quiet --initial-branch $BranchName
      Set-Content -LiteralPath (Join-Path $repositoryPath 'tracked.txt') -Value 'original'
      & git -C $repositoryPath add tracked.txt
      & git -C $repositoryPath -c user.name='Prompt Test' -c user.email='prompt-test@example.com' -c commit.gpgsign=false commit --quiet -m 'commit inicial'
      return $repositoryPath
    }
  }

  AfterAll {
    Set-Location -LiteralPath $script:OriginalLocation
    Set-Item -LiteralPath Function:\global:prompt -Value $script:OriginalPrompt
    Remove-Item -LiteralPath Function:\global:__zoxide_hook -ErrorAction SilentlyContinue
  }

  BeforeEach {
    $env:MURILASSO_PR_URL = ''
    $env:MURILASSO_PR_STATE = ''
    $env:MURILASSO_PR_NUMBER = ''
    $env:MURILASSO_PR_CI = ''
    $script:ZoxideInitialized = $false
  }

  It 'debe contar cambios, sincronización y stash desde git status porcelain v2' {
    $gitStatus = ConvertFrom-MurilassoGitStatus -StatusLines @(
      '# branch.oid 0123456789abcdef0123456789abcdef01234567'
      '# branch.head feature/prompt'
      '# branch.upstream origin/feature/prompt'
      '# branch.ab +2 -1'
      '# stash 3'
      '1 M. N... 100644 100644 100644 aaaa bbbb staged.txt'
      '1 .M N... 100644 100644 100644 aaaa bbbb modified.txt'
      '1 MM N... 100644 100644 100644 aaaa bbbb both.txt'
      '2 R. N... 100644 100644 100644 aaaa bbbb R100 renamed.txt old.txt'
      'u UU N... 100644 100644 100644 100644 aaaa bbbb cccc conflict.txt'
      '? untracked.txt'
    )

    $gitStatus.Branch | Should -Be 'feature/prompt'
    $gitStatus.Ahead | Should -Be 2
    $gitStatus.Behind | Should -Be 1
    $gitStatus.StashCount | Should -Be 3
    $gitStatus.Staged | Should -Be 3
    $gitStatus.Modified | Should -Be 2
    $gitStatus.Unmerged | Should -Be 1
    $gitStatus.Untracked | Should -Be 1
    $gitStatus.Detached | Should -BeFalse
    $gitStatus.UpstreamGone | Should -BeFalse
  }

  It 'debe marcar la branch remota borrada y el HEAD detached' {
    $goneUpstreamStatus = ConvertFrom-MurilassoGitStatus -StatusLines @('# branch.head feature/gone', '# branch.upstream origin/feature/gone')
    $detachedStatus = ConvertFrom-MurilassoGitStatus -StatusLines @('# branch.oid 0123456789abcdef', '# branch.head (detached)')

    $goneUpstreamStatus.UpstreamGone | Should -BeTrue
    $detachedStatus.Detached | Should -BeTrue
    ConvertTo-PlainPromptText (Format-MurilassoGitSegment -GitStatus $detachedStatus -Operation '') | Should -Match '0123456'
    ConvertTo-PlainPromptText (Format-MurilassoGitSegment -GitStatus $detachedStatus -Operation '') | Should -Not -Match '0123456789'
  }

  It 'debe acortar <Path> a <ExpectedPath>' -ForEach @(
    @{ Path = 'C:\Users\guido'; ExpectedPath = '~' }
    @{ Path = 'C:\Users\guido\system-config'; ExpectedPath = '~/system-config' }
    @{ Path = 'C:\Users\guido\system-config\configs\PowerShell'; ExpectedPath = '~/../configs/PowerShell' }
    @{ Path = 'C:\Windows'; ExpectedPath = 'C:/Windows' }
    @{ Path = 'C:\Windows\System32\drivers'; ExpectedPath = 'C:/../System32/drivers' }
    @{ Path = 'C:\'; ExpectedPath = 'C:/' }
    @{ Path = 'C:\Users\guidoextra'; ExpectedPath = 'C:/Users/guidoextra' }
  ) {
    Get-MurilassoShortPath -Path $Path -HomePath 'C:\Users\guido' | Should -Be $ExpectedPath
  }

  It 'debe formatear <Milliseconds> ms como <ExpectedDuration>' -ForEach @(
    @{ Milliseconds = 4200; ExpectedDuration = '4.2s' }
    @{ Milliseconds = 75000; ExpectedDuration = '1m15s' }
    @{ Milliseconds = 3720000; ExpectedDuration = '1h02m' }
  ) {
    Format-MurilassoDuration -Milliseconds $Milliseconds | Should -Be $ExpectedDuration
  }

  It 'debe mostrar el exit code con el nombre de la señal' {
    ConvertTo-PlainPromptText (Format-MurilassoStatusSegment -ExitCode 130) | Should -Match '130 SIGINT$'
    ConvertTo-PlainPromptText (Format-MurilassoStatusSegment -ExitCode 2) | Should -Match ' 2$'
    Format-MurilassoStatusSegment -ExitCode 0 | Should -BeNullOrEmpty
  }

  It 'debe avisar la versión del .nvmrc solo cuando no coincide con <NodeVersion>' -ForEach @(
    @{ NodeVersion = 'v24.14.1'; ExpectedVersion = '24'; ShowsMismatch = $false }
    @{ NodeVersion = 'v24.14.1'; ExpectedVersion = '24.14.1'; ShowsMismatch = $false }
    @{ NodeVersion = 'v24.14.1'; ExpectedVersion = '24.1'; ShowsMismatch = $true }
    @{ NodeVersion = 'v24.14.1'; ExpectedVersion = '20'; ShowsMismatch = $true }
    @{ NodeVersion = 'v24.14.1'; ExpectedVersion = 'lts/*'; ShowsMismatch = $false }
  ) {
    $nodeSegment = ConvertTo-PlainPromptText (Format-MurilassoNodeSegment -NodeVersion $NodeVersion -ExpectedVersion $ExpectedVersion)

    $nodeSegment | Should -Match ([regex]::Escape($NodeVersion))
    ($nodeSegment -match '\.nvmrc') | Should -Be $ShowsMismatch
  }

  It 'debe alinear el bloque derecho al ancho de la consola y ocultarlo si no entra' {
    $leftText = Format-MurilassoText -Text 'izquierda' -Color 'Blue'
    $rightText = Format-MurilassoText -Text 'derecha' -Color 'Frame'

    $alignedLine = Join-MurilassoPromptLine -LeftText $leftText -RightText $rightText -ConsoleWidth 40
    $narrowLine = Join-MurilassoPromptLine -LeftText $leftText -RightText $rightText -ConsoleWidth 15

    Get-MurilassoDisplayWidth -Text $alignedLine | Should -Be (40 - $MURILASSO_RIGHT_PROMPT_MARGIN)
    ConvertTo-PlainPromptText $alignedLine | Should -Match '^izquierda +derecha$'
    $narrowLine | Should -Be $leftText
  }

  It 'debe mostrar la PR con link y el estado de su CI' {
    $env:MURILASSO_PR_URL = 'https://github.com/owner/repo/pull/8'
    $env:MURILASSO_PR_STATE = 'OPEN'
    $env:MURILASSO_PR_NUMBER = '8'
    $env:MURILASSO_PR_CI = 'FAILURE'

    $prSegment = Format-MurilassoPrSegment

    $prSegment | Should -Match ([regex]::Escape(']8;;https://github.com/owner/repo/pull/8'))
    ConvertTo-PlainPromptText $prSegment | Should -Match ('#8 ' + [regex]::Escape($MURILASSO_GLYPHS.CiFailure) + '$')
  }

  It 'debe renderizar branch y cambios de un repo real y preservar LASTEXITCODE' {
    Mock Start-MurilassoGhFetch { }
    $repositoryPath = New-TestGitRepository -BranchName 'feature/prompt-test'
    Set-Content -LiteralPath (Join-Path $repositoryPath 'tracked.txt') -Value 'modificado'
    Set-Content -LiteralPath (Join-Path $repositoryPath 'nuevo.txt') -Value 'sin trackear'
    Set-Location -LiteralPath $repositoryPath
    try {
      $global:LASTEXITCODE = 7

      $promptLines = @((ConvertTo-PlainPromptText (prompt)) -split '\r?\n')

      $global:LASTEXITCODE | Should -Be 7
      $promptLines.Count | Should -Be 2
      $promptLines[0] | Should -Match ([regex]::Escape($MURILASSO_GLYPHS.Branch + ' feature/prompt-test'))
      $promptLines[0] | Should -Match ([regex]::Escape($MURILASSO_GLYPHS.Modified + ' 1'))
      $promptLines[0] | Should -Match ([regex]::Escape($MURILASSO_GLYPHS.Untracked + ' 1'))
      $promptLines[1] | Should -Match ([regex]::Escape($MURILASSO_GLYPHS.PromptArrow) + ' $|# $')
      Should -Invoke Start-MurilassoGhFetch -Times 1 -Exactly
    } finally {
      Set-Location -LiteralPath $script:OriginalLocation
    }
  }

  It 'debe mostrar el rebase en curso con su paso' {
    Mock Start-MurilassoGhFetch { }
    $repositoryPath = New-TestGitRepository -BranchName 'feature/rebase-test'
    $rebaseDirectory = Join-Path $repositoryPath '.git/rebase-merge'
    New-Item -ItemType Directory -Path $rebaseDirectory | Out-Null
    Set-Content -LiteralPath (Join-Path $rebaseDirectory 'msgnum') -Value '2'
    Set-Content -LiteralPath (Join-Path $rebaseDirectory 'end') -Value '5'
    Set-Location -LiteralPath $repositoryPath
    try {
      ConvertTo-PlainPromptText (prompt) | Should -Match 'REBASE 2/5'
    } finally {
      Set-Location -LiteralPath $script:OriginalLocation
    }
  }

  It 'debe omitir el segmento git fuera de un repo' {
    Mock Start-MurilassoGhFetch { }
    $plainDirectory = Join-Path $TestDrive ('plain-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $plainDirectory | Out-Null
    Set-Location -LiteralPath $plainDirectory
    try {
      $firstPromptLine = (@((ConvertTo-PlainPromptText (prompt)) -split '\r?\n'))[0]

      $firstPromptLine | Should -Not -Match ([regex]::Escape($MURILASSO_GLYPHS.Branch))
      Should -Invoke Start-MurilassoGhFetch -Times 0 -Exactly
    } finally {
      Set-Location -LiteralPath $script:OriginalLocation
    }
  }

  It 'debe registrar la carpeta en zoxide desde el prompt cuando zoxide está inicializado' {
    $global:FixtureZoxideHookCalls = 0
    function global:__zoxide_hook { $global:FixtureZoxideHookCalls++ }
    $script:ZoxideInitialized = $true

    $null = prompt

    $global:FixtureZoxideHookCalls | Should -Be 1
  }
}
