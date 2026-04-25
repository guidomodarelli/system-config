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
    [PSCustomObject]@{ Label = 'Git'; DefaultSelected = $true },
    [PSCustomObject]@{ Label = 'PowerToys'; DefaultSelected = $false }
  )
}

$setupScriptPath = Join-Path $PSScriptRoot 'setup.ps1'
Import-SetupScriptFunctions -ScriptPath $setupScriptPath

$sharedMenuCatalog = Get-SetupMenuCatalog -CatalogPath (Join-Path $PSScriptRoot 'setup.pwsh.catalog.csv')
Test-SetupMenuCatalog -menuCatalog $sharedMenuCatalog
Assert-Equal -Expected $true -Actual (Test-SetupFunctionAllowed -menuCatalog $sharedMenuCatalog -FunctionName 'Install-Git') -Message 'Catalog allowlist should include setup installer functions.'
Assert-Equal -Expected $false -Actual (Test-SetupFunctionAllowed -menuCatalog $sharedMenuCatalog -FunctionName 'Get-ChildItem') -Message 'Catalog allowlist should reject functions outside setup installers.'
Assert-Equal -Expected 'Chocolatey' -Actual $sharedMenuCatalog[0].Label -Message 'PowerShell catalog should be loaded from the pwsh setup catalog.'

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
