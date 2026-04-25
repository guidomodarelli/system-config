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
    [PSCustomObject]@{ Label = 'Git' },
    [PSCustomObject]@{ Label = 'PowerToys' }
  )
}

$setupScriptPath = Join-Path $PSScriptRoot 'setup.ps1'
Import-SetupScriptFunctions -ScriptPath $setupScriptPath

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

Write-Host 'setup.ps1 menu search tests passed.'
