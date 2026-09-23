Describe 'setup.ps1' {
  BeforeAll {
    Set-StrictMode -Version Latest

    # setup.ps1 ejecuta el menú al final, así que no se dot-sourcea completo: se cargan
    # solo sus funciones en el scope del test.
    $script:SetupScriptPath = Join-Path $PSScriptRoot 'setup.ps1'
    $tokens = $null
    $parseErrors = $null
    $setupScriptAst = [System.Management.Automation.Language.Parser]::ParseFile($script:SetupScriptPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
      throw "setup.ps1 has parse errors: $($parseErrors.Message -join '; ')"
    }

    $functionDefinitions = $setupScriptAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
      }, $true)
    foreach ($functionDefinition in $functionDefinitions) {
      . ([scriptblock]::Create($functionDefinition.Extent.Text))
    }

    # Bordes externos (CLIs nativos). Existen como funciones para que Mock pueda
    # reemplazarlos aunque la herramienta no esté instalada donde corren los tests.
    function winget { }
    function scoop { }
    function fnm { }
    function npm { }
    function pythonTestExecutable { }

    # Get-FilteredSetupMenuIndexes devuelve el array envuelto (return ,$indexes); se desenvuelve acá.
    function ConvertTo-TestArray {
      param([object]$Value)
      if ($null -eq $Value) { return @() }
      $values = @($Value)
      if ($values.Count -eq 1 -and $values[0] -is [array]) { return @($values[0]) }
      return $values
    }

    function New-TestSetupMenuCatalog {
      return @(
        [PSCustomObject]@{ Id = 'git'; Label = 'Git'; FunctionName = 'Install-Git'; DefaultSelected = $true; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false },
        [PSCustomObject]@{ Id = 'powertoys'; Label = 'PowerToys'; FunctionName = 'Install-PowerToys'; DefaultSelected = $false; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false }
      )
    }

    function New-TestMenuItem {
      param(
        [string]$Id = 'git',
        [string]$FunctionName = 'Install-Git',
        [bool]$DefaultSelected = $true,
        [string]$Platforms = 'windows'
      )
      return [PSCustomObject]@{ Id = $Id; Label = $Id; FunctionName = $FunctionName; DefaultSelected = $DefaultSelected; RequiresAdmin = $false; Platforms = $Platforms; RequiresRestart = $false }
    }

    $script:SharedCatalogPath = Join-Path $PSScriptRoot 'setup.catalog.csv'
    $script:SharedMenuCatalog = Get-SetupMenuCatalog -CatalogPath $script:SharedCatalogPath
  }

  AfterEach {
    $global:LASTEXITCODE = 0
  }

  Context 'catálogo compartido' {
    It 'pasa la validación del catálogo de PowerShell' {
      { Test-SetupMenuCatalog -menuCatalog $script:SharedMenuCatalog } | Should -Not -Throw
    }

    It 'carga ids, etiquetas y metadata del catálogo compartido' {
      $firstMenuItem = $script:SharedMenuCatalog[0]

      $firstMenuItem.Label | Should -Be 'Chocolatey'
      $firstMenuItem.Id | Should -Be 'chocolatey'
      $firstMenuItem.RequiresAdmin | Should -BeTrue
      $firstMenuItem.Platforms | Should -Be 'windows'
      $firstMenuItem.RequiresRestart | Should -BeFalse
    }

    It 'la allowlist incluye <FunctionName>' -ForEach @(
      @{ FunctionName = 'Install-Git' }
      @{ FunctionName = 'Install-Gh' }
      @{ FunctionName = 'Install-Bat' }
      @{ FunctionName = 'Install-Hunk' }
      @{ FunctionName = 'Install-McpRemoteProxy' }
      @{ FunctionName = 'Install-Ghostty' }
    ) {
      Test-SetupFunctionAllowed -menuCatalog $script:SharedMenuCatalog -FunctionName $FunctionName | Should -BeTrue
    }

    It 'la allowlist rechaza funciones fuera de los instaladores' {
      Test-SetupFunctionAllowed -menuCatalog $script:SharedMenuCatalog -FunctionName 'Get-ChildItem' | Should -BeFalse
    }

    It 'incluye <Id> sin requerir administrador' -ForEach @(
      @{ Id = 'git' }
      @{ Id = 'curl' }
      @{ Id = 'vscode' }
      @{ Id = 'gh' }
      @{ Id = 'hunk' }
    ) {
      $menuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $script:SharedMenuCatalog -ItemIdentifier $Id

      $menuIndex | Should -BeGreaterOrEqual 0
      $script:SharedMenuCatalog[$menuIndex].RequiresAdmin | Should -BeFalse
    }

    It 'incluye bat del catálogo anterior de PowerShell' {
      Find-SetupMenuCatalogItemIndex -menuCatalog $script:SharedMenuCatalog -ItemIdentifier 'bat' | Should -BeGreaterOrEqual 0
    }

    It 'busca ítems por id o por nombre de función' {
      Find-SetupMenuCatalogItemIndex -menuCatalog $script:SharedMenuCatalog -ItemIdentifier 'chocolatey' | Should -Be 0
      Find-SetupMenuCatalogItemIndex -menuCatalog $script:SharedMenuCatalog -ItemIdentifier 'Install-Choco' | Should -Be 0
    }

    It 'detecta ítems seleccionados que requieren administrador' {
      Test-SetupMenuIndexesRequireAdmin -menuCatalog $script:SharedMenuCatalog -selectedIndexes @(0) | Should -BeTrue
    }

    It 'instala mcp-remote-proxy después de Python en Windows' {
      $pythonMenuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $script:SharedMenuCatalog -ItemIdentifier 'python'
      $mcpRemoteProxyMenuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $script:SharedMenuCatalog -ItemIdentifier 'mcp_remote_proxy'

      $mcpRemoteProxyMenuIndex | Should -BeGreaterThan $pythonMenuIndex
    }

    It 'rechaza catálogos con encabezado distinto al común' {
      $invalidHeaderCatalogPath = Join-Path $TestDrive 'invalid-header.catalog.csv'
      Set-Content -Path $invalidHeaderCatalogPath -Value @('Id|Label|FunctionName', 'git|Git|Install-Git')

      { Get-SetupMenuCatalog -CatalogPath $invalidHeaderCatalogPath } | Should -Throw
    }

    # Los datos de -ForEach se evalúan en discovery, antes de BeforeAll: solo parámetros literales.
    It 'rechaza <Case>' -ForEach @(
      @{ Case = 'ids duplicados'; MenuItemParameters = @(@{}, @{ DefaultSelected = $false }) }
      @{ Case = 'plataformas no soportadas'; MenuItemParameters = @(@{ Platforms = 'windows,plan9' }) }
      @{ Case = 'funciones de PowerShell inexistentes'; MenuItemParameters = @(@{ Id = 'missing'; FunctionName = 'Install-MissingTool' }) }
    ) {
      $invalidMenuCatalog = @(foreach ($menuItemParameter in $MenuItemParameters) { New-TestMenuItem @menuItemParameter })

      { Test-SetupMenuCatalog -menuCatalog $invalidMenuCatalog } | Should -Throw
    }
  }

  Context 'argumentos de la CLI' {
    It 'acepta --dry-run y --yes después de los comandos y conserva sus argumentos' {
      $parsedSetupArguments = ConvertTo-SetupArguments -Arguments @('Install-Git', '--dry-run', 'fd_find', '--yes')

      $parsedSetupArguments.DryRun | Should -BeTrue
      $parsedSetupArguments.AssumeYes | Should -BeTrue
      ($parsedSetupArguments.CommandArguments -join ' ') | Should -Be 'Install-Git fd_find'
    }
  }

  Context 'instaladores remotos' {
    It 'limpia los directorios temporales de setup' {
      $temporaryDirectoryPath = New-SetupTemporaryDirectory

      Remove-SetupTemporaryDirectory -Path $temporaryDirectoryPath

      Test-Path -LiteralPath $temporaryDirectoryPath | Should -BeFalse
    }

    It 'borra la descarga temporal después de ejecutar el instalador oficial' {
      $script:DownloadedScriptPath = $null
      Mock Invoke-RestMethod {
        $script:DownloadedScriptPath = $OutFile
        Set-Content -Path $OutFile -Value '$global:LASTEXITCODE = 0'
      }

      Invoke-SetupLatestOfficialScript -Uri 'https://example.test/install.ps1' -FileName 'install.ps1'

      $script:DownloadedScriptPath | Should -Not -BeNullOrEmpty
      Test-Path -LiteralPath (Split-Path -Path $script:DownloadedScriptPath -Parent) | Should -BeFalse
    }
  }

  Context 'Install-WingetPackage' {
    It 'actualiza paquetes ya instalados a la última versión estable' {
      Mock winget { $global:LASTEXITCODE = 0 }

      Install-WingetPackage -appIds @('Example.Tool')

      Should -Invoke winget -ParameterFilter { ($args -join ' ') -like 'upgrade --exact --id Example.Tool*' }
    }

    It 'reintenta con install idempotente cuando upgrade falla' {
      Mock winget { $global:LASTEXITCODE = 0 }
      Mock winget { $global:LASTEXITCODE = -42 } -ParameterFilter { ($args -join ' ') -like 'upgrade --exact --id Recover.Tool*' }

      Install-WingetPackage -appIds @('Recover.Tool')

      Should -Invoke winget -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -like 'upgrade --exact --id Recover.Tool*' }
      Should -Invoke winget -ParameterFilter { ($args -join ' ') -like 'install --exact --id Recover.Tool*' }
    }

    It 'trata como no fatales los códigos de winget "sin actualización" y "ya instalado"' {
      Test-WingetIdempotentSuccessExitCode -ExitCode -1978335189 | Should -BeTrue
      Test-WingetIdempotentSuccessExitCode -ExitCode -1978334964 | Should -BeTrue
    }

    It 'resetea LASTEXITCODE cuando la recuperación responde "ya instalado"' {
      Mock winget { $global:LASTEXITCODE = 0 }
      Mock winget { $global:LASTEXITCODE = -42 } -ParameterFilter { ($args -join ' ') -like 'upgrade --exact --id Installed.Tool*' }
      Mock winget { $global:LASTEXITCODE = -1978334964 } -ParameterFilter { ($args -join ' ') -like 'install --exact --id Installed.Tool*' }

      Install-WingetPackage -appIds @('Installed.Tool')

      Should -Invoke winget -ParameterFilter { ($args -join ' ') -like 'upgrade --exact --id Installed.Tool*' }
      Should -Invoke winget -ParameterFilter { ($args -join ' ') -like 'install --exact --id Installed.Tool*' }
      $global:LASTEXITCODE | Should -Be 0
    }

    It 'instala paquetes ausentes y acepta "sin actualización" como éxito' {
      Mock Test-WingetPackageInstalled { $false }
      Mock winget { $global:LASTEXITCODE = -1978335189 } -ParameterFilter { ($args -join ' ') -like 'install --exact --id Already.Latest.Tool*' }

      Install-WingetPackage -appIds @('Already.Latest.Tool')

      Should -Invoke winget -ParameterFilter { ($args -join ' ') -like 'install --exact --id Already.Latest.Tool*' }
      $global:LASTEXITCODE | Should -Be 0
    }

    It 'Install-PowerShell instala el MSI oficial en vez del paquete MSIX' {
      Mock Test-WingetPackageInstalled { $false }
      Mock winget { $global:LASTEXITCODE = 0 }

      Install-PowerShell

      Should -Invoke winget -Times 1 -Exactly -ParameterFilter {
        ($args -join ' ') -like 'install --exact --id Microsoft.PowerShell --installer-type wix *'
      }
    }

    It 'no fuerza tipo de instalador cuando no se pide' {
      Mock Test-WingetPackageInstalled { $false }
      Mock winget { $global:LASTEXITCODE = 0 }

      Install-WingetPackage -appIds @('Example.Tool')

      Should -Invoke winget -Times 0 -Exactly -ParameterFilter { $args -contains '--installer-type' }
    }

    It 'Install-Gh usa el id oficial de winget' {
      Mock winget { $global:LASTEXITCODE = 0 }

      Install-Gh

      Should -Invoke winget -ParameterFilter { $args -contains 'GitHub.cli' }
    }
  }

  Context 'resolución de ejecutables' {
    It 'encuentra fnm en WinGet Links aunque la sesión no haya recargado PATH' {
      $originalLocalAppData = $env:LOCALAPPDATA
      $fnmLinkPath = Join-Path $TestDrive 'Microsoft/WinGet/Links/fnm.exe'
      New-Item -ItemType Directory -Path (Split-Path -Path $fnmLinkPath -Parent) -Force | Out-Null
      New-Item -ItemType File -Path $fnmLinkPath -Force | Out-Null
      Mock Get-Command { $null }
      try {
        $env:LOCALAPPDATA = $TestDrive

        Resolve-FnmExecutable | Should -Be $fnmLinkPath
      } finally {
        $env:LOCALAPPDATA = $originalLocalAppData
      }
    }

    It 'prefiere el shim npm.cmd cuando PowerShell resuelve npm.ps1' {
      $npmPowerShellShimPath = Join-Path $TestDrive 'npm.ps1'
      $npmCommandShimPath = Join-Path $TestDrive 'npm.cmd'
      New-Item -ItemType File -Path $npmPowerShellShimPath, $npmCommandShimPath -Force | Out-Null
      Mock Get-Command {
        [PSCustomObject]@{ Source = $npmPowerShellShimPath; CommandType = [System.Management.Automation.CommandTypes]::ExternalScript }
      } -ParameterFilter { $Name -eq 'npm' }

      Resolve-NpmExecutable | Should -Be $npmCommandShimPath
    }
  }

  Context 'Install-Hunk' {
    BeforeEach {
      $script:NpmAvailableInCurrentSession = $false
      Mock Get-Command { $null }
      # CommandType replica la forma real de Get-Command, que Resolve-NpmExecutable inspecciona.
      Mock Get-Command {
        [PSCustomObject]@{ Source = 'npm'; CommandType = [System.Management.Automation.CommandTypes]::Application }
      } -ParameterFilter { $Name -eq 'npm' -and $script:NpmAvailableInCurrentSession }
      Mock Get-Command {
        [PSCustomObject]@{ Source = 'fnm'; CommandType = [System.Management.Automation.CommandTypes]::Application }
      } -ParameterFilter { $Name -eq 'fnm' }
      Mock Install-fnm { $global:LASTEXITCODE = 0 }
      Mock fnm { $global:LASTEXITCODE = 0 }
      Mock fnm {
        $script:NpmAvailableInCurrentSession = $true
        $global:LASTEXITCODE = 0
      } -ParameterFilter { ($args -join ' ') -eq 'default latest' }
      Mock fnm {
        '$env:PATH = $env:PATH'
        $global:LASTEXITCODE = 0
      } -ParameterFilter { ($args -join ' ') -eq 'env --use-on-cd --shell powershell' }
      Mock npm { $global:LASTEXITCODE = 0 }

      Install-Hunk
    }

    It 'asegura fnm cuando npm no está disponible en la sesión' {
      Should -Invoke Install-fnm -Times 1 -Exactly
    }

    It 'instala y deja por defecto la última versión estable de Node.js con fnm' {
      Should -Invoke fnm -ParameterFilter { ($args -join ' ') -eq 'install latest' }
      Should -Invoke fnm -ParameterFilter { ($args -join ' ') -eq 'default latest' }
    }

    It 'activa fnm en la misma sesión de PowerShell' {
      Should -Invoke fnm -ParameterFilter { ($args -join ' ') -eq 'env --use-on-cd --shell powershell' }
    }

    It 'instala el paquete npm hunkdiff' {
      Should -Invoke npm -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'i -g hunkdiff' }
    }
  }

  Context 'Install-ScoopPackage' {
    BeforeEach {
      $script:OriginalUserProfile = $env:USERPROFILE
      $env:USERPROFILE = $TestDrive
      Mock Install-Scoop { $global:LASTEXITCODE = 0 }
      Mock scoop { $global:LASTEXITCODE = 0 }
    }

    AfterEach {
      $env:USERPROFILE = $script:OriginalUserProfile
      Remove-Item -LiteralPath (Join-Path $TestDrive 'scoop') -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'asegura Scoop e instala paquetes ausentes' {
      Install-ScoopPackage -packages @('ripgrep')

      Should -Invoke Install-Scoop -Times 1 -Exactly
      Should -Invoke scoop -ParameterFilter { ($args -join ' ') -eq 'install ripgrep' }
    }

    It 'actualiza paquetes ya presentes' {
      New-Item -ItemType Directory -Path (Join-Path $TestDrive 'scoop/apps/ripgrep/current') -Force | Out-Null

      Install-ScoopPackage -packages @('ripgrep')

      Should -Invoke scoop -ParameterFilter { ($args -join ' ') -eq 'update ripgrep' }
    }

    It 'Install-RipGrep usa el paquete de Scoop' {
      Install-RipGrep

      Should -Invoke scoop -ParameterFilter { ($args -join ' ') -eq 'install ripgrep' }
    }
  }

  Context 'Install-Pester' {
    BeforeEach {
      Mock Get-InstalledModule { [PSCustomObject]@{ Version = [Version]'5.5.0' } }
      Mock Find-Module { [PSCustomObject]@{ Version = [Version]'6.2.0' } }
      Mock Install-Module { }

      Install-Pester
    }

    It 'busca la última versión estable en PSGallery' {
      Should -Invoke Find-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'Pester' -and $Repository -eq 'PSGallery' }
    }

    It 'instala la última versión estable, incluida la rama 6.x' {
      Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'Pester' -and $RequiredVersion -eq [Version]'6.2.0' }
    }

    It 'puede reemplazar el Pester 3.4.0 firmado que trae Windows PowerShell' {
      Should -Invoke Install-Module -ParameterFilter { $SkipPublisherCheck.IsPresent }
    }
  }

  Context 'Install-McpRemoteProxy' {
    It 'usa pip de usuario con el mismo índice que setup.sh' {
      Mock Resolve-PythonExecutable { 'pythonTestExecutable' }
      Mock pythonTestExecutable { $global:LASTEXITCODE = 0 }

      Install-McpRemoteProxy

      Should -Invoke pythonTestExecutable -Times 1 -Exactly -ParameterFilter {
        ($args -join ' ') -eq '-m pip install --user --upgrade --index-url https://pypi.artifacts.furycloud.io/simple/ mcp-remote-proxy'
      }
    }

    It 'falla con contexto cuando pip falla' {
      Mock Resolve-PythonExecutable { 'pythonTestExecutable' }
      Mock pythonTestExecutable { $global:LASTEXITCODE = 1 }

      { Install-McpRemoteProxy } | Should -Throw -ExpectedMessage '*mcp-remote-proxy*'
    }

    It 'explica que falta Python cuando no está en PATH' {
      Mock Resolve-PythonExecutable { $null }

      { Install-McpRemoteProxy } | Should -Throw -ExpectedMessage '*Python*'
    }
  }

  Context 'Install-Ghostty' {
    It 'muestra un aviso con el enlace de descarga en vez de instalar' {
      Mock LogWarning { }

      Install-Ghostty

      Should -Invoke LogWarning -Times 1 -Exactly -ParameterFilter { $message -like '*https://ghostty.org/download*' }
    }
  }

  Context 'Install-Espanso' {
    BeforeEach {
      Mock Install-WingetPackage { $global:LASTEXITCODE = 0 }
      Mock _espanso { $global:LASTEXITCODE = 0 }
      Mock _espanso { $global:LASTEXITCODE = 3 } -ParameterFilter { ($args -join ' ') -eq 'start' }

      Install-Espanso
    }

    It 'instala o actualiza el paquete oficial de winget' {
      Should -Invoke Install-WingetPackage -ParameterFilter { $appIds -contains 'Espanso.Espanso' }
    }

    It 'registra e inicia el servicio' {
      Should -Invoke _espanso -ParameterFilter { ($args -join ' ') -eq 'service register' }
      Should -Invoke _espanso -ParameterFilter { ($args -join ' ') -eq 'start' }
    }

    It 'trata "ya en ejecución" como no fatal y resetea LASTEXITCODE' {
      Test-EspansoAlreadyRunningExitCode -ExitCode 3 | Should -BeTrue
      $global:LASTEXITCODE | Should -Be 0
    }
  }

  Context 'resultados de ejecución' {
    It 'detecta resultados fallidos' {
      $failedSetupResults = @(
        [PSCustomObject]@{ Label = 'Git'; Status = 'OK'; Detail = ''; RequiresRestart = $false },
        [PSCustomObject]@{ Label = 'PowerToys'; Status = 'Falló'; Detail = 'winget error'; RequiresRestart = $false }
      )

      Test-SetupExecutionResultsHaveFailures -results $failedSetupResults | Should -BeTrue
    }

    It 'no mezcla la salida estándar del instalador con los resultados' {
      function Install-TestOutputPackage {
        Write-Output 'external installer output'
        $global:LASTEXITCODE = 0
      }
      $outputMenuCatalog = @(
        [PSCustomObject]@{ Id = 'output'; Label = 'Output package'; FunctionName = 'Install-TestOutputPackage'; DefaultSelected = $false; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false }
      )

      $outputPackageResults = @(Invoke-SelectedSetupMenuItems -menuCatalog $outputMenuCatalog -selectedIndexes @(0))

      $outputPackageResults | Should -HaveCount 1
      $outputPackageResults[0].Status | Should -Be 'OK'
      Test-SetupExecutionResultsHaveFailures -results $outputPackageResults | Should -BeFalse
    }

    It 'no falla con resultados exitosos, dry-run u omitidos' {
      $nonFailedSetupResults = @(
        [PSCustomObject]@{ Label = 'Git'; Status = 'OK'; Detail = ''; RequiresRestart = $false },
        [PSCustomObject]@{ Label = 'PowerToys'; Status = 'Dry-run'; Detail = 'No ejecutado'; RequiresRestart = $false },
        [PSCustomObject]@{ Label = 'VLC'; Status = 'Omitido'; Detail = 'Plataforma no soportada'; RequiresRestart = $false }
      )

      Test-SetupExecutionResultsHaveFailures -results $nonFailedSetupResults | Should -BeFalse
    }

    It 'el resumen de fallos incluye la etiqueta y omite paréntesis vacíos' {
      $emptyDetailSummaryMessage = Get-SetupFailureSummaryMessage -Label 'SinDetalle' -Detail ''

      $emptyDetailSummaryMessage | Should -BeLike '*SinDetalle:*'
      $emptyDetailSummaryMessage | Should -Not -BeLike '*()*'
    }

    It 'el resumen de fallos incluye el detalle cuando existe' {
      Get-SetupFailureSummaryMessage -Label 'ConDetalle' -Detail 'boom' | Should -BeLike '*(boom)*'
    }

    It 'formatea duraciones cortas en segundos y largas en minutos' {
      Format-SetupDuration -TotalSeconds 45 | Should -Be '45s'
      Format-SetupDuration -TotalSeconds 125 | Should -Be '2m 05s'
    }
  }

  Context 'búsqueda y selección del menú' {
    BeforeEach {
      $script:MenuCatalog = New-TestSetupMenuCatalog
    }

    It 'la búsqueda trata comodines como texto literal' {
      @(ConvertTo-TestArray -Value (Get-FilteredSetupMenuIndexes -menuCatalog $script:MenuCatalog -query '[')) | Should -HaveCount 0
      @(ConvertTo-TestArray -Value (Get-FilteredSetupMenuIndexes -menuCatalog $script:MenuCatalog -query '*')) | Should -HaveCount 0
    }

    It 'la búsqueda no distingue mayúsculas y devuelve el índice' {
      $caseInsensitiveMatches = @(ConvertTo-TestArray -Value (Get-FilteredSetupMenuIndexes -menuCatalog $script:MenuCatalog -query 'git'))

      $caseInsensitiveMatches | Should -HaveCount 1
      $caseInsensitiveMatches[0] | Should -Be 0
    }

    It 'find devuelve la siguiente coincidencia literal' {
      Find-SetupMenuItemIndex -menuCatalog $script:MenuCatalog -query 'toy' -startIndex 0 | Should -Be 1
    }

    It 'find mantiene el cursor cuando no hay coincidencia' {
      Find-SetupMenuItemIndex -menuCatalog $script:MenuCatalog -query '[' -startIndex 0 | Should -Be 0
    }

    It 'espacio alterna solo el ítem bajo el cursor cuando todo está seleccionado' {
      $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new([int[]]@(0, 1, 2))
      $hasManualSelection = $true

      Update-SetupMenuSelectionForToggle -selectedIndexes $selectedIndexes -cursorIndex 1 -HasManualSelection ([ref]$hasManualSelection)

      @(Get-SetupSelectedIndexArray -selectedIndexes $selectedIndexes) | Should -HaveCount 2
      $selectedIndexes.Contains(1) | Should -BeFalse
      $selectedIndexes.Contains(0) | Should -BeTrue
      $selectedIndexes.Contains(2) | Should -BeTrue
    }

    It 'espacio alterna solo el cursor y marca la selección como manual' {
      $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new([int[]]@(0, 1))
      $hasManualSelection = $false

      Update-SetupMenuSelectionForToggle -selectedIndexes $selectedIndexes -cursorIndex 1 -HasManualSelection ([ref]$hasManualSelection)

      $selectedIndexes.Contains(1) | Should -BeFalse
      $selectedIndexes.Contains(0) | Should -BeTrue
      $hasManualSelection | Should -BeTrue
    }

    It 'el atajo a selecciona todo y luego limpia todo' {
      $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()
      $hasManualSelection = $false

      Update-SetupMenuSelectionForAll -selectedIndexes $selectedIndexes -menuItemCount 3 -HasManualSelection ([ref]$hasManualSelection)
      $selectedIndexes.Count | Should -Be 3
      $hasManualSelection | Should -BeTrue

      Update-SetupMenuSelectionForAll -selectedIndexes $selectedIndexes -menuItemCount 3 -HasManualSelection ([ref]$hasManualSelection)
      $selectedIndexes.Count | Should -Be 0
    }
  }

  Context 'render de filas del menú' {
    BeforeAll {
      $script:MenuCatalog = New-TestSetupMenuCatalog
      $script:AdminRestartItem = [PSCustomObject]@{ Id = 'wsl'; Label = 'WSL'; FunctionName = 'Install-WSL'; DefaultSelected = $true; RequiresAdmin = $true; Platforms = 'windows'; RequiresRestart = $true }
    }

    It 'una fila seleccionada muestra checkbox verde, estrella gris y colores por defecto' {
      $rowSegments = @(Get-SetupMenuRowSegments -menuItem $script:MenuCatalog[0] -IsSelected $true -IsCursor $false)

      (($rowSegments | ForEach-Object Text) -join '') | Should -Be '    [x]  * Git'
      $rowSegments[4].ForegroundColor | Should -Be ([ConsoleColor]::Green)
      $rowSegments[6].ForegroundColor | Should -Be ([ConsoleColor]::DarkGray)
      $rowSegments[3].BackgroundColor | Should -Be ([Console]::BackgroundColor)
      $rowSegments[8].ForegroundColor | Should -Be ([Console]::ForegroundColor)
    }

    It 'una fila no seleccionada atenúa checkbox y etiqueta' {
      $rowSegments = @(Get-SetupMenuRowSegments -menuItem $script:MenuCatalog[1] -IsSelected $false -IsCursor $false)

      $rowSegments[4].ForegroundColor | Should -Be ([ConsoleColor]::DarkGray)
      $rowSegments[8].ForegroundColor | Should -Be ([ConsoleColor]::DarkGray)
    }

    It 'la fila del cursor se resalta con ancho fijo sin incluir la scrollbar' {
      $rowSegments = @(Get-SetupMenuRowSegments -menuItem $script:MenuCatalog[1] -IsSelected $false -IsCursor $true)

      ((($rowSegments | ForEach-Object Text) -join '').TrimEnd()) | Should -Be '  > [ ]    PowerToys'
      $rowSegments[3].BackgroundColor | Should -Be ([ConsoleColor]::DarkGray)
      $rowSegments[-1].BackgroundColor | Should -Be ([ConsoleColor]::DarkGray)
      $rowSegments[0].BackgroundColor | Should -Be ([Console]::BackgroundColor)
      (((@($rowSegments | Select-Object -Skip 2) | ForEach-Object Text) -join '').Length) | Should -Be (Get-SetupMenuHighlightWidth)
      $rowSegments[2].ForegroundColor | Should -Be ([ConsoleColor]::Cyan)
      $rowSegments[8].ForegroundColor | Should -Be ([ConsoleColor]::Cyan)
    }

    It 'las filas empiezan con el glifo de la scrollbar' {
      $rowSegments = @(Get-SetupMenuRowSegments -menuItem $script:MenuCatalog[0] -IsSelected $true -IsCursor $false -ScrollbarGlyph '#' -ScrollbarColor Cyan)

      $rowSegments[0].Text | Should -Be '#'
      $rowSegments[0].ForegroundColor | Should -Be ([ConsoleColor]::Cyan)
    }

    It 'alinea las etiquetas de admin y reinicio después de la columna del label' {
      $taggedRowText = ((@(Get-SetupMenuRowSegments -menuItem $script:AdminRestartItem -IsSelected $true -IsCursor $false -LabelColumn 9) | ForEach-Object Text) -join '')

      $taggedRowText | Should -Be '    [x]  * WSL        # admin  ^ reinicio'
    }

    It 'la etiqueta visible incluye el marcador recomendado y los badges' {
      Get-SetupMenuDisplayLabel -menuItem $script:AdminRestartItem | Should -Be '* WSL # ^'
    }

    It 'el resaltado de búsqueda parte la etiqueta y conserva mayúsculas' {
      $highlightedSegments = @(Get-SetupMenuLabelSegments -Label 'GitHub CLI' -HighlightQuery 'hub' -ForegroundColor Gray -BackgroundColor Black)

      $highlightedSegments | Should -HaveCount 3
      $highlightedSegments[1].Text | Should -Be 'Hub'
      $highlightedSegments[1].ForegroundColor | Should -Be ([ConsoleColor]::Yellow)
    }

    It 'sin consulta o sin coincidencia la etiqueta queda en un segmento' {
      @(Get-SetupMenuLabelSegments -Label 'Git' -HighlightQuery '' -ForegroundColor Gray -BackgroundColor Black) | Should -HaveCount 1
      @(Get-SetupMenuLabelSegments -Label 'Git' -HighlightQuery 'zzz' -ForegroundColor Gray -BackgroundColor Black) | Should -HaveCount 1
    }

    It 'el resaltado de búsqueda no cambia el texto visible de la fila' {
      $searchRowText = ((@(Get-SetupMenuRowSegments -menuItem $script:MenuCatalog[0] -IsSelected $true -IsCursor $false -HighlightQuery 'gi') | ForEach-Object Text) -join '')

      $searchRowText | Should -Be '    [x]  * Git'
    }
  }

  Context 'scrollbar, layout y referencias del menú' {
    It 'la scrollbar se oculta cuando la lista entra completa' {
      (Get-SetupMenuScrollbarGlyph -RowPosition 0 -WindowStartIndex 0 -VisibleItemCount 10 -ItemCount 10).Glyph | Should -Be ' '
    }

    It 'el thumb de la scrollbar recorre de arriba hacia abajo' {
      (Get-SetupMenuScrollbarGlyph -RowPosition 0 -WindowStartIndex 0 -VisibleItemCount 5 -ItemCount 10).Glyph | Should -Be '#'
      (Get-SetupMenuScrollbarGlyph -RowPosition 4 -WindowStartIndex 0 -VisibleItemCount 5 -ItemCount 10).Glyph | Should -Be '|'
      (Get-SetupMenuScrollbarGlyph -RowPosition 4 -WindowStartIndex 5 -VisibleItemCount 5 -ItemCount 10).Glyph | Should -Be '#'
    }

    It 'calcula ítems visibles según la ventana, la cantidad y un mínimo' {
      Get-SetupMenuVisibleItemCount -itemCount 40 -WindowHeight 40 | Should -Be 20
      Get-SetupMenuVisibleItemCount -itemCount 10 -WindowHeight 40 | Should -Be 10
      Get-SetupMenuVisibleItemCount -itemCount 40 -WindowHeight 10 | Should -Be 5
    }

    It 'las referencias documentan navegación, defaults y cancelación' {
      $referenceRows = @(Get-SetupMenuReferenceRows)

      $referenceRows[0].Shortcut | Should -Be 'Arriba/Abajo/j/k'
      $referenceRows[0].ShortcutColor | Should -Be ([ConsoleColor]::DarkCyan)
      @($referenceRows | Where-Object { $_.Description -eq 'restaurar defaults' })[0].Shortcut | Should -Be 'd'
      $referenceRows[-1].Shortcut | Should -Be 'q/ESC/Ctrl+C/D'
      Get-SetupMenuReferenceFrameColor | Should -Be ([ConsoleColor]::DarkGray)
    }

    It 'los detalles describen el ítem bajo el cursor' {
      $menuCatalog = New-TestSetupMenuCatalog

      Get-SetupMenuDetailsText -menuItem $menuCatalog[0] | Should -Be '  - git - Install-Git - windows - * recomendado'
      Get-SetupMenuDetailsText -menuItem $menuCatalog[1] | Should -Be '  - powertoys - Install-PowerToys - windows - opcional'
    }

    It 'calcula líneas renderizadas y offsets de filas' {
      $renderedLineCount = Get-ClassicSetupMenuRenderedLineCount -visibleItemCount 24

      $renderedLineCount | Should -Be 30
      Get-ClassicSetupMenuItemRowOffset -menuIndex 10 -windowStartIndex 10 | Should -Be 4
      Get-ClassicSetupMenuItemRowOffset -menuIndex 12 -windowStartIndex 10 | Should -Be 6
      ($renderedLineCount - 2) | Should -Be 28
    }

    It 'cambiar la cantidad de ítems visibles fuerza un render completo' {
      Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 0 -previousVisibleItemCount 5 -visibleItemCount 6 -ForceFullRender $false | Should -BeTrue
    }
  }

  Context 'lectura de teclas con input VT' {
    BeforeAll {
      function New-TestConsoleKey {
        param(
          [int]$KeyCharCode,
          [ConsoleKey]$Key = [ConsoleKey]::None,
          [switch]$Control
        )
        return [ConsoleKeyInfo]::new([char]$KeyCharCode, $Key, $false, $false, [bool]$Control)
      }

      # Simula el buffer de la consola: cada lectura consume la próxima tecla pendiente.
      function Set-TestConsoleInput {
        param([ConsoleKeyInfo[]]$Keys)
        $script:PendingConsoleKeys = [System.Collections.Generic.Queue[ConsoleKeyInfo]]::new()
        foreach ($pendingKey in $Keys) { $script:PendingConsoleKeys.Enqueue($pendingKey) }
        Mock Read-SetupRawConsoleKey { $script:PendingConsoleKeys.Dequeue() }
        Mock Test-SetupConsoleKeyAvailable { $script:PendingConsoleKeys.Count -gt 0 }
      }

      function ConvertTo-TestConsoleKeys {
        param([string]$Text)
        return @($Text.ToCharArray() | ForEach-Object { New-TestConsoleKey -KeyCharCode ([int]$_) })
      }
    }

    It 'ESC como carácter VT (Key None) cancela el menú' {
      Set-TestConsoleInput -Keys @(New-TestConsoleKey -KeyCharCode 27)

      Read-SetupMenuKey | Should -Be 'Cancel'
    }

    It 'ESC nativo de la consola cancela el menú' {
      Set-TestConsoleInput -Keys @(New-TestConsoleKey -KeyCharCode 27 -Key Escape)

      Read-SetupMenuKey | Should -Be 'Cancel'
    }

    It 'la secuencia VT <Sequence> se lee como <Expected>' -ForEach @(
      @{ Sequence = '[A'; Expected = 'Up' },
      @{ Sequence = '[B'; Expected = 'Down' },
      @{ Sequence = 'OH'; Expected = 'Home' },
      @{ Sequence = '[F'; Expected = 'End' },
      @{ Sequence = '[5~'; Expected = 'PageUp' },
      @{ Sequence = '[6~'; Expected = 'PageDown' },
      @{ Sequence = '[1;5A'; Expected = 'Up' }
    ) {
      Set-TestConsoleInput -Keys (@(New-TestConsoleKey -KeyCharCode 27) + (ConvertTo-TestConsoleKeys -Text $Sequence))

      Read-SetupMenuKey | Should -Be $Expected
      $script:PendingConsoleKeys.Count | Should -Be 0
    }

    It 'una secuencia VT desconocida se ignora sin cancelar' {
      Set-TestConsoleInput -Keys (@(New-TestConsoleKey -KeyCharCode 27) + (ConvertTo-TestConsoleKeys -Text '[Z'))

      Read-SetupMenuKey | Should -Be 'Other'
    }

    It 'el carácter VT <KeyCharCode> se lee como <Expected>' -ForEach @(
      @{ KeyCharCode = 13; Expected = 'Enter' },
      @{ KeyCharCode = 32; Expected = 'Toggle' },
      @{ KeyCharCode = 3; Expected = 'Cancel' },
      @{ KeyCharCode = 4; Expected = 'Cancel' }
    ) {
      Set-TestConsoleInput -Keys @(New-TestConsoleKey -KeyCharCode $KeyCharCode)

      Read-SetupMenuKey | Should -Be $Expected
    }

    It 'ESC como carácter VT cierra la búsqueda sin mover el cursor' {
      Mock Clear-Host { }
      Mock Write-ClearedSetupMenuLine { }
      Mock Write-SearchSetupMenu { }
      Mock Set-SetupConsoleCursorPosition { }
      Set-TestConsoleInput -Keys @(New-TestConsoleKey -KeyCharCode 27)
      $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()

      $searchResult = Invoke-SetupMenuSearch -menuCatalog (New-TestSetupMenuCatalog) -selectedIndexes $selectedIndexes -cursorIndex 1 -visibleItemCount 5

      $searchResult.Cancelled | Should -BeTrue
      $searchResult.CursorIndex | Should -Be 1
    }

    It 'Backspace VT (127) borra el último carácter de la búsqueda' {
      Mock Clear-Host { }
      Mock Write-ClearedSetupMenuLine { }
      Mock Write-SearchSetupMenu { }
      Mock Set-SetupConsoleCursorPosition { }
      Set-TestConsoleInput -Keys ((ConvertTo-TestConsoleKeys -Text 'pz') + @((New-TestConsoleKey -KeyCharCode 127), (New-TestConsoleKey -KeyCharCode 13)))
      $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()

      $searchResult = Invoke-SetupMenuSearch -menuCatalog (New-TestSetupMenuCatalog) -selectedIndexes $selectedIndexes -cursorIndex 0 -visibleItemCount 5

      $searchResult.Cancelled | Should -BeFalse
      $searchResult.CursorIndex | Should -Be 1
    }
  }

  Context 'salida solo ASCII' {
    It 'el ícono <_> es ASCII' -ForEach @('Pointer', 'Checked', 'Unchecked', 'Recommended', 'Admin', 'Restart', 'Ok', 'FailedItem', 'Warn', 'Error') {
      Get-SetupIcon $_ | Should -Not -Match '[^\x00-\x7F]'
    }

    It 'el glifo <_> es ASCII' -ForEach @('BoxTopLeft', 'BoxVertical', 'BoxHorizontal', 'ScrollbarThumb', 'ScrollbarTrack', 'ArrowUp', 'ArrowDown', 'Separator', 'BarFilled', 'BarEmpty') {
      Get-SetupGlyph $_ | Should -Not -Match '[^\x00-\x7F]'
    }
  }
}
