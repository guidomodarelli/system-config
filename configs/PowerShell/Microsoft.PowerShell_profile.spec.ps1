Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-ProfileFunctions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter(Mandatory = $true)]
        [string[]]$FunctionNames
    )

    $tokens = $null
    $parseErrors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        throw "Profile script has parse errors: $($parseErrors.Message -join '; ')"
    }

    foreach ($functionName in $FunctionNames) {
        $functionDefinition = $scriptAst.Find(
            {
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
            },
            $true
        )

        if (-not $functionDefinition) {
            throw "Function '$functionName' was not found in profile script."
        }

        Invoke-Expression "function global:$($functionDefinition.Name) $($functionDefinition.Body.Extent.Text)"
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Expected,
        [Parameter(Mandatory = $true)]
        [object]$Actual,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Items,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedItem,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Items -notcontains $ExpectedItem) {
        throw "$Message Expected item '$ExpectedItem'."
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Items,
        [Parameter(Mandatory = $true)]
        [string]$UnexpectedItem,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Items -contains $UnexpectedItem) {
        throw "$Message Unexpected item '$UnexpectedItem'."
    }
}

$profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
Import-ProfileFunctions -ScriptPath $profilePath -FunctionNames @(
    'Test-CacheEntryIsFresh',
    'Get-GhqRepositoryScanExcludedDirectoryNames',
    'Test-ShouldSkipGhqScanDirectory',
    'Test-IsReparsePointDirectory',
    'Test-IsBareGitRepositoryDirectory',
    'Test-IsGitRepositoryDirectory',
    'Get-RelativePathCompat',
    'Get-GhqRootFingerprint',
    'Get-CachedGhqRepositoryList'
)

$script:GhqSelectionCacheTtlSeconds = 10
$script:GhqRepositoryListCache = $null
$script:GhqRepositoryListCacheTimestamp = $null
$script:GhqRepositoryListCacheRootFingerprint = $null
$script:GhqRepositoryScanDefaultExcludedDirectoryNames = @(
    '.cache',
    '.npm',
    '.pnpm-store',
    '.yarn',
    '.terraform',
    'node_modules'
)
$script:GhqRepositoryScanExcludedDirectoryNames = @()

$script:FakeGhqRootPath = $null
$script:FakeGhqListResult = @()

function global:Get-CachedGhqRootPath {
    return $script:FakeGhqRootPath
}

function global:Get-CachedGhqCommandInfo {
    return [pscustomobject]@{ Source = 'ghq' }
}

function global:ghq {
    param(
        [string]$command
    )

    if ($command -eq 'list') {
        return $script:FakeGhqListResult
    }

    return @()
}

$testRootPath = Join-Path ([System.IO.Path]::GetTempPath()) ("profile-ghq-spec-" + [System.Guid]::NewGuid().ToString())
New-Item -Path $testRootPath -ItemType Directory | Out-Null

try {
    [Environment]::SetEnvironmentVariable('GHQ_SCAN_EXCLUDES', 'tmp-cache,custom_large_dir')

    $mergedExclusions = @(Get-GhqRepositoryScanExcludedDirectoryNames)
    Assert-Contains -Items $mergedExclusions -ExpectedItem 'node_modules' -Message 'Default exclusions should be preserved.'
    Assert-Contains -Items $mergedExclusions -ExpectedItem 'custom_large_dir' -Message 'Environment exclusions should be appended.'

    $simulatedReparseDirectory = [pscustomobject]@{
        Attributes = [System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::ReparsePoint
    }
    Assert-True -Condition (Test-IsReparsePointDirectory -DirectoryInfo $simulatedReparseDirectory) -Message 'Reparse-point directories should be detected.'

    $normalRepositoryPath = Join-Path $testRootPath 'github.com\acme\alpha'
    New-Item -Path (Join-Path $normalRepositoryPath '.git') -ItemType Directory -Force | Out-Null

    $worktreeRepositoryPath = Join-Path $testRootPath 'github.com\acme\beta-worktree'
    New-Item -Path $worktreeRepositoryPath -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $worktreeRepositoryPath '.git') -Value 'gitdir: C:\tmp\linked-worktree' -NoNewline

    $bareRepositoryPath = Join-Path $testRootPath 'github.com\acme\gamma-bare'
    New-Item -Path (Join-Path $bareRepositoryPath 'objects') -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $bareRepositoryPath 'refs') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $bareRepositoryPath 'HEAD') -Value 'ref: refs/heads/main' -NoNewline

    $ignoredRepositoryPath = Join-Path $testRootPath 'node_modules\ignored\repo'
    New-Item -Path (Join-Path $ignoredRepositoryPath '.git') -ItemType Directory -Force | Out-Null

    $duplicateCaseRepositoryPath = Join-Path $testRootPath 'GitHub.com\Acme\ALPHA'
    New-Item -Path (Join-Path $duplicateCaseRepositoryPath '.git') -ItemType Directory -Force | Out-Null

    $script:FakeGhqRootPath = $testRootPath
    $script:GhqRepositoryListCache = $null
    $script:GhqRepositoryListCacheTimestamp = $null
    $script:GhqRepositoryListCacheRootFingerprint = $null
    $script:FakeGhqListResult = @()

    $detectedRepositories = @(Get-CachedGhqRepositoryList)
    Assert-Contains -Items $detectedRepositories -ExpectedItem 'github.com/acme/alpha' -Message 'Scanner should detect repositories with .git directory.'
    Assert-Contains -Items $detectedRepositories -ExpectedItem 'github.com/acme/beta-worktree' -Message 'Scanner should detect repositories with .git file (worktree).'
    Assert-Contains -Items $detectedRepositories -ExpectedItem 'github.com/acme/gamma-bare' -Message 'Scanner should detect bare repositories.'
    Assert-NotContains -Items $detectedRepositories -UnexpectedItem 'node_modules/ignored/repo' -Message 'Scanner should skip excluded directories.'
    Assert-Equal -Expected 3 -Actual $detectedRepositories.Count -Message 'Scanner should deduplicate case-insensitive repository paths.'

    $cacheBeforeChange = @(Get-CachedGhqRepositoryList)
    Assert-Equal -Expected 3 -Actual $cacheBeforeChange.Count -Message 'Second call should return warm cache.'

    Start-Sleep -Milliseconds 1200
    $newRepositoryPath = Join-Path $testRootPath 'github.com\new-owner\delta-new'
    New-Item -Path (Join-Path $newRepositoryPath '.git') -ItemType Directory -Force | Out-Null

    $cacheAfterChange = @(Get-CachedGhqRepositoryList)
    Assert-Contains -Items $cacheAfterChange -ExpectedItem 'github.com/new-owner/delta-new' -Message 'Cache should be invalidated when ghq root metadata changes.'
    Assert-Equal -Expected 4 -Actual $cacheAfterChange.Count -Message 'Scanner should include repositories created after cache warm-up.'

    $script:FakeGhqRootPath = Join-Path $testRootPath 'missing-root'
    $script:FakeGhqListResult = @('github.com/acme/from-ghq-list')
    $script:GhqRepositoryListCache = $null
    $script:GhqRepositoryListCacheTimestamp = $null
    $script:GhqRepositoryListCacheRootFingerprint = $null

    $fallbackRepositories = @(Get-CachedGhqRepositoryList)
    Assert-Equal -Expected 1 -Actual $fallbackRepositories.Count -Message 'Fallback should return repositories from ghq list when filesystem scan is unavailable.'
    Assert-Equal -Expected 'github.com/acme/from-ghq-list' -Actual $fallbackRepositories[0] -Message 'Fallback should preserve ghq list entries.'
} finally {
    [Environment]::SetEnvironmentVariable('GHQ_SCAN_EXCLUDES', $null)
    if (Test-Path -LiteralPath $testRootPath) {
        Remove-Item -LiteralPath $testRootPath -Recurse -Force
    }
}

Write-Host 'Microsoft.PowerShell_profile ghq repository scan tests passed.'
