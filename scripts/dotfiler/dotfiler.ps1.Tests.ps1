Describe 'dotfiler.ps1' {
  BeforeAll {
    $script:PreviousSkipMain = $env:DOTFILER_PS1_SKIP_MAIN
    $env:DOTFILER_PS1_SKIP_MAIN = '1'
    . (Join-Path -Path $PSScriptRoot -ChildPath 'dotfiler.ps1')
  }

  AfterAll {
    if ($null -eq $script:PreviousSkipMain) {
      Remove-Item Env:DOTFILER_PS1_SKIP_MAIN -ErrorAction SilentlyContinue
    } else {
      $env:DOTFILER_PS1_SKIP_MAIN = $script:PreviousSkipMain
    }
  }

  BeforeEach {
    $script:DryRun = $false
    $script:UseColor = $false
    $script:Quiet = $false
    $script:VerboseMode = $false
    $script:IsElevatedSymlinkMode = $false
    $script:PreferredCommandPaths = @{}
    $script:DocumentsDir = 'C:\Users\tester\Documents'
    $script:CountCreated = 0
    $script:CountReplaced = 0
    $script:CountBackups = 0
    $script:CountSimulated = 0
    $script:CountErrors = 0
    $script:CountPlannedCreated = 0
    $script:CountPlannedReplaced = 0
    $script:CountPlannedBackups = 0
    $script:LastOutputWasSeparator = $false
    $script:Diagnostics = [System.Collections.Generic.List[object]]::new()
    $script:ConfigPathsFile = ''
  }

  It 'Print-Summary imprime tabla y cierre final en una ejecucion exitosa' {
    $script:StartTime = [datetime]'2026-04-12T10:00:00-03:00'
    $script:CountCreated = 2
    $script:CountReplaced = 1
    $script:CountBackups = 1
    $script:CountErrors = 0

    $summaryOutput = Print-Summary | Out-String

    $summaryOutput | Should -Match 'RESUMEN'
    $summaryOutput | Should -Match '╔════════'
    $summaryOutput | Should -Match 'Metrica'
    $summaryOutput | Should -Match 'Modo ejecucion'
    $summaryOutput | Should -Match '\[ FIN \] Configuracion de symlinks finalizada\.'
  }

  It 'Print-Summary conserva el offset horario completo en los timestamps locales' {
    $script:StartTime = [datetime]'2026-04-12T10:00:00-03:00'

    $summaryOutput = Print-Summary | Out-String

    $summaryOutput | Should -Match '2026-04-12T10:00:00-03:00'
    $summaryOutput | Should -Match 'Fin \(local\)\s+║ \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}-03:00'
  }

  It 'Print-Summary muestra labels de plan y mensaje de simulacion en dry-run' {
    $script:DryRun = $true
    $script:StartTime = [datetime]'2026-04-12T10:00:00-03:00'
    $script:CountPlannedCreated = 3
    $script:CountPlannedReplaced = 2
    $script:CountPlannedBackups = 1
    $script:CountSimulated = 4

    $summaryOutput = Print-Summary | Out-String

    $summaryOutput | Should -Match 'Creados \(plan\)'
    $summaryOutput | Should -Match 'Reemplazados \(plan\)'
    $summaryOutput | Should -Match 'Respaldos \(plan\)'
    $summaryOutput | Should -Match 'Modo simulacion activo, no se escribieron cambios en el sistema de archivos\.'
    $summaryOutput | Should -Match '\[ FIN \] Configuracion de symlinks finalizada\.'
  }

  It 'Print-Diagnostics imprime el bloque de diagnostico con errores enumerados' {
    $script:Diagnostics.Add([PSCustomObject]@{
        Target = 'C:\destino'
        Reason = 'Fallo controlado'
      })

    $diagnosticsOutput = Print-Diagnostics | Out-String

    $diagnosticsOutput | Should -Match 'DIAGNOSTICO'
    $diagnosticsOutput | Should -Match '\[ ERROR \] 1\) destino=C:\\destino \| causa=Fallo controlado'
  }

  It 'Write-SymlinkLine usa flecha doble violeta y rutas con estilo ANSI cuando hay color' {
    $script:UseColor = $true
    $styledOutput = & {
      Write-SymlinkLine -Label 'OK' -LabelColor Green -Prefix 'Symlink creado' -TargetPath 'C:\destino' -SourcePath 'C:\fuente'
    } | Out-String

    $styledOutput | Should -Match 'Symlink creado'
    $styledOutput | Should -Match 'C:\\destino'
    $styledOutput | Should -Match 'C:\\fuente'
    $styledOutput | Should -Match '→→'
  }

  It 'Write-Separator evita separadores consecutivos duplicados' {
    $separatorOutput = & {
      Write-Separator
      Write-Separator
      Write-PlainLine -Message 'contenido'
      Write-Separator
    } | Out-String

    ([regex]::Matches($separatorOutput, '────────────────────────────────────────────────────────')).Count | Should -Be 2
  }

  It 'instala una dependencia faltante con winget cuando existe configuracion de paquete' {
    $script:installInvocations = [System.Collections.Generic.List[string]]::new()
    $script:commandInstalled = $false

    Mock Test-CommandAvailable {
      param([string]$Name)
      return $Name -eq 'winget' -or $script:commandInstalled
    }
    Mock Test-CommandOperational {
      param([string]$CommandName)
      return $script:commandInstalled
    }
    Mock Install-WingetPackage {
      param([string]$PackageId, [string]$CommandName)
      $script:installInvocations.Add("$CommandName|$PackageId")
      $script:commandInstalled = $true
    }
    Mock Update-ProcessPathFromEnvironment {}

    Ensure-CommandAvailable -CommandName 'jq' -WingetPackageId 'jqlang.jq'

    $script:installInvocations.Count | Should -Be 1
    $script:installInvocations[0] | Should -Be 'jq|jqlang.jq'
    Assert-MockCalled Update-ProcessPathFromEnvironment -Times 1 -Exactly -Scope It
  }

  It 'falla cuando falta una dependencia y winget no esta disponible' {
    Mock Test-CommandAvailable {
      param([string]$Name)
      return $false
    }
    Mock Test-CommandOperational { $false }

    { Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq' } | Should -Throw -ExpectedMessage '*winget*'
  }

  It 'reintenta validar una dependencia despues de refrescar PATH tras instalar con winget' {
    $script:pathWasRefreshed = $false

    Mock Test-CommandAvailable {
      param([string]$Name)
      if ($Name -eq 'winget') {
        return $true
      }

      return $script:pathWasRefreshed
    }
    Mock Test-CommandOperational { $script:pathWasRefreshed }
    Mock Install-WingetPackage {}
    Mock Update-ProcessPathFromEnvironment {
      $script:pathWasRefreshed = $true
    }

    { Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq' } | Should -Not -Throw
    Assert-MockCalled Update-ProcessPathFromEnvironment -Times 1 -Exactly -Scope It
  }

  It 'omite un ejecutable previo roto y conserva la ruta operativa encontrada para usos posteriores' {
    Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq 'C:\winget\yq.exe' }
    Mock Get-Command {
      param([string]$Name, [switch]$All)

      if ($Name -eq 'yq' -and $All) {
        return @(
          [PSCustomObject]@{ Source = 'C:\broken\yq.exe'; Path = 'C:\broken\yq.exe' },
          [PSCustomObject]@{ Source = 'C:\winget\yq.exe'; Path = 'C:\winget\yq.exe' }
        )
      }

      if ($Name -eq 'yq') {
        return [PSCustomObject]@{ Source = 'C:\broken\yq.exe'; Path = 'C:\broken\yq.exe' }
      }

      return $null
    }
    Mock Test-CommandOperational {
      param([string]$CommandName, [string]$CommandPath)
      return $CommandPath -eq 'C:\winget\yq.exe'
    }

    Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq'

    $script:PreferredCommandPaths['yq'] | Should -Be 'C:\winget\yq.exe'
    (Get-ResolvedCommandPath -CommandName 'yq') | Should -Be 'C:\winget\yq.exe'
  }

  It 'avisa cuando --dry-run necesita instalar una dependencia faltante' {
    $script:DryRun = $true

    Mock Test-CommandAvailable {
      param([string]$Name)
      if ($Name -eq 'winget') {
        return $true
      }

      return $false
    }
    Mock Test-CommandOperational { $false }
    Mock Install-WingetPackage {}
    Mock Update-ProcessPathFromEnvironment {}
    Mock Write-Warn {}

    { Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq' } | Should -Throw -ExpectedMessage '*sigue sin estar disponible*'

    Assert-MockCalled Write-Warn -Times 1 -Exactly -Scope It -ParameterFilter {
      $Message -like '*--dry-run*' -and $Message -like "*'yq'*"
    }
  }

  It 'falla cuando winget instala pero el comando sigue sin aparecer despues de refrescar PATH' {
    Mock Test-CommandAvailable {
      param([string]$Name)
      if ($Name -eq 'winget') {
        return $true
      }

      return $false
    }
    Mock Test-CommandOperational { $false }
    Mock Install-WingetPackage {}
    Mock Update-ProcessPathFromEnvironment {}

    { Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq' } | Should -Throw -ExpectedMessage '*sigue sin estar disponible*'
  }

  It 'reinstala una dependencia cuando el ejecutable existe pero no funciona' {
    $script:installInvocations = [System.Collections.Generic.List[string]]::new()
    $script:commandOperational = $false

    Mock Test-CommandAvailable {
      param([string]$Name)
      return $true
    }
    Mock Test-CommandOperational {
      param([string]$CommandName)
      return $script:commandOperational
    }
    Mock Install-WingetPackage {
      param([string]$PackageId, [string]$CommandName)
      $script:installInvocations.Add("$CommandName|$PackageId")
      $script:commandOperational = $true
    }
    Mock Update-ProcessPathFromEnvironment {}

    Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq'

    $script:installInvocations.Count | Should -Be 1
    $script:installInvocations[0] | Should -Be 'yq|MikeFarah.yq'
    Assert-MockCalled Update-ProcessPathFromEnvironment -Times 1 -Exactly -Scope It
  }

  It 'considera yq no operativo cuando no soporta la sintaxis requerida por dotfiler' {
    Mock Invoke-ExternalCommand {
      [PSCustomObject]@{
        ExitCode = 1
        Output = 'unsupported'
      }
    }

    (Test-YqCommandOperational) | Should -Be $false
  }

  It 'resuelve comandos por la ruta preferida cuando ya fue validada' {
    $script:PreferredCommandPaths['jq'] = 'C:\winget\jq.exe'
    Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq 'C:\winget\jq.exe' }

    Mock Get-Command {
      throw 'Get-Command no deberia ejecutarse cuando existe una ruta preferida'
    }

    (Get-ResolvedCommandPath -CommandName 'jq') | Should -Be 'C:\winget\jq.exe'
  }

  It 'prioriza PATH de User y Machine sobre Process al recomponer entradas unicas' {
    $mergedPath = Join-UniquePathEntries -RawPathValues @(
      'C:\Users\guido\AppData\Local\Microsoft\WinGet\Links;C:\Tools',
      'C:\Program Files\Git\cmd;C:\Windows\System32',
      'C:\BrokenTools;C:\Tools;C:\Windows\System32'
    )

    $mergedPath | Should -Be 'C:\Users\guido\AppData\Local\Microsoft\WinGet\Links;C:\Tools;C:\Program Files\Git\cmd;C:\Windows\System32;C:\BrokenTools'
  }

  It 'convierte paths desde JSON generado por yq' {
    $script:ConfigPathsFile = 'C:\repo\symlinks.yml'

    Mock Get-YamlPathsJson {
      @'
[
  {
    "path": "PowerShell/Microsoft.PowerShell_profile.ps1",
    "target": "Documents/PowerShell"
  }
]
'@
    }
    Mock Test-JsonArray { $true }

    $entries = @(Get-ConfigEntries)

    $entries.Count | Should -Be 1
    $entries[0].path | Should -Be 'PowerShell/Microsoft.PowerShell_profile.ps1'
    $entries[0].target | Should -Be 'Documents/PowerShell'
  }

  It 'convierte JSON anidado sin depender de parametros no disponibles en PowerShell 5.1' {
    $script:ConfigPathsFile = 'C:\repo\symlinks.yml'

    Mock Get-YamlPathsJson {
      @'
[
  {
    "path": "git/.gitconfig",
    "overrides": [
      {
        "windows": true,
        "target": "Documents/Git"
      }
    ]
  }
]
'@
    }
    Mock Test-JsonArray { $true }

    $entries = @(Get-ConfigEntries)

    $entries.Count | Should -Be 1
    $entries[0].overrides.Count | Should -Be 1
    $entries[0].overrides[0].target | Should -Be 'Documents/Git'
  }

  It 'valida con jq cuando el JSON representa un arreglo' {
    Mock Invoke-ExternalCommand {
      [PSCustomObject]@{
        ExitCode = 0
        Output = 'true'
      }
    }

    (Test-JsonArray -JsonText '[{"path":"example"}]') | Should -Be $true
  }

  It 'drena stdout y stderr abundantes sin bloquear el proceso hijo' {
    $dotfilerPath = Join-Path -Path $PSScriptRoot -ChildPath 'dotfiler.ps1'
    $heavyOutputScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'invoke-external-command-heavy-output.ps1'
    $currentPowerShellPath = (Get-Process -Id $PID).Path

    $job = Start-Job -ArgumentList $dotfilerPath, $currentPowerShellPath, $heavyOutputScriptPath -ScriptBlock {
      param($ImportedScriptPath, $ExecutablePath, $ScriptPath)

      $env:DOTFILER_PS1_SKIP_MAIN = '1'
      . $ImportedScriptPath

      Invoke-ExternalCommand -FilePath $ExecutablePath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $ScriptPath
      )
    }

    try {
      $completedJob = Wait-Job -Job $job -Timeout 10

      $completedJob | Should -Not -BeNullOrEmpty

      $result = Receive-Job -Job $job

      $result.ExitCode | Should -Be 0
      $result.Output | Should -Match 'stdout line 0'
      $result.Output | Should -Match 'stderr line 0'
    } finally {
      if ($job.State -eq 'Running') {
        Stop-Job -Job $job
      }

      Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
  }

  It 'detecta errores de permisos insuficientes para symlinks' {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.UnauthorizedAccessException]::new('The required privilege is not held by the client'),
      'PrivilegeError',
      [System.Management.Automation.ErrorCategory]::PermissionDenied,
      $null
    )

    (Test-IsPrivilegeElevationError -ErrorRecord $errorRecord) | Should -Be $true
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

    $script:elevatedInvocation.Source | Should -Be 'C:\fuente'
    $script:elevatedInvocation.Target | Should -Be 'C:\destino'
    $script:CountErrors | Should -Be 0
  }

  It 'cita argumentos con espacios antes de relanzar el proceso elevado' {
    $processArguments = Get-ElevatedSymlinkProcessArguments `
      -ScriptPath 'C:\Users\guido\Source Repos\system-config\scripts\dotfiler\dotfiler.ps1' `
      -SourcePath 'C:\Users\guido\Source Repos\config file.ps1' `
      -TargetPath 'C:\Users\guido\AppData\Roaming\My Folder\profile.ps1'

    $processArguments | Should -Be @(
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

  It 'arma una cadena de argumentos compatible con Windows PowerShell 5.1' {
    $argumentString = ConvertTo-WindowsProcessArgumentsString -ArgumentList @(
      'eval',
      '.paths',
      'C:\Users\guido\Source Repos\symlinks file.yml',
      'value "with quotes"'
    )

    $argumentString | Should -Be 'eval .paths "C:\Users\guido\Source Repos\symlinks file.yml" "value \"with quotes\""'
  }

  It 'no clasifica errores genericos como problemas de elevacion' {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new('Generic failure'),
      'GenericError',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $null
    )

    (Test-IsPrivilegeElevationError -ErrorRecord $errorRecord) | Should -Be $false
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

    (Test-EntryIncluded -Entry $entry) | Should -Be $true
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

    $overrideTarget.UsesExactTarget | Should -Be $false
    $overrideTarget.ConfiguredTarget | Should -Be 'AppData/Roaming'
  }

  It 'expande ~, $HOME, $DOCUMENTS y $USER en rutas de usuario' {
    $script:HomeDir = 'C:\Users\tester'
    $script:DocumentsDir = 'C:\Users\tester\Documentos'
    $script:WindowsUser = 'windows-user'

    (Expand-UserPath -Path '~') | Should -Be 'C:\Users\tester'
    (Expand-UserPath -Path '~\Documents') | Should -Be 'C:\Users\tester\Documents'
    (Expand-UserPath -Path '$DOCUMENTS\PowerShell') | Should -Be 'C:\Users\tester\Documentos\PowerShell'
    (Expand-UserPath -Path '$HOME\AppData\$USER\file.txt') | Should -Be 'C:\Users\tester\AppData\windows-user\file.txt'
  }

  It 'resuelve targets base por defecto, absolutos y relativos' {
    $script:HomeDir = 'C:\Users\tester'

    (Resolve-TargetBase -Target $null) | Should -Be 'C:\Users\tester'
    (Resolve-TargetBase -Target 'Documents\PowerShell') | Should -Be 'C:\Users\tester\Documents\PowerShell'
    (Resolve-TargetBase -Target 'D:\dotfiles\target') | Should -Be 'D:\dotfiles\target'
  }

  It 'ordena resultados wildcard y devuelve vacio para fuentes inexistentes' {
    $testRootDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
    $script:ConfigsDir = Join-Path -Path $testRootDirectory -ChildPath 'configs'
    New-Item -ItemType Directory -Path (Join-Path -Path $script:ConfigsDir -ChildPath 'wild') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $script:ConfigsDir -ChildPath 'wild\b-file.txt') -Value 'b'
    Set-Content -LiteralPath (Join-Path -Path $script:ConfigsDir -ChildPath 'wild\a-file.txt') -Value 'a'

    $resolvedSources = @(Get-ResolvedSources -OriginalPath 'wild\*')
    $missingSources = @(Get-ResolvedSources -OriginalPath 'missing*')

    $resolvedSources.Count | Should -Be 2
    $resolvedSources[0].Name | Should -Be 'a-file.txt'
    $resolvedSources[1].Name | Should -Be 'b-file.txt'
    $missingSources.Count | Should -Be 0

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

    $operations.Count | Should -Be 1
    $operations[0].Source | Should -Be $sourceDirectory
    $operations[0].Target | Should -Be (Join-Path -Path $script:HomeDir -ChildPath '.agents/.codex/skills/.system')
    $operations[0].Group | Should -Be (Join-Path -Path $script:HomeDir -ChildPath '.agents/.codex/skills')

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

    $operations.Count | Should -Be 0
    $script:CountErrors | Should -Be 1
    if ($script:Diagnostics.Count -gt 0) {
      $script:Diagnostics[0].Reason | Should -Match 'exactTarget no admite patrones wildcard'
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

    $operations.Count | Should -Be 0
    $script:CountErrors | Should -Be 0
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

    $operations.Count | Should -Be 0
    $script:CountErrors | Should -Be 1
    $script:Diagnostics.Count | Should -Be 1
    $script:Diagnostics[0].Reason | Should -Match 'Ruta de origen inexistente'
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

    $operations.Count | Should -Be 0
    $script:CountErrors | Should -Be 0
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

    $operations.Count | Should -Be 0
    $script:CountErrors | Should -Be 1
    if ($script:Diagnostics.Count -gt 0) {
      $script:Diagnostics[0].Reason | Should -Match 'target y exactTarget al mismo tiempo'
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

    $operations.Count | Should -Be 0
    $script:CountErrors | Should -Be 1
    if ($script:Diagnostics.Count -gt 0) {
      $script:Diagnostics[0].Reason | Should -Match 'override no puede definir target y exactTarget'
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

    $script:DryRun | Should -Be $true
    $script:UseColor | Should -Be $false
    $script:UseIcons | Should -Be $false
    $script:VerboseMode | Should -Be $true
    $script:Quiet | Should -Be $true
    $script:IsElevatedSymlinkMode | Should -Be $true
    $script:ElevatedSymlinkSource | Should -Be 'C:\source'
    $script:ElevatedSymlinkTarget | Should -Be 'C:\target'
  }

  It 'el modo interno elevado devuelve false cuando no fue solicitado' {
    (Invoke-InternalElevatedSymlinkMode) | Should -Be $false
  }

  It 'valida el repositorio antes de instalar dependencias globales' {
    $script:CliArgs = @()
    $script:MainCallOrder = [System.Collections.Generic.List[string]]::new()

    Mock Parse-Args {}
    Mock Invoke-InternalElevatedSymlinkMode { $false }
    Mock Get-RepoRoot {
      $script:MainCallOrder.Add('Get-RepoRoot')
      return 'C:\repo'
    }
    Mock Assert-ConfigPathsFileExists {
      $script:MainCallOrder.Add('Assert-ConfigPathsFileExists')
    }
    Mock Ensure-DotfilerDependencies {
      $script:MainCallOrder.Add('Ensure-DotfilerDependencies')
    }
    Mock Resolve-Operations { throw 'stop-after-order-check' }
    Mock Print-Summary {}
    Mock Print-Diagnostics {}

    { Main } | Should -Throw 'stop-after-order-check'

    $script:MainCallOrder | Should -Be @('Get-RepoRoot', 'Assert-ConfigPathsFileExists', 'Ensure-DotfilerDependencies')
  }
}

