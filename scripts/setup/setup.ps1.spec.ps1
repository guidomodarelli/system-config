Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-SetupScriptFunctions {
  param (
    [string]$ScriptPath
  )

  $tokens = $null
  $parseErrors = $null
  $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)

  if ($parseErrors.Count -gt 0) {
    throw "setup.ps1 has parse errors: $($parseErrors.Message -join '; ')"
  }

  $functionDefinitions = $scriptAst.FindAll(
    {
      param ($node)
      return $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    },
    $true
  )

  foreach ($functionDefinition in $functionDefinitions) {
    Invoke-Expression "function global:$($functionDefinition.Name) $($functionDefinition.Body.Extent.Text)"
  }
}

function Assert-Equal {
  param (
    [object]$Expected,
    [object]$Actual,
    [string]$Message
  )

  if ($Expected -ne $Actual) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function Assert-Contains {
  param (
    [string]$Haystack,
    [string]$Needle,
    [string]$Message
  )

  if (-not $Haystack.Contains($Needle)) {
    throw "$Message Expected output to contain '$Needle'."
  }
}

function Assert-NotContains {
  param (
    [string]$Haystack,
    [string]$Needle,
    [string]$Message
  )

  if ($Haystack.Contains($Needle)) {
    throw "$Message Expected output not to contain '$Needle'."
  }
}

function ConvertTo-TestArray {
  param (
    [object]$Value
  )

  if ($null -eq $Value) {
    return @()
  }

  $values = @($Value)
  if ($values.Count -eq 1 -and $values[0] -is [array]) {
    return @($values[0])
  }

  return $values
}

function New-TestSetupMenuCatalog {
  return @(
    [PSCustomObject]@{ Id = 'git'; Label = 'Git'; FunctionName = 'Install-Git'; DefaultSelected = $true; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false },
    [PSCustomObject]@{ Id = 'powertoys'; Label = 'PowerToys'; FunctionName = 'Install-PowerToys'; DefaultSelected = $false; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false }
  )
}

$setupScriptPath = Join-Path $PSScriptRoot 'setup.ps1'
Import-SetupScriptFunctions -ScriptPath $setupScriptPath

$setupScriptContent = Get-Content -Path $setupScriptPath -Raw
Assert-Contains -Haystack $setupScriptContent -Needle "latest-stable-official" -Message 'PowerShell setup should make the latest stable policy explicit.'
Assert-NotContains -Haystack $setupScriptContent -Needle 'setup.pwsh.catalog.csv' -Message 'PowerShell setup should not reference the old PowerShell-only catalog.'

$sharedCatalogPath = Join-Path $PSScriptRoot 'setup.catalog.csv'
$sharedMenuCatalog = Get-SetupMenuCatalog -CatalogPath $sharedCatalogPath
Test-SetupMenuCatalog -menuCatalog $sharedMenuCatalog
Assert-Equal -Expected $true -Actual (Test-SetupFunctionAllowed -menuCatalog $sharedMenuCatalog -FunctionName 'Install-Git') -Message 'Catalog allowlist should include setup installer functions.'
Assert-Equal -Expected $false -Actual (Test-SetupFunctionAllowed -menuCatalog $sharedMenuCatalog -FunctionName 'Get-ChildItem') -Message 'Catalog allowlist should reject functions outside setup installers.'
Assert-Equal -Expected 'Chocolatey' -Actual $sharedMenuCatalog[0].Label -Message 'PowerShell catalog should be loaded from the shared setup catalog.'
Assert-Equal -Expected 'chocolatey' -Actual $sharedMenuCatalog[0].Id -Message 'PowerShell catalog should preserve setup ids.'
Assert-Equal -Expected $true -Actual $sharedMenuCatalog[0].RequiresAdmin -Message 'PowerShell catalog should load admin metadata.'
Assert-Equal -Expected 'windows' -Actual $sharedMenuCatalog[0].Platforms -Message 'PowerShell catalog should load platform metadata.'
Assert-Equal -Expected $false -Actual $sharedMenuCatalog[0].RequiresRestart -Message 'PowerShell catalog should load restart metadata.'

$invalidHeaderCatalogPath = Join-Path $PSScriptRoot 'invalid-header.catalog.csv'
Set-Content -Path $invalidHeaderCatalogPath -Value @('Id|Label|FunctionName', 'git|Git|Install-Git')
$invalidHeaderFailed = $false
try {
  Get-SetupMenuCatalog -CatalogPath $invalidHeaderCatalogPath | Out-Null
} catch {
  $invalidHeaderFailed = $true
} finally {
  Remove-Item -Path $invalidHeaderCatalogPath -Force
}
Assert-Equal -Expected $true -Actual $invalidHeaderFailed -Message 'PowerShell catalog loading should reject non-shared headers.'

$duplicatedIdCatalog = @(
  [PSCustomObject]@{ Id = 'git'; Label = 'Git'; FunctionName = 'Install-Git'; DefaultSelected = $true; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false },
  [PSCustomObject]@{ Id = 'git'; Label = 'Git duplicated'; FunctionName = 'Install-Git'; DefaultSelected = $false; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false }
)
$duplicatedIdFailed = $false
try {
  Test-SetupMenuCatalog -menuCatalog $duplicatedIdCatalog
} catch {
  $duplicatedIdFailed = $true
}
Assert-Equal -Expected $true -Actual $duplicatedIdFailed -Message 'PowerShell catalog validation should reject duplicated ids.'

$unsupportedPlatformCatalog = @(
  [PSCustomObject]@{ Id = 'git'; Label = 'Git'; FunctionName = 'Install-Git'; DefaultSelected = $true; RequiresAdmin = $false; Platforms = 'windows,plan9'; RequiresRestart = $false }
)
$unsupportedPlatformFailed = $false
try {
  Test-SetupMenuCatalog -menuCatalog $unsupportedPlatformCatalog
} catch {
  $unsupportedPlatformFailed = $true
}
Assert-Equal -Expected $true -Actual $unsupportedPlatformFailed -Message 'PowerShell catalog validation should reject unsupported platform tokens.'

$missingFunctionCatalog = @(
  [PSCustomObject]@{ Id = 'missing'; Label = 'Missing'; FunctionName = 'Install-MissingTool'; DefaultSelected = $true; RequiresAdmin = $false; Platforms = 'windows'; RequiresRestart = $false }
)
$missingFunctionFailed = $false
try {
  Test-SetupMenuCatalog -menuCatalog $missingFunctionCatalog
} catch {
  $missingFunctionFailed = $true
}
Assert-Equal -Expected $true -Actual $missingFunctionFailed -Message 'PowerShell catalog validation should reject missing PowerShell functions.'

$parsedSetupArguments = ConvertTo-SetupArguments -Arguments @('Install-Git', '--dry-run', 'fd_find', '--yes')
Assert-Equal -Expected $true -Actual $parsedSetupArguments.DryRun -Message 'PowerShell CLI parsing should accept dry-run after commands.'
Assert-Equal -Expected $true -Actual $parsedSetupArguments.AssumeYes -Message 'PowerShell CLI parsing should accept yes after commands.'
Assert-Equal -Expected 'Install-Git fd_find' -Actual ($parsedSetupArguments.CommandArguments -join ' ') -Message 'PowerShell CLI parsing should preserve command arguments.'

Assert-Equal -Expected 0 -Actual (Find-SetupMenuCatalogItemIndex -menuCatalog $sharedMenuCatalog -ItemIdentifier 'chocolatey') -Message 'PowerShell catalog lookup should accept setup ids.'
Assert-Equal -Expected 0 -Actual (Find-SetupMenuCatalogItemIndex -menuCatalog $sharedMenuCatalog -ItemIdentifier 'Install-Choco') -Message 'PowerShell catalog lookup should accept function names.'
Assert-Equal -Expected $true -Actual (Test-SetupMenuIndexesRequireAdmin -menuCatalog $sharedMenuCatalog -selectedIndexes @(0)) -Message 'PowerShell selected metadata should detect admin requirements.'
$gitMenuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $sharedMenuCatalog -ItemIdentifier 'git'
$curlMenuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $sharedMenuCatalog -ItemIdentifier 'curl'
$vscodeMenuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $sharedMenuCatalog -ItemIdentifier 'vscode'
$batMenuIndex = Find-SetupMenuCatalogItemIndex -menuCatalog $sharedMenuCatalog -ItemIdentifier 'bat'
Assert-Equal -Expected $false -Actual $sharedMenuCatalog[$gitMenuIndex].RequiresAdmin -Message 'PowerShell catalog should preserve non-admin Git installs.'
Assert-Equal -Expected $false -Actual $sharedMenuCatalog[$curlMenuIndex].RequiresAdmin -Message 'PowerShell catalog should preserve non-admin curl installs.'
Assert-Equal -Expected $false -Actual $sharedMenuCatalog[$vscodeMenuIndex].RequiresAdmin -Message 'PowerShell catalog should preserve non-admin VS Code installs.'
Assert-Equal -Expected $true -Actual ($batMenuIndex -ge 0) -Message 'PowerShell catalog should include bat from the previous PowerShell catalog.'
Assert-Equal -Expected $true -Actual (Test-SetupFunctionAllowed -menuCatalog $sharedMenuCatalog -FunctionName 'Install-Bat') -Message 'PowerShell catalog allowlist should include Install-Bat.'

$scriptDownloadPath = $null
function global:Invoke-RestMethod {
  param (
    [string]$Uri,
    [string]$OutFile,
    [object]$ErrorAction
  )

  $script:scriptDownloadPath = $OutFile
  Set-Content -Path $OutFile -Value '$global:LASTEXITCODE = 0'
}

$temporaryDirectoryPath = New-SetupTemporaryDirectory
Remove-SetupTemporaryDirectory -Path $temporaryDirectoryPath
Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $temporaryDirectoryPath) -Message 'Temporary setup directories should be removable.'

Invoke-SetupLatestOfficialScript -Uri 'https://example.test/install.ps1' -FileName 'install.ps1'
Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Split-Path -Path $scriptDownloadPath -Parent)) -Message 'Remote installer helper should clean temporary downloads.'

$wingetActions = @()
function global:winget {
  $script:wingetActions += ($args -join ' ')
  $global:LASTEXITCODE = 0
}

Install-WingetPackage -appIds @('Example.Tool')
Assert-Equal -Expected $true -Actual (($wingetActions -join '|').Contains('upgrade --exact --id Example.Tool')) -Message 'Winget installer should update installed packages to the latest stable version.'

$failedSetupResults = @(
  [PSCustomObject]@{ Label = 'Git'; Status = 'OK'; Detail = ''; RequiresRestart = $false },
  [PSCustomObject]@{ Label = 'PowerToys'; Status = 'Falló'; Detail = 'winget error'; RequiresRestart = $false }
)
Assert-Equal -Expected $true -Actual (Test-SetupExecutionResultsHaveFailures -results $failedSetupResults) -Message 'PowerShell setup results should detect failed installer results.'

$nonFailedSetupResults = @(
  [PSCustomObject]@{ Label = 'Git'; Status = 'OK'; Detail = ''; RequiresRestart = $false },
  [PSCustomObject]@{ Label = 'PowerToys'; Status = 'Dry-run'; Detail = 'No ejecutado'; RequiresRestart = $false },
  [PSCustomObject]@{ Label = 'VLC'; Status = 'Omitido'; Detail = 'Plataforma no soportada'; RequiresRestart = $false }
)
Assert-Equal -Expected $false -Actual (Test-SetupExecutionResultsHaveFailures -results $nonFailedSetupResults) -Message 'PowerShell setup results should not fail on successful, dry-run, or skipped results.'

$menuCatalog = New-TestSetupMenuCatalog

$invalidWildcardMatches = @(ConvertTo-TestArray -Value (Get-FilteredSetupMenuIndexes -menuCatalog $menuCatalog -query '['))
Assert-Equal -Expected 0 -Actual $invalidWildcardMatches.Count -Message 'Search should treat invalid wildcard characters as literal text.'

$wildcardMatches = @(ConvertTo-TestArray -Value (Get-FilteredSetupMenuIndexes -menuCatalog $menuCatalog -query '*'))
Assert-Equal -Expected 0 -Actual $wildcardMatches.Count -Message 'Search should not treat wildcard characters as patterns.'

$caseInsensitiveMatches = @(ConvertTo-TestArray -Value (Get-FilteredSetupMenuIndexes -menuCatalog $menuCatalog -query 'git'))
Assert-Equal -Expected 1 -Actual $caseInsensitiveMatches.Count -Message 'Search should match labels case-insensitively.'
Assert-Equal -Expected 0 -Actual $caseInsensitiveMatches[0] -Message 'Search should return the matching menu index.'

$matchingMenuIndex = Find-SetupMenuItemIndex -menuCatalog $menuCatalog -query 'toy' -startIndex 0
Assert-Equal -Expected 1 -Actual $matchingMenuIndex -Message 'Find should return the next literal case-insensitive match.'

$invalidWildcardMenuIndex = Find-SetupMenuItemIndex -menuCatalog $menuCatalog -query '[' -startIndex 0
Assert-Equal -Expected 0 -Actual $invalidWildcardMenuIndex -Message 'Find should keep the cursor when literal text has no match.'

$defaultSelectedRowSegments = @(Get-SetupMenuRowSegments -menuItem $menuCatalog[0] -IsSelected $true -IsCursor $false)
Assert-Equal -Expected '   [x] @ Git' -Actual (($defaultSelectedRowSegments | ForEach-Object Text) -join '') -Message 'Default selected row should keep the visible menu text.'
Assert-Equal -Expected ([Console]::ForegroundColor) -Actual $defaultSelectedRowSegments[3].ForegroundColor -Message 'Opening bracket should use the default foreground color.'
Assert-Equal -Expected ([ConsoleColor]::DarkGreen) -Actual $defaultSelectedRowSegments[4].ForegroundColor -Message 'Selected marker should use a muted green.'
Assert-Equal -Expected ([Console]::ForegroundColor) -Actual $defaultSelectedRowSegments[5].ForegroundColor -Message 'Closing bracket should use the default foreground color.'
Assert-Equal -Expected ([ConsoleColor]::DarkYellow) -Actual $defaultSelectedRowSegments[6].ForegroundColor -Message 'Default marker should use a muted yellow.'

$cursorRowSegments = @(Get-SetupMenuRowSegments -menuItem $menuCatalog[1] -IsSelected $false -IsCursor $true)
Assert-Equal -Expected ' > [ ] PowerToys' -Actual (($cursorRowSegments | ForEach-Object Text) -join '') -Message 'Cursor row should keep the visible menu text.'
Assert-Equal -Expected ([ConsoleColor]::Black) -Actual $cursorRowSegments[1].ForegroundColor -Message 'Cursor marker should use black on the highlighted row.'
Assert-Equal -Expected ([ConsoleColor]::Gray) -Actual $cursorRowSegments[3].BackgroundColor -Message 'Cursor row bracket should keep the highlighted background.'
Assert-Equal -Expected ([ConsoleColor]::Gray) -Actual $cursorRowSegments[4].BackgroundColor -Message 'Cursor row selection marker should keep the highlighted background.'

$referenceRows = @(Get-SetupMenuReferenceRows)
Assert-Equal -Expected 'Arriba/Abajo/j/k' -Actual $referenceRows[0].Shortcut -Message 'Reference rows should start with navigation keys.'
Assert-Equal -Expected ([ConsoleColor]::DarkCyan) -Actual $referenceRows[0].ShortcutColor -Message 'Key references should use muted cyan.'
Assert-Equal -Expected ([ConsoleColor]::DarkMagenta) -Actual (Get-SetupMenuReferenceFrameColor) -Message 'Reference table frame should use muted violet.'

$defaultMarkerSegments = @(Get-SetupMenuDefaultMarkerSegments)
Assert-Equal -Expected '  @ seleccionado por defecto' -Actual (($defaultMarkerSegments | ForEach-Object Text) -join '') -Message 'Default marker legend should keep the visible text.'
Assert-Equal -Expected ([ConsoleColor]::DarkYellow) -Actual $defaultMarkerSegments[1].ForegroundColor -Message 'Default marker legend should use muted yellow.'

$rangeSegments = @(Get-SetupMenuRangeSegments -FirstVisibleItemNumber 1 -LastVisibleItemNumber 5 -TotalItemCount 20)
Assert-Equal -Expected '  Elementos 1-5 de 20' -Actual (($rangeSegments | ForEach-Object Text) -join '') -Message 'Range line should keep the visible menu text.'
Assert-Equal -Expected ([ConsoleColor]::DarkCyan) -Actual $rangeSegments[1].ForegroundColor -Message 'First visible item number should use muted cyan.'
Assert-Equal -Expected ([ConsoleColor]::DarkCyan) -Actual $rangeSegments[3].ForegroundColor -Message 'Last visible item number should use muted cyan.'
Assert-Equal -Expected ([ConsoleColor]::DarkCyan) -Actual $rangeSegments[5].ForegroundColor -Message 'Total item count should use muted cyan.'

$renderedLineCount = Get-ClassicSetupMenuRenderedLineCount -visibleItemCount 24
Assert-Equal -Expected 28 -Actual $renderedLineCount -Message 'Rendered line count should include range, default marker, top indicator, items, and bottom indicator.'

$firstVisibleItemOffset = Get-ClassicSetupMenuItemRowOffset -menuIndex 10 -windowStartIndex 10
Assert-Equal -Expected 3 -Actual $firstVisibleItemOffset -Message 'First visible menu item should render after range, default marker, and top indicator.'

$thirdVisibleItemOffset = Get-ClassicSetupMenuItemRowOffset -menuIndex 12 -windowStartIndex 10
Assert-Equal -Expected 5 -Actual $thirdVisibleItemOffset -Message 'Visible menu item offset should include its position in the current window.'

$bottomIndicatorOffset = $renderedLineCount - 1
Assert-Equal -Expected 27 -Actual $bottomIndicatorOffset -Message 'Bottom indicator should remain the final rendered menu line.'

$sameWindowNavigationRequiresFullRender = Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 0 -previousVisibleItemCount 5 -visibleItemCount 5 -ForceFullRender $false
Assert-Equal -Expected $false -Actual $sameWindowNavigationRequiresFullRender -Message 'Navigation inside the same window should allow partial row repaint.'

$windowChangeRequiresFullRender = Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 1 -previousVisibleItemCount 5 -visibleItemCount 5 -ForceFullRender $false
Assert-Equal -Expected $true -Actual $windowChangeRequiresFullRender -Message 'Navigation that changes the visible window should require a full render.'

$toggleCurrentItemRequiresFullRender = Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 0 -previousVisibleItemCount 5 -visibleItemCount 5 -ForceFullRender $false
Assert-Equal -Expected $false -Actual $toggleCurrentItemRequiresFullRender -Message 'Toggling the cursor item should allow a single-row repaint.'

$bulkSelectionRequiresFullRender = Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 0 -previousVisibleItemCount 5 -visibleItemCount 5 -ForceFullRender $true
Assert-Equal -Expected $true -Actual $bulkSelectionRequiresFullRender -Message 'Bulk selection updates should force a full render.'

$searchReturnRequiresFullRender = Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 0 -previousVisibleItemCount 5 -visibleItemCount 5 -ForceFullRender $true
Assert-Equal -Expected $true -Actual $searchReturnRequiresFullRender -Message 'Returning from search should force a full render.'

$resizeRequiresFullRender = Test-ClassicSetupMenuRequiresFullRender -previousWindowStartIndex 0 -windowStartIndex 0 -previousVisibleItemCount 5 -visibleItemCount 6 -ForceFullRender $false
Assert-Equal -Expected $true -Actual $resizeRequiresFullRender -Message 'Changing the visible item count should require a full render.'

Write-Host 'setup.ps1 menu search tests passed.'
