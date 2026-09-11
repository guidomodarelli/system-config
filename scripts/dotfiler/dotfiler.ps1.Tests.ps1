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
    $script:ElevatedSymlinkHardLink = $false
    $script:PendingElevatedSymlinks = [System.Collections.Generic.List[object]]::new()
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

  It 'New-DotfileSymlink crea hard link usando el tipo correspondiente' {
    Mock Test-IsSymlink { $false }
    Mock Test-PathEntry { $false }
    Mock Test-Path { $true }
    Mock New-Item {} -ParameterFilter { $ItemType -eq 'HardLink' }
    Mock Write-SymlinkLine {}

    New-DotfileSymlink -SourcePath 'C:\fuente.txt' -TargetPath 'C:\destino.txt' -HardLink $true

    Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter {
      $ItemType -eq 'HardLink' -and $Target -eq 'C:\fuente.txt'
    }
    $script:CountErrors | Should -Be 0
  }

  It 'New-DotfileSymlink rechaza directorios para hard links antes de mutar destino' {
    Mock Test-IsSymlink { $false }
    Mock Test-PathEntry { $false }
    Mock Test-Path {
      param([string]$LiteralPath, [string]$PathType)
      if ($PathType -eq 'Leaf') {
        return $false
      }

      return $true
    }
    Mock New-Item {}

    New-DotfileSymlink -SourcePath 'C:\carpeta' -TargetPath 'C:\destino' -HardLink $true

    $script:CountErrors | Should -Be 1
    $script:Diagnostics[0].Reason | Should -Match 'hard link'
    Should -Invoke New-Item -Times 0 -Exactly
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

  It 'acumula los enlaces cuando falla New-Item por permisos sin solicitar UAC por enlace' {

    Mock Test-IsSymlink { $false }
    Mock Test-PathEntry { $false }
    Mock Test-Path { $true }
    Mock Write-Info {}
    Mock Write-Success {}
    Mock Add-Diagnostic {}
    Mock Test-ElevationTargetAllowed { $true }
    Mock Start-Process { throw 'No debe solicitar UAC al acumular enlaces' }
    Mock New-Item {
      throw [System.UnauthorizedAccessException]::new('The required privilege is not held by the client')
    } -ParameterFilter { $ItemType -eq 'SymbolicLink' }

    New-DotfileSymlink -SourcePath 'C:\fuente' -TargetPath 'C:\destino'
    New-DotfileSymlink -SourcePath 'C:\otra fuente' -TargetPath 'C:\otro destino'

    $script:PendingElevatedSymlinks.Count | Should -Be 2
    $script:PendingElevatedSymlinks[0].Source | Should -Be 'C:\fuente'
    $script:PendingElevatedSymlinks[0].Target | Should -Be 'C:\destino'
    $script:CountErrors | Should -Be 0
    Should -Invoke Start-Process -Times 0 -Exactly
  }

  Context 'Elevacion agrupada' {
    BeforeEach {
      $script:PendingElevatedSymlinks.Add([PSCustomObject]@{ Source = 'C:\fuente'; Target = 'C:\destino' })
      $script:PendingElevatedSymlinks.Add([PSCustomObject]@{ Source = 'C:\otra fuente'; Target = 'C:\otro destino' })
      Mock Get-PowerShellExecutablePath { 'powershell.exe' }
      Mock Write-Info {}
      Mock Write-SymlinkLine {}
      Mock Write-ErrorLog {}
    }

    It 'solicita UAC una vez y conserva los errores individuales del lote' {
      Mock Start-Process {
        param($ArgumentList)
        $requestMatch = [regex]::Match($ArgumentList, '-RequestPath (?:"([^"]+)"|(\S+))')
        $resultMatch = [regex]::Match($ArgumentList, '-ResultPath (?:"([^"]+)"|(\S+))')
        $script:BatchRequestPath = ($requestMatch.Groups[1].Value + $requestMatch.Groups[2].Value)
        $script:BatchResultPath = ($resultMatch.Groups[1].Value + $resultMatch.Groups[2].Value)
        $requests = Get-Content -LiteralPath $script:BatchRequestPath -Raw | ConvertFrom-Json
        $requests.Count | Should -Be 2
        $requests[1].Source | Should -Be 'C:\otra fuente'
        @(
          @{ Success = $true; Error = $null },
          @{ Success = $false; Error = 'Destino ocupado' }
        ) | ConvertTo-Json | Set-Content -LiteralPath $script:BatchResultPath
        [PSCustomObject]@{ ExitCode = 0 }
      }

      Complete-PendingElevatedSymlinks
      Complete-PendingElevatedSymlinks

      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $Verb -eq 'RunAs' -and $Wait -and $WindowStyle -eq 'Hidden' }
      Should -Invoke Write-SymlinkLine -Times 1 -Exactly
      $script:CountErrors | Should -Be 1
      $script:Diagnostics[0].Target | Should -Be 'C:\otro destino'
      Test-Path -LiteralPath $script:BatchRequestPath | Should -BeFalse
      Test-Path -LiteralPath $script:BatchResultPath | Should -BeFalse
    }

    It 'registra todos los pendientes y no vuelve a preguntar cuando se cancela UAC' {
      Mock Start-Process { throw 'El usuario cancelo la solicitud' }

      Complete-PendingElevatedSymlinks
      Complete-PendingElevatedSymlinks

      Should -Invoke Start-Process -Times 1 -Exactly
      $script:CountErrors | Should -Be 2
      $script:Diagnostics.Count | Should -Be 2
    }

    It 'no solicita elevacion durante una simulacion' {
      $script:DryRun = $true
      Mock Start-Process {}

      Complete-PendingElevatedSymlinks

      Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'registra todos los pendientes cuando el proceso elevado falla' {
      Mock Start-Process { [PSCustomObject]@{ ExitCode = 1 } }

      Complete-PendingElevatedSymlinks

      $script:CountErrors | Should -Be 2
      $script:PendingElevatedSymlinks.Count | Should -Be 0
    }

    It 'registra errores si el proceso no devuelve resultados completos' {
      Mock Start-Process { [PSCustomObject]@{ ExitCode = 0 } }

      Complete-PendingElevatedSymlinks

      $script:CountErrors | Should -Be 2
    }

    It 'el worker continua despues de un error y devuelve el resultado de cada enlace' {
      $requestPath = Join-Path $TestDrive 'solicitud con espacios.json'
      $resultPath = Join-Path $TestDrive 'resultados con espacios.json'
      ConvertTo-Json -InputObject $script:PendingElevatedSymlinks.ToArray() | Set-Content -LiteralPath $requestPath
      # Se simula solo la operacion privilegiada del sistema para no abrir UAC en tests.
      Mock New-Item {
        param($Path)
        if ($Path -eq 'C:\destino') { throw 'Destino ocupado' }
      } -ParameterFilter { $ItemType -eq 'SymbolicLink' }

      & (Join-Path $PSScriptRoot 'create-symlinks-elevated.ps1') -RequestPath $requestPath -ResultPath $resultPath

      $results = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
      $results.Count | Should -Be 2
      $results[0].Success | Should -BeFalse
      $results[0].Error | Should -Be 'Destino ocupado'
      $results[1].Success | Should -BeTrue
      Should -Invoke New-Item -Times 2 -Exactly -ParameterFilter { $ItemType -eq 'SymbolicLink' -and -not $Force }
    }

    It 'el worker crea HardLink cuando la operacion lo solicita' {
      $requestPath = Join-Path $TestDrive 'hard-request.json'
      $resultPath = Join-Path $TestDrive 'hard-result.json'
      $sourcePath = Join-Path $TestDrive 'hard-source.txt'
      $targetPath = Join-Path $TestDrive 'hard-target.txt'
      Set-Content -LiteralPath $sourcePath -Value 'origen'
      ConvertTo-Json -InputObject @(@{ Source = $sourcePath; Target = $targetPath; HardLink = $true }) | Set-Content -LiteralPath $requestPath
      Mock New-Item {} -ParameterFilter { $ItemType -eq 'HardLink' }

      & (Join-Path $PSScriptRoot 'create-symlinks-elevated.ps1') -RequestPath $requestPath -ResultPath $resultPath

      $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
      $result.Success | Should -BeTrue
      Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $ItemType -eq 'HardLink' -and -not $Force }
    }

    It 'el worker preserva un archivo que aparecio en el destino' {
      $requestPath = Join-Path $TestDrive 'request.json'
      $resultPath = Join-Path $TestDrive 'result.json'
      $sourcePath = Join-Path $TestDrive 'source.txt'
      $targetPath = Join-Path $TestDrive 'existing.txt'
      Set-Content -LiteralPath $sourcePath -Value 'origen'
      Set-Content -LiteralPath $targetPath -Value 'conservar'
      ConvertTo-Json -InputObject @(@{ Source = $sourcePath; Target = $targetPath }) | Set-Content -LiteralPath $requestPath

      & (Join-Path $PSScriptRoot 'create-symlinks-elevated.ps1') -RequestPath $requestPath -ResultPath $resultPath

      $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
      $result.Success | Should -BeFalse
      Get-Content -LiteralPath $targetPath | Should -Be 'conservar'
      (Get-Item -LiteralPath $targetPath).LinkType | Should -BeNullOrEmpty
    }
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

  It 'incluye el flag interno de hard link al solicitar elevacion' {
    $processArguments = Get-ElevatedSymlinkProcessArguments `
      -ScriptPath 'C:\dotfiler.ps1' `
      -SourcePath 'C:\source.txt' `
      -TargetPath 'C:\target.txt' `
      -HardLink

    $processArguments | Should -Contain '--internal-hard-link'
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

    $operations = @(Resolve-Operations)

    $operations.Count | Should -Be 1
    $operations[0].Source | Should -Be $sourceDirectory
    $operations[0].Target | Should -Be (Join-Path -Path $script:HomeDir -ChildPath '.agents/.codex/skills/.system')
    $operations[0].Group | Should -Be (Join-Path -Path $script:HomeDir -ChildPath '.agents/.codex/skills')

    Remove-Item -LiteralPath $testRootDirectory -Recurse -Force
  }

  It 'propaga hardLink al resolver de operaciones' {
    $script:HomeDir = 'C:\Users\tester'
    $script:ConfigsDir = 'C:\repo\configs'

    Mock Get-ConfigEntries {
      @(
        [PSCustomObject]@{
          path = 'hard-source.txt'
          target = 'linked-files'
          hardLink = $true
        }
      )
    }
    Mock Get-ResolvedSources {
      @([PSCustomObject]@{ Name = 'hard-source.txt'; FullName = 'C:\repo\configs\hard-source.txt' })
    }

    $operations = @(Resolve-Operations)

    $operations.Count | Should -Be 1
    $operations[0].HardLink | Should -BeTrue
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

    $operations = @(Resolve-Operations)

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

    $operations = @(Resolve-Operations)

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

    $operations = @(Resolve-Operations)

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

    $operations = @(Resolve-Operations)

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

    $operations = @(Resolve-Operations)

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

    $operations = @(Resolve-Operations)

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
      '--internal-target', 'C:\target',
      '--internal-hard-link'
    )

    $script:DryRun | Should -Be $true
    $script:UseColor | Should -Be $false
    $script:UseIcons | Should -Be $false
    $script:VerboseMode | Should -Be $true
    $script:Quiet | Should -Be $true
    $script:IsElevatedSymlinkMode | Should -Be $true
    $script:ElevatedSymlinkSource | Should -Be 'C:\source'
    $script:ElevatedSymlinkTarget | Should -Be 'C:\target'
    $script:ElevatedSymlinkHardLink | Should -BeTrue
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

  Context 'Filtros descendInto / markerFile / exclude' {
    BeforeEach {
      $script:FilterRoot = Join-Path -Path $TestDrive -ChildPath ("filters-{0}" -f ([guid]::NewGuid().ToString('N')))
      New-Item -ItemType Directory -Path $script:FilterRoot -Force | Out-Null

      $script:OriginalConfigsDir = $script:ConfigsDir
      $script:ConfigsDir = $script:FilterRoot

      $treeRoot = Join-Path -Path $script:FilterRoot -ChildPath 'skills-tree'
      New-Item -ItemType Directory -Path $treeRoot -Force | Out-Null

      foreach ($leaf in @('leaf-a', 'leaf-b', 'no-marker')) {
        $leafPath = Join-Path -Path $treeRoot -ChildPath $leaf
        New-Item -ItemType Directory -Path $leafPath -Force | Out-Null
        if ($leaf -ne 'no-marker') {
          New-Item -ItemType File -Path (Join-Path -Path $leafPath -ChildPath 'SKILL.md') -Value 'x' -Force | Out-Null
        }
      }

      $group1 = Join-Path -Path $treeRoot -ChildPath '(group1)'
      New-Item -ItemType Directory -Path $group1 -Force | Out-Null
      $innerLeaf = Join-Path -Path $group1 -ChildPath 'inner-leaf'
      New-Item -ItemType Directory -Path $innerLeaf -Force | Out-Null
      New-Item -ItemType File -Path (Join-Path -Path $innerLeaf -ChildPath 'SKILL.md') -Value 'x' -Force | Out-Null

      $deep = Join-Path -Path $group1 -ChildPath '(deep)'
      New-Item -ItemType Directory -Path $deep -Force | Out-Null
      $veryDeep = Join-Path -Path $deep -ChildPath 'very-deep'
      New-Item -ItemType Directory -Path $veryDeep -Force | Out-Null
      New-Item -ItemType File -Path (Join-Path -Path $veryDeep -ChildPath 'SKILL.md') -Value 'x' -Force | Out-Null

      $dist = Join-Path -Path $treeRoot -ChildPath 'dist'
      New-Item -ItemType Directory -Path $dist -Force | Out-Null
      $distInner = Join-Path -Path $dist -ChildPath 'anything'
      New-Item -ItemType Directory -Path $distInner -Force | Out-Null
      New-Item -ItemType File -Path (Join-Path -Path $distInner -ChildPath 'SKILL.md') -Value 'x' -Force | Out-Null

      New-Item -ItemType File -Path (Join-Path -Path $treeRoot -ChildPath 'file.txt') -Value 'top' -Force | Out-Null
      New-Item -ItemType File -Path (Join-Path -Path $treeRoot -ChildPath 'excluded.tmp') -Value 'tmp' -Force | Out-Null
    }

    AfterEach {
      $script:ConfigsDir = $script:OriginalConfigsDir
      if (Test-Path -LiteralPath $script:FilterRoot) {
        Remove-Item -LiteralPath $script:FilterRoot -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'ConvertTo-StrippedRegexPattern stripea slashes decorativos' {
      $regex = ConvertTo-StrippedRegexPattern -Pattern '/^foo$/'
      $regex.ToString() | Should -Be '^foo$'
      $regex.IsMatch('foo') | Should -BeTrue
      $regex.IsMatch('foobar') | Should -BeFalse
    }

    It 'ConvertTo-StrippedRegexPattern acepta pattern sin slashes' {
      $regex = ConvertTo-StrippedRegexPattern -Pattern '^foo$'
      $regex.IsMatch('foo') | Should -BeTrue
    }

    It 'ConvertTo-StrippedRegexPattern lanza con regex invalido' {
      { ConvertTo-StrippedRegexPattern -Pattern '/[/' } | Should -Throw '*regex invalido*'
    }

    It 'Test-LeafHasMarkerFile retorna true sin marker definido' {
      Test-LeafHasMarkerFile -Path $script:FilterRoot -MarkerFile $null | Should -BeTrue
      Test-LeafHasMarkerFile -Path $script:FilterRoot -MarkerFile '' | Should -BeTrue
    }

    It 'Test-LeafHasMarkerFile valida presencia del archivo en la carpeta' {
      $leafA = Join-Path $script:FilterRoot 'skills-tree/leaf-a'
      Test-LeafHasMarkerFile -Path $leafA -MarkerFile 'SKILL.md' | Should -BeTrue
      $noMarker = Join-Path $script:FilterRoot 'skills-tree/no-marker'
      Test-LeafHasMarkerFile -Path $noMarker -MarkerFile 'SKILL.md' | Should -BeFalse
    }

    It 'Get-ResolvedSources sin filtros enlaza todos los hijos top-level' {
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'leaf-b'
      $names | Should -Contain 'no-marker'
      $names | Should -Contain '(group1)'
      $names | Should -Contain 'dist'
      $names | Should -Contain 'file.txt'
    }

    It 'Get-ResolvedSources con exclude descarta basenames matcheados' {
      $excludeRegex = ConvertTo-StrippedRegexPattern -Pattern '/^(dist|excluded\.tmp)$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -ExcludeRegex $excludeRegex
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Not -Contain 'dist'
      $names | Should -Not -Contain 'excluded.tmp'
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'file.txt'
    }

    It 'Get-ResolvedSources con markerFile filtra folders sin el archivo' {
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -MarkerFile 'SKILL.md'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Not -Contain 'no-marker'
      # archivos top-level pasan porque markerFile no aplica
      $names | Should -Contain 'file.txt'
    }

    It 'Get-ResolvedSources con descendInto recursivo aplana hojas anidadas' {
      $descend = ConvertTo-StrippedRegexPattern -Pattern '/^\(.*\)$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -DescendIntoRegex $descend -MarkerFile 'SKILL.md'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'leaf-b'
      $names | Should -Contain 'inner-leaf'
      $names | Should -Contain 'very-deep'
      $names | Should -Not -Contain '(group1)'
      $names | Should -Not -Contain '(deep)'
      $names | Should -Not -Contain 'no-marker'
    }

    It 'Get-ResolvedSources con exclude profundo evita descender en subtree' {
      $descend = ConvertTo-StrippedRegexPattern -Pattern '/^\(.*\)$/'
      $excludeRegex = ConvertTo-StrippedRegexPattern -Pattern '/^dist$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -DescendIntoRegex $descend -ExcludeRegex $excludeRegex -MarkerFile 'SKILL.md'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Not -Contain 'anything'
      $names | Should -Not -Contain 'dist'
    }

    It 'Combinacion (-,markerFile,exclude): filtra ambos en top-level' {
      $excludeRegex = ConvertTo-StrippedRegexPattern -Pattern '/^dist$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -ExcludeRegex $excludeRegex -MarkerFile 'SKILL.md'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'leaf-b'
      $names | Should -Not -Contain 'dist'
      $names | Should -Not -Contain 'no-marker'
      $names | Should -Contain 'file.txt'
      $names | Should -Contain 'excluded.tmp'
    }

    It 'Combinacion (descendInto,-,-): solo descendInto trata no-matches como hojas' {
      $descend = ConvertTo-StrippedRegexPattern -Pattern '/^\(.*\)$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -DescendIntoRegex $descend
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'no-marker'
      $names | Should -Contain 'dist'
      $names | Should -Contain 'file.txt'
      $names | Should -Not -Contain '(group1)'
      $names | Should -Contain 'inner-leaf'
    }

    It 'Combinacion (descendInto,-,exclude): poda subtrees sin requerir marker' {
      $descend = ConvertTo-StrippedRegexPattern -Pattern '/^\(.*\)$/'
      $excludeRegex = ConvertTo-StrippedRegexPattern -Pattern '/^(dist|no-marker)$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -DescendIntoRegex $descend -ExcludeRegex $excludeRegex
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'leaf-b'
      $names | Should -Contain 'inner-leaf'
      $names | Should -Not -Contain 'no-marker'
      $names | Should -Not -Contain 'dist'
    }

    It 'Combinacion (-,-,-): sin ningun filtro produce el comportamiento del glob original' {
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'leaf-a'
      $names | Should -Contain 'leaf-b'
      $names | Should -Contain 'no-marker'
      $names | Should -Contain '(group1)'
      $names | Should -Contain 'dist'
      $names | Should -Contain 'file.txt'
      $names | Should -Contain 'excluded.tmp'
      $names | Should -Not -Contain 'inner-leaf'
    }

    It 'Get-ResolvedSources con descendInto enlaza archivos sueltos del agrupador' {
      $files = Join-Path $script:FilterRoot 'skills-tree/(group1)/utility.js'
      New-Item -ItemType File -Path $files -Value 'js' -Force | Out-Null

      $descend = ConvertTo-StrippedRegexPattern -Pattern '/^\(.*\)$/'
      $sources = Get-ResolvedSources -OriginalPath 'skills-tree/*' -DescendIntoRegex $descend -MarkerFile 'SKILL.md'
      $names = @($sources | ForEach-Object { $_.Name })
      $names | Should -Contain 'utility.js'
    }

    It 'Test-PathEndsWithGlobStar detecta paths terminados con /* o \*' {
      Test-PathEndsWithGlobStar -Path 'foo/*' | Should -BeTrue
      Test-PathEndsWithGlobStar -Path 'foo\*' | Should -BeTrue
      Test-PathEndsWithGlobStar -Path 'foo' | Should -BeFalse
      Test-PathEndsWithGlobStar -Path 'foo/*/bar' | Should -BeFalse
      Test-PathEndsWithGlobStar -Path '' | Should -BeFalse
    }

    It 'Get-DescendIntoRegex retorna null si el campo no existe' {
      $entry = [PSCustomObject]@{ path = 'foo/*'; target = 'bar' }
      Get-DescendIntoRegex -Entry $entry | Should -BeNullOrEmpty
    }

    It 'Get-DescendIntoRegex compila el regex stripeando slashes' {
      $entry = [PSCustomObject]@{ descendInto = '/^\(.*\)$/' }
      $regex = Get-DescendIntoRegex -Entry $entry
      $regex | Should -Not -BeNullOrEmpty
      $regex.IsMatch('(javascript)') | Should -BeTrue
      $regex.IsMatch('plain') | Should -BeFalse
    }

    It 'Get-MarkerFileName retorna null si el campo no existe' {
      $entry = [PSCustomObject]@{ path = 'foo/*' }
      Get-MarkerFileName -Entry $entry | Should -BeNullOrEmpty
    }

    It 'Get-MarkerFileName retorna el nombre cuando esta presente' {
      $entry = [PSCustomObject]@{ markerFile = 'SKILL.md' }
      Get-MarkerFileName -Entry $entry | Should -Be 'SKILL.md'
    }
  }
}
