$ErrorActionPreference = 'Stop'

$script:ExitCodeSuccess = 0
$script:ExitCodeRuntimeError = 1
$script:ExitCodeInputError = 2

$script:LinkTypeSymbolic = 'SymbolicLink'
$script:LinkTypeHard = 'HardLink'
$script:LinkLabelSymbolic = 'symlink'
$script:LinkLabelHard = 'hard link'

$script:DryRun = $false
$script:UseColor = $true
$script:UseIcons = $true
$script:Quiet = $false
$script:VerboseMode = $false
$script:CliArgs = @($args)
$script:IsElevatedSymlinkMode = $false
$script:ElevatedSymlinkSource = $null
$script:ElevatedSymlinkTarget = $null
$script:ElevatedSymlinkHardLink = $false
$script:PendingElevatedSymlinks = [System.Collections.Generic.List[object]]::new()

$script:RootDir = $null
$script:ConfigsDir = $null
$script:ConfigPathsFile = $null
$script:HomeDir = [Environment]::GetFolderPath('UserProfile')
$script:DocumentsDir = [Environment]::GetFolderPath('MyDocuments')
$script:WindowsUser = $env:USERNAME
$script:StartTime = Get-Date

$script:CountCreated = 0
$script:CountReplaced = 0
$script:CountBackups = 0
$script:CountRemoved = 0
$script:CountUnchanged = 0
$script:CountErrors = 0
$script:CountPlannedCreated = 0
$script:CountPlannedReplaced = 0
$script:CountPlannedBackups = 0
$script:CountPlannedRemoved = 0

$script:Diagnostics = [System.Collections.Generic.List[object]]::new()
$script:PreferredCommandPaths = @{}
$script:LastOutputWasBlank = $true
$script:PendingGroupHeader = $null
$script:GroupOpen = $false
$script:GroupChangeCount = 0
$script:GroupUnchangedCount = 0

# Emojis without variation selectors so columns stay aligned.
$script:Icons = @{
  App        = '🔗'
  RealRun    = '🚀'
  DryRun     = '🧪'
  Source     = '📦'
  Home       = '🏠'
  Group      = '📁'
  Created    = '✨'
  Replaced   = '🔄'
  Unchanged  = '✅'
  Delete     = '🧹'
  Backup     = '💾'
  Directory  = '📂'
  Elevated   = '🔐'
  Warn       = '🚨'
  Error      = '❌'
  Time       = '⌛'
  Summary    = '📊'
  Diagnostic = '🩺'
  Done       = '🎉'
  Failed     = '💥'
}
$script:BoxRuleWidth = 64
$script:ActionLabelWidth = 12
$script:SummaryLabelWidth = 14
$script:MinItemNameWidth = 16
$script:MaxItemNameWidth = 40
$script:ItemNameWidth = $script:MinItemNameWidth
$script:ProgressMode = if ([string]::IsNullOrWhiteSpace($env:DOTFILER_PROGRESS)) { 'auto' } else { $env:DOTFILER_PROGRESS }
$script:ProgressActivity = '🔗 dotfiler'
$script:ProgressBarWidth = 12
$script:ResolveMessages = @(
  @{ Icon = '🧭'; Text = 'Resolviendo rutas' },
  @{ Icon = '🧩'; Text = 'Recorriendo agrupadores' },
  @{ Icon = '🔎'; Text = 'Aplicando filtros' },
  @{ Icon = '🧹'; Text = 'Buscando enlaces obsoletos' },
  @{ Icon = '☕'; Text = 'Ya casi' }
)
$script:ResolveMessageSeconds = 2
$script:PlannedDirectoryReplacements = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)


function Get-AnsiColorCode {
  param([ConsoleColor]$Color)

  switch ($Color) {
    ([ConsoleColor]::Red) { return '31' }
    ([ConsoleColor]::Yellow) { return '33' }
    ([ConsoleColor]::Blue) { return '34' }
    ([ConsoleColor]::Green) { return '32' }
    ([ConsoleColor]::Magenta) { return '35' }
    ([ConsoleColor]::DarkGray) { return '90' }
    default { return '37' }
  }
}

function Format-AnsiSegment {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [ConsoleColor]$Color = [ConsoleColor]::Gray,
    [switch]$Bold,
    [switch]$Underline,
    [switch]$Italic
  )

  if (-not $script:UseColor) {
    return $Text
  }

  $ansiCodes = [System.Collections.Generic.List[string]]::new()
  if ($Bold) {
    $ansiCodes.Add('1')
  }
  if ($Underline) {
    $ansiCodes.Add('4')
  }
  if ($Italic) {
    $ansiCodes.Add('3')
  }
  $ansiCodes.Add((Get-AnsiColorCode -Color $Color))

  return "$([char]27)[$([string]::Join(';', $ansiCodes))m$Text$([char]27)[0m"
}

function Write-FormattedLine {
  param(
    [Parameter(Mandatory = $true)][string[]]$Segments,
    [switch]$ErrorStream
  )

  $message = [string]::Concat($Segments)

  if ($ErrorStream) {
    [Console]::Error.WriteLine($message)
  } else {
    Write-Output $message
  }

  $script:LastOutputWasBlank = $false
}

function Format-LabelText {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [ConsoleColor]$Color
  )

  return (Format-AnsiSegment -Text $Text -Color $Color -Bold)
}

function Format-IconText {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [ConsoleColor]$Color
  )

  return (Format-AnsiSegment -Text $Text -Color $Color -Bold)
}

function Format-PathText {
  param([Parameter(Mandatory = $true)][string]$Text)

  return (Format-AnsiSegment -Text $Text -Underline -Italic)
}

function Get-OptionalIcon {
  param([Parameter(Mandatory = $true)][string]$Icon)

  if (-not $script:UseIcons) {
    return ''
  }

  return $Icon
}

function Test-ProgressEnabled {
  switch ($script:ProgressMode) {
    'always' { return $true }
    'never' { return $false }
  }

  return (-not $script:Quiet) -and (-not [Console]::IsOutputRedirected)
}

function Format-ProgressBar {
  param(
    [int]$Current,
    [int]$Total
  )

  $filled = if ($Total -gt 0) { [int][Math]::Floor($Current * $script:ProgressBarWidth / $Total) } else { 0 }
  return ('▰' * $filled) + ('▱' * ($script:ProgressBarWidth - $filled))
}

# Rotating status text for the resolve phase, chosen from elapsed seconds.
function Get-ResolveProgressStatus {
  param(
    [int]$Current,
    [int]$Total,
    [string]$Detail,
    [int]$ElapsedSeconds
  )

  $message = $script:ResolveMessages[[int][Math]::Floor($ElapsedSeconds / $script:ResolveMessageSeconds) % $script:ResolveMessages.Count]
  return "$(Get-IconPrefix $message.Icon)$($message.Text) $(Format-ProgressBar -Current $Current -Total $Total) $Current/$Total · $Detail · $(Get-IconPrefix $script:Icons.Time)${ElapsedSeconds}s"
}

function Write-DotfilerProgress {
  param(
    [int]$Id,
    [string]$Status,
    [int]$Current,
    [int]$Total
  )

  if (-not (Test-ProgressEnabled)) {
    return
  }

  $percent = if ($Total -gt 0) { [int][Math]::Min(100, [Math]::Floor($Current * 100 / $Total)) } else { 0 }
  Write-Progress -Id $Id -Activity $script:ProgressActivity -Status $Status -PercentComplete $percent
}

function Complete-DotfilerProgress {
  param([int]$Id)

  if (Test-ProgressEnabled) {
    Write-Progress -Id $Id -Activity $script:ProgressActivity -Completed
  }
}

function Get-IconPrefix {
  param([AllowNull()][string]$Icon)

  if (-not $script:UseIcons -or [string]::IsNullOrEmpty($Icon)) {
    return ''
  }

  return "$Icon "
}

function Format-DisplayTarget {
  param([AllowNull()][string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($script:HomeDir)) {
    return $Path
  }

  $homePath = $script:HomeDir.TrimEnd('\', '/')
  if ([string]::Equals($Path, $homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return '~'
  }
  foreach ($separator in @('\', '/')) {
    if ($Path.StartsWith($homePath + $separator, [System.StringComparison]::OrdinalIgnoreCase)) {
      return '~' + $Path.Substring($homePath.Length)
    }
  }

  return $Path
}

# Shows sources relative to the repository configs directory, or with `~`.
function Format-DisplaySource {
  param([AllowNull()][string]$Path)

  if (-not [string]::IsNullOrWhiteSpace($script:ConfigsDir) -and -not [string]::IsNullOrWhiteSpace($Path)) {
    $configsPath = $script:ConfigsDir.TrimEnd('\', '/')
    foreach ($separator in @('\', '/')) {
      if ($Path.StartsWith($configsPath + $separator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($configsPath.Length + 1)
      }
    }
  }

  return (Format-DisplayTarget -Path $Path)
}

function Format-LinkDetail {
  param(
    [string]$SourcePath,
    [bool]$HardLink = $false
  )

  $detail = "→ $(Format-DisplaySource -Path $SourcePath)"
  if ($HardLink) {
    $detail = "$detail ($($script:LinkLabelHard))"
  }
  return $detail
}

# Boxes are open on the right: emoji width varies between terminals, so only
# the left border and horizontal rules are drawn.
function Write-BoxTop {
  param([string]$Title = '')

  if ([string]::IsNullOrEmpty($Title)) {
    Write-FormattedLine -Segments @((Format-AnsiSegment -Text ('╭' + ('─' * $script:BoxRuleWidth)) -Color DarkGray -Bold))
    return
  }

  $ruleLength = [Math]::Max(1, $script:BoxRuleWidth - $Title.Length - 4)
  Write-FormattedLine -Segments @(
    (Format-AnsiSegment -Text '╭─' -Color DarkGray -Bold), ' ',
    (Format-AnsiSegment -Text $Title -Color Blue -Bold), ' ',
    (Format-AnsiSegment -Text ('─' * $ruleLength) -Color DarkGray -Bold)
  )
}

function Write-BoxRow {
  param([string]$Content)

  Write-FormattedLine -Segments @((Format-AnsiSegment -Text '│' -Color DarkGray -Bold), ' ', $Content)
}

function Write-BoxDivider {
  Write-FormattedLine -Segments @((Format-AnsiSegment -Text ('├' + ('─' * $script:BoxRuleWidth)) -Color DarkGray -Bold))
}

function Write-BoxBottom {
  Write-FormattedLine -Segments @((Format-AnsiSegment -Text ('╰' + ('─' * $script:BoxRuleWidth)) -Color DarkGray -Bold))
}

function Write-BlockGap {
  if (-not $script:Quiet -and -not $script:LastOutputWasBlank) {
    Write-Output ''
    $script:LastOutputWasBlank = $true
  }
}

function Write-Banner {
  if ($script:Quiet) {
    return
  }

  $modeText = if ($script:DryRun) {
    "$(Get-IconPrefix $script:Icons.DryRun)simulacion: no se escriben cambios"
  } else {
    "$(Get-IconPrefix $script:Icons.RealRun)aplicacion real"
  }

  Write-BoxTop
  Write-BoxRow -Content ("$(Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.App)dotfiler" -Color Magenta -Bold) · $modeText")
  Write-BoxRow -Content (Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.Source)$(Format-DisplayTarget -Path $script:ConfigsDir)  →  $(Get-IconPrefix $script:Icons.Home)~" -Color DarkGray)
  Write-BoxBottom
}

# Registers the group header; it is printed lazily before the first visible
# line, so groups where nothing changed stay hidden unless --verbose is set.
function Set-GroupHeader {
  param([string]$GroupPath)

  $script:PendingGroupHeader = $GroupPath
  if ($script:VerboseMode) {
    Write-PendingGroupHeader
  }
}

function Write-PendingGroupHeader {
  if ([string]::IsNullOrEmpty($script:PendingGroupHeader) -or $script:Quiet) {
    return
  }

  $groupPath = $script:PendingGroupHeader
  $script:PendingGroupHeader = $null
  $script:GroupOpen = $true
  $script:GroupChangeCount = 0
  Write-BlockGap
  Write-FormattedLine -Segments @((Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.Group)$groupPath" -Color Magenta -Bold))
}

# Closes the current group box with its change and unchanged counts.
function Close-Group {
  if ($script:GroupOpen -and -not $script:Quiet) {
    $closingParts = [System.Collections.Generic.List[string]]::new()
    if (-not $script:VerboseMode -and $script:GroupChangeCount -gt 0) {
      $noun = if ($script:GroupChangeCount -eq 1) { 'cambio' } else { 'cambios' }
      $closingParts.Add("$($script:GroupChangeCount) $noun")
    }
    if ($script:GroupUnchangedCount -gt 0) {
      $closingParts.Add("$(Get-IconPrefix $script:Icons.Unchanged)$($script:GroupUnchangedCount) sin cambios")
    }

    $closingSegments = [System.Collections.Generic.List[string]]::new()
    $closingSegments.Add((Format-AnsiSegment -Text '╰─' -Color DarkGray -Bold))
    if ($closingParts.Count -gt 0) {
      $closingSegments.Add(' ')
      $closingSegments.Add((Format-AnsiSegment -Text ([string]::Join(' · ', $closingParts)) -Color DarkGray))
    }
    Write-FormattedLine -Segments $closingSegments.ToArray()
  }

  $script:PendingGroupHeader = $null
  $script:GroupOpen = $false
  $script:GroupChangeCount = 0
  $script:GroupUnchangedCount = 0
}

# Prints one operation row: icon, action label, item name and optional detail.
function Write-ItemLine {
  param(
    [Parameter(Mandatory = $true)][string]$Icon,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][ConsoleColor]$Color,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Detail = '',
    [switch]$Unchanged
  )

  if ($script:Quiet) {
    return
  }

  Write-PendingGroupHeader
  if (-not $Unchanged) {
    $script:GroupChangeCount += 1
  }

  $itemText = $Name
  if (-not [string]::IsNullOrEmpty($Detail)) {
    $itemText = "$($Name.PadRight($script:ItemNameWidth)) $(Format-AnsiSegment -Text $Detail -Color DarkGray)"
  }

  Write-BoxRow -Content ("$(Get-IconPrefix $Icon)$(Format-AnsiSegment -Text $Label.PadRight($script:ActionLabelWidth) -Color $Color -Bold) $itemText")
}

function Write-Info {
  param([string]$Message)
  if (-not $script:Quiet) {
    Write-FormattedLine -Segments @('  ', (Format-AnsiSegment -Text $Message -Color DarkGray))
  }
}

function Write-Warn {
  param([string]$Message)
  Write-FormattedLine -Segments @((Format-LabelText -Text "$(Get-IconPrefix $script:Icons.Warn)Aviso:" -Color Yellow), " $Message") -ErrorStream
}

function Write-ErrorLog {
  param([string]$Message)
  Write-FormattedLine -Segments @((Format-LabelText -Text "$(Get-IconPrefix $script:Icons.Error)Error:" -Color Red), " $Message") -ErrorStream
}







function Write-HelpText {
  @'
Uso: .\scripts\dotfiler\dotfiler.bat [opciones]

Opciones:
  --dry-run   Muestra los cambios planificados sin escribir archivos
  --no-color  Desactiva los colores
  --plain     Desactiva colores e iconos
  --verbose   Lista tambien los enlaces sin cambios y el tiempo por operacion
  --quiet     Oculta logs por item y deja resumen/errores
  --help      Muestra esta ayuda
'@ | Write-Output
}

function Parse-Args {
  param([string[]]$CliArgs)

  for ($index = 0; $index -lt $CliArgs.Count; $index += 1) {
    $arg = $CliArgs[$index]

    switch ($arg) {
      '--dry-run' { $script:DryRun = $true }
      '--no-color' { $script:UseColor = $false }
      '--plain' {
        $script:UseColor = $false
        $script:UseIcons = $false
      }
      '--verbose' { $script:VerboseMode = $true }
      '--quiet' { $script:Quiet = $true }
      '--internal-create-link' { $script:IsElevatedSymlinkMode = $true }
      '--internal-source' {
        if ($index + 1 -ge $CliArgs.Count) {
          Write-ErrorLog 'Falta valor para --internal-source'
          exit $script:ExitCodeInputError
        }

        $index += 1
        $script:ElevatedSymlinkSource = $CliArgs[$index]
      }
      '--internal-target' {
        if ($index + 1 -ge $CliArgs.Count) {
          Write-ErrorLog 'Falta valor para --internal-target'
          exit $script:ExitCodeInputError
        }

        $index += 1
        $script:ElevatedSymlinkTarget = $CliArgs[$index]
      }
      '--internal-hard-link' { $script:ElevatedSymlinkHardLink = $true }
      '--help' {
        Write-HelpText
        exit $script:ExitCodeSuccess
      }
      default {
        Write-ErrorLog "Opcion desconocida: $arg"
        Write-HelpText
        exit $script:ExitCodeInputError
      }
    }
  }
}

function Test-IsAdministrator {
  try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    return $false
  }
}

function Get-PowerShellExecutablePath {
  if ($null -ne $PSHOME) {
    $pwshCandidate = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    if (Test-Path -LiteralPath $pwshCandidate) {
      return $pwshCandidate
    }

    $windowsPowerShellCandidate = Join-Path -Path $PSHOME -ChildPath 'powershell.exe'
    if (Test-Path -LiteralPath $windowsPowerShellCandidate) {
      return $windowsPowerShellCandidate
    }
  }

  if ($null -ne (Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue)) {
    return 'pwsh.exe'
  }

  return 'powershell.exe'
}

function Test-IsPrivilegeElevationError {
  param([Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord)

  $exception = $ErrorRecord.Exception
  while ($null -ne $exception) {
    if ($exception -is [System.UnauthorizedAccessException]) {
      return $true
    }

    if ($exception.HResult -eq -2147024891 -or $exception.HResult -eq -2147023570) {
      return $true
    }

    $exception = $exception.InnerException
  }

  $errorText = ($ErrorRecord | Out-String).ToLowerInvariant()
  $privilegePatterns = @(
    'required privilege is not held',
    'requested operation requires elevation',
    'client does not possess a required privilege',
    'privilege is not held',
    'symbolic link',
    'simbolo',
    'elevation',
    '1314'
  )

  foreach ($pattern in $privilegePatterns) {
    if ($errorText.Contains($pattern)) {
      return $true
    }
  }

  return $false
}

function ConvertTo-WindowsProcessArgument {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

  if ($Value.Length -eq 0) {
    return '""'
  }

  $needsQuoting = $Value.IndexOfAny([char[]]@(' ', "`t", '"')) -ge 0
  if (-not $needsQuoting) {
    return $Value
  }

  $escapedValue = [System.Text.RegularExpressions.Regex]::Replace(
    $Value,
    '(\\*)"',
    '$1$1\"'
  )
  $escapedValue = [System.Text.RegularExpressions.Regex]::Replace($escapedValue, '(\\+)$', '$1$1')

  return '"' + $escapedValue + '"'
}

function ConvertTo-WindowsProcessArgumentsString {
  param([string[]]$ArgumentList = @())

  if ($null -eq $ArgumentList -or $ArgumentList.Count -eq 0) {
    return ''
  }

  $quotedArguments = $ArgumentList | ForEach-Object {
    ConvertTo-WindowsProcessArgument -Value $_
  }

  return [string]::Join(' ', $quotedArguments)
}

function Get-ElevatedSymlinkProcessArguments {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [switch]$HardLink
  )

  $processArguments = [System.Collections.Generic.List[string]]::new()
  $processArguments.Add('-NoLogo')
  $processArguments.Add('-NoProfile')
  $processArguments.Add('-ExecutionPolicy')
  $processArguments.Add('Bypass')
  $processArguments.Add('-File')
  $processArguments.Add($ScriptPath)
  $processArguments.Add('--internal-create-link')
  $processArguments.Add('--internal-source')
  $processArguments.Add($SourcePath)
  $processArguments.Add('--internal-target')
  $processArguments.Add($TargetPath)

  if ($HardLink) {
    $processArguments.Add('--internal-hard-link')
  }

  $quotedProcessArguments = $processArguments | ForEach-Object {
    ConvertTo-WindowsProcessArgument -Value $_
  }

  return ,$quotedProcessArguments
}

function Get-ElevationAllowedPrefixes {
  $prefixCandidates = [System.Collections.Generic.List[string]]::new()

  if (-not [string]::IsNullOrWhiteSpace($script:HomeDir)) {
    $prefixCandidates.Add($script:HomeDir)
  }
  if (-not [string]::IsNullOrWhiteSpace($script:RootDir)) {
    $prefixCandidates.Add($script:RootDir)
  }
  foreach ($envName in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'ProgramData')) {
    $envValue = [Environment]::GetEnvironmentVariable($envName)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) {
      $prefixCandidates.Add($envValue)
    }
  }

  $normalizedPrefixes = [System.Collections.Generic.List[string]]::new()
  $seenPrefixes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($prefix in $prefixCandidates) {
    $normalizedPrefix = $prefix.TrimEnd([char[]]@('\', '/'))
    if ([string]::IsNullOrWhiteSpace($normalizedPrefix)) {
      continue
    }
    if ($seenPrefixes.Add($normalizedPrefix)) {
      $normalizedPrefixes.Add($normalizedPrefix)
    }
  }

  return @($normalizedPrefixes)
}

function Test-ElevationTargetAllowed {
  param([Parameter(Mandatory = $true)][string]$TargetPath)

  try {
    $absoluteTarget = [System.IO.Path]::GetFullPath($TargetPath)
  } catch {
    return $false
  }

  foreach ($prefix in (Get-ElevationAllowedPrefixes)) {
    try {
      $absolutePrefix = [System.IO.Path]::GetFullPath($prefix)
    } catch {
      continue
    }

    $absolutePrefixWithSeparator = $absolutePrefix.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
    if ($absoluteTarget.Equals($absolutePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        $absoluteTarget.StartsWith($absolutePrefixWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Invoke-ElevatedSymlinkCreation {
  param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [switch]$HardLink
  )

  if (-not (Test-ElevationTargetAllowed -TargetPath $TargetPath)) {
    throw "Auto-elevacion bloqueada: el destino '$TargetPath' esta fuera de las rutas permitidas (HOME, repo, APPDATA, LOCALAPPDATA, USERPROFILE, ProgramData). Cree el symlink manualmente desde una sesion administrativa si realmente lo necesita."
  }

  if ($HardLink -and -not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "No se puede crear hard link: el origen '$SourcePath' no es un archivo regular."
  }

  $powerShellExecutable = Get-PowerShellExecutablePath
  $quotedProcessArguments = Get-ElevatedSymlinkProcessArguments -ScriptPath $PSCommandPath -SourcePath $SourcePath -TargetPath $TargetPath -HardLink:$HardLink

  try {
    $elevatedProcess = Start-Process -FilePath $powerShellExecutable -ArgumentList $quotedProcessArguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
  } catch {
    throw "No se pudo solicitar elevacion para crear el symlink: $($_.Exception.Message)"
  }

  if ($elevatedProcess.ExitCode -ne 0) {
    throw "El proceso elevado finalizo con codigo $($elevatedProcess.ExitCode)."
  }
}

function Invoke-InternalElevatedSymlinkMode {
  if (-not $script:IsElevatedSymlinkMode) {
    return $false
  }

  if ([string]::IsNullOrWhiteSpace($script:ElevatedSymlinkSource) -or [string]::IsNullOrWhiteSpace($script:ElevatedSymlinkTarget)) {
    Write-ErrorLog 'Faltan argumentos requeridos para el modo interno elevado.'
    exit $script:ExitCodeInputError
  }

  try {
    $parentDir = Split-Path -Path $script:ElevatedSymlinkTarget -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
      New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $itemType = if ($script:ElevatedSymlinkHardLink) { $script:LinkTypeHard } else { $script:LinkTypeSymbolic }
    if ($script:ElevatedSymlinkHardLink -and -not (Test-Path -LiteralPath $script:ElevatedSymlinkSource -PathType Leaf)) {
      throw "No se puede crear hard link: el origen '$($script:ElevatedSymlinkSource)' no es un archivo regular."
    }

    New-Item -ItemType $itemType -Path $script:ElevatedSymlinkTarget -Target $script:ElevatedSymlinkSource -Force | Out-Null
  } catch {
    $linkLabel = if ($script:ElevatedSymlinkHardLink) { $script:LinkLabelHard } else { $script:LinkLabelSymbolic }
    Write-ErrorLog "No se pudo crear $linkLabel elevado $($script:ElevatedSymlinkTarget) -> $($script:ElevatedSymlinkSource)"
    Write-ErrorLog $_.Exception.Message
    exit $script:ExitCodeRuntimeError
  }

  exit $script:ExitCodeSuccess
}

# Procesa los enlaces pendientes con una sola solicitud UAC y conserva cada resultado.
function Complete-PendingElevatedSymlinks {
  if ($script:DryRun -or $script:PendingElevatedSymlinks.Count -eq 0) {
    return
  }

  $operations = @($script:PendingElevatedSymlinks.ToArray())
  $script:PendingElevatedSymlinks.Clear()
  $requestPath = $null
  $resultPath = $null
  try {
    $requestPath = [System.IO.Path]::GetTempFileName()
    $resultPath = [System.IO.Path]::GetTempFileName()
    ConvertTo-Json -InputObject $operations -Depth 4 | Set-Content -LiteralPath $requestPath -Encoding UTF8
    $workerPath = Join-Path $PSScriptRoot 'create-symlinks-elevated.ps1'
    $arguments = ConvertTo-WindowsProcessArgumentsString -ArgumentList @(
      '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $workerPath,
      '-RequestPath', $requestPath, '-ResultPath', $resultPath
    )
    Write-Info "Solicitando permisos de administrador una vez para $($operations.Count) enlaces pendientes."
    Set-GroupHeader -GroupPath 'Enlaces con elevacion'
    $process = Start-Process -FilePath (Get-PowerShellExecutablePath) -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
    if ($process.ExitCode -ne 0) {
      throw "El proceso elevado finalizo con codigo $($process.ExitCode)."
    }
    $results = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $results = @($results)
    if ($results.Count -ne $operations.Count) {
      throw 'El proceso elevado no devolvio todos los resultados esperados.'
    }
    for ($index = 0; $index -lt $operations.Count; $index += 1) {
      $operation = $operations[$index]
      $result = $results[$index]
      $linkLabel = if ($operation.HardLink -eq $true) { $script:LinkLabelHard } else { $script:LinkLabelSymbolic }
      if ($result.Success -eq $true) {
        Write-ItemLine -Icon $script:Icons.Created -Label 'creado' -Color Green -Name (Format-DisplayTarget -Path $operation.Target) -Detail (Format-LinkDetail -SourcePath $operation.Source -HardLink ($operation.HardLink -eq $true))
      } else {
        $script:CountErrors += 1
        Add-Diagnostic -Target $operation.Target -Reason $result.Error
        Write-ErrorLog "No se pudo crear $linkLabel $($operation.Target) -> $($operation.Source)"
      }
    }
  } catch {
    foreach ($operation in $operations) {
      $script:CountErrors += 1
      $linkLabel = if ($operation.HardLink -eq $true) { $script:LinkLabelHard } else { $script:LinkLabelSymbolic }
      Add-Diagnostic -Target $operation.Target -Reason "No se pudo completar el lote elevado: $($_.Exception.Message)"
      Write-ErrorLog "No se pudo crear $linkLabel $($operation.Target) -> $($operation.Source)"
    }
  } finally {
    Close-Group
    foreach ($temporaryPath in @($requestPath, $resultPath)) {
      if ($temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

function Test-CommandAvailable {
  param([string]$Name)
  return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-ResolvedCommandCandidates {
  param([Parameter(Mandatory = $true)][string]$CommandName)

  $resolvedCommands = @(Get-Command -Name $CommandName -All -ErrorAction SilentlyContinue)
  $resolvedPaths = [System.Collections.Generic.List[string]]::new()
  $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($resolvedCommand in $resolvedCommands) {
    $candidatePath = if (-not [string]::IsNullOrWhiteSpace($resolvedCommand.Source)) {
      $resolvedCommand.Source
    } elseif (-not [string]::IsNullOrWhiteSpace($resolvedCommand.Path)) {
      $resolvedCommand.Path
    } else {
      $null
    }

    if ([string]::IsNullOrWhiteSpace($candidatePath)) {
      continue
    }

    if ($seenPaths.Add($candidatePath)) {
      $resolvedPaths.Add($candidatePath)
    }
  }

  return @($resolvedPaths)
}

function Get-ResolvedCommandPath {
  param([Parameter(Mandatory = $true)][string]$CommandName)

  $preferredCommandPath = $script:PreferredCommandPaths[$CommandName]
  if (-not [string]::IsNullOrWhiteSpace($preferredCommandPath) -and (Test-Path -LiteralPath $preferredCommandPath)) {
    return $preferredCommandPath
  }

  $resolvedCommand = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
  if ($null -ne $resolvedCommand -and -not [string]::IsNullOrWhiteSpace($resolvedCommand.Source)) {
    return $resolvedCommand.Source
  }

  return $null
}

function Invoke-ExternalCommand {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @()
  )

  $resolvedFilePath = if ([System.IO.Path]::IsPathRooted($FilePath)) {
    $FilePath
  } else {
    $preferredCommandPath = Get-ResolvedCommandPath -CommandName $FilePath
    if (-not [string]::IsNullOrWhiteSpace($preferredCommandPath)) {
      $preferredCommandPath
    } else {
      $FilePath
    }
  }

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $resolvedFilePath
  $startInfo.Arguments = ConvertTo-WindowsProcessArgumentsString -ArgumentList $ArgumentList
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  [void]$process.Start()

  $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
  $standardErrorTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  [System.Threading.Tasks.Task]::WaitAll(@($standardOutputTask, $standardErrorTask))

  $standardOutput = $standardOutputTask.GetAwaiter().GetResult()
  $standardError = $standardErrorTask.GetAwaiter().GetResult()

  $normalizedOutputParts = @($standardOutput.Trim(), $standardError.Trim()) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  $normalizedOutput = [string]::Join([Environment]::NewLine, $normalizedOutputParts)

  return [PSCustomObject]@{
    ExitCode = $process.ExitCode
    Output   = $normalizedOutput.Trim()
  }
}

function Install-WingetPackage {
  param(
    [Parameter(Mandatory = $true)][string]$PackageId,
    [Parameter(Mandatory = $true)][string]$CommandName
  )

  Write-Info "Instalando dependencia requerida '$CommandName' con winget."

  $installResult = Invoke-ExternalCommand -FilePath 'winget' -ArgumentList @(
    'install',
    '-e',
    '--id', $PackageId,
    '--force',
    '--accept-source-agreements',
    '--accept-package-agreements'
  )

  if ($installResult.ExitCode -ne 0) {
    $failureReason = if ([string]::IsNullOrWhiteSpace($installResult.Output)) {
      'winget finalizo con error sin devolver detalles.'
    } else {
      $installResult.Output
    }

    throw "No se pudo instalar '$CommandName' con winget: $failureReason"
  }
}

function Join-UniquePathEntries {
  param([AllowEmptyCollection()][string[]]$RawPathValues)

  $pathEntries = [System.Collections.Generic.List[string]]::new()
  $seenEntries = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($rawPathValue in $RawPathValues) {
    if ([string]::IsNullOrWhiteSpace($rawPathValue)) {
      continue
    }

    foreach ($pathEntry in ($rawPathValue -split ';')) {
      $normalizedEntry = $pathEntry.Trim()
      if ([string]::IsNullOrWhiteSpace($normalizedEntry)) {
        continue
      }

      if ($seenEntries.Add($normalizedEntry)) {
        $pathEntries.Add($normalizedEntry)
      }
    }
  }

  if ($pathEntries.Count -eq 0) {
    return $null
  }

  return [string]::Join(';', $pathEntries)
}

function Update-ProcessPathFromEnvironment {
  # Refresh PATH giving priority to persisted locations so a reinstalled tool
  # can override a broken executable that is still present in the current process PATH.
  $mergedPath = Join-UniquePathEntries -RawPathValues @(
    [Environment]::GetEnvironmentVariable('Path', 'User'),
    [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'Process')
  )

  if (-not [string]::IsNullOrWhiteSpace($mergedPath)) {
    $env:PATH = $mergedPath
  }
}

function Assert-ConfigPathsFileExists {
  if (-not (Test-Path -LiteralPath $script:ConfigPathsFile)) {
    Write-ErrorLog "No se encontro el archivo de configuracion: $script:ConfigPathsFile"
    exit $script:ExitCodeInputError
  }
}

function Test-YqCommandOperational {
  param([string]$CommandPath = 'yq')

  $tempYamlPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("dotfiler-yq-{0}.yml" -f [System.Guid]::NewGuid().ToString('N'))

  try {
    Set-Content -LiteralPath $tempYamlPath -Value "paths: []" -Encoding utf8
    $yqResult = Invoke-ExternalCommand -FilePath $CommandPath -ArgumentList @('eval', '-o=json', '.paths', $tempYamlPath)
    return $yqResult.ExitCode -eq 0
  } finally {
    Remove-Item -LiteralPath $tempYamlPath -Force -ErrorAction SilentlyContinue
  }
}

function Test-CommandOperational {
  param(
    [Parameter(Mandatory = $true)][string]$CommandName,
    [string]$CommandPath = $CommandName
  )

  try {
    if ($CommandName -eq 'yq') {
      return (Test-YqCommandOperational -CommandPath $CommandPath)
    }

    $versionResult = Invoke-ExternalCommand -FilePath $CommandPath -ArgumentList @('--version')
    return $versionResult.ExitCode -eq 0
  } catch {
    return $false
  }
}

function Find-OperationalCommandPath {
  param([Parameter(Mandatory = $true)][string]$CommandName)

  foreach ($candidatePath in (Get-ResolvedCommandCandidates -CommandName $CommandName)) {
    if (Test-CommandOperational -CommandName $CommandName -CommandPath $candidatePath) {
      return $candidatePath
    }
  }

  return $null
}

function Ensure-CommandAvailable {
  param(
    [Parameter(Mandatory = $true)][string]$CommandName,
    [AllowNull()][string]$WingetPackageId
  )

  $operationalCommandPath = Find-OperationalCommandPath -CommandName $CommandName
  if (-not [string]::IsNullOrWhiteSpace($operationalCommandPath)) {
    $script:PreferredCommandPaths[$CommandName] = $operationalCommandPath
    return
  }

  if ([string]::IsNullOrWhiteSpace($WingetPackageId)) {
    throw "El comando requerido '$CommandName' no esta disponible en PATH."
  }

  if (-not (Test-CommandAvailable -Name 'winget')) {
    throw "Falta el comando requerido '$CommandName' y no se encontro 'winget' para instalarlo automaticamente."
  }

  if ($script:DryRun) {
    Write-Warn "El modo --dry-run no evita la instalacion automatica de dependencias. Se instalara '$CommandName' antes de continuar con la simulacion."
  }

  Install-WingetPackage -PackageId $WingetPackageId -CommandName $CommandName
  Update-ProcessPathFromEnvironment

  $operationalCommandPath = Find-OperationalCommandPath -CommandName $CommandName
  if ([string]::IsNullOrWhiteSpace($operationalCommandPath) -and -not (Test-CommandAvailable -Name $CommandName)) {
    throw "La instalacion de '$CommandName' finalizo, pero el comando sigue sin estar disponible en PATH."
  }

  if ([string]::IsNullOrWhiteSpace($operationalCommandPath)) {
    throw "La instalacion de '$CommandName' finalizo, pero el comando no se puede ejecutar correctamente."
  }

  $script:PreferredCommandPaths[$CommandName] = $operationalCommandPath
}

function Ensure-DotfilerDependencies {
  try {
    Ensure-CommandAvailable -CommandName 'yq' -WingetPackageId 'MikeFarah.yq'
    Ensure-CommandAvailable -CommandName 'jq' -WingetPackageId 'jqlang.jq'
  } catch {
    Write-ErrorLog $_.Exception.Message
    exit $script:ExitCodeInputError
  }
}

function Get-YamlPathsJson {
  Assert-ConfigPathsFileExists

  $validationResult = Invoke-ExternalCommand -FilePath 'yq' -ArgumentList @('eval', '.paths', $script:ConfigPathsFile)
  if ($validationResult.ExitCode -ne 0) {
    Write-ErrorLog "Configuracion invalida en ${script:ConfigPathsFile}: no se pudo interpretar YAML."
    exit $script:ExitCodeInputError
  }

  $pathsJsonResult = Invoke-ExternalCommand -FilePath 'yq' -ArgumentList @('eval', '-o=json', '.paths', $script:ConfigPathsFile)
  if ($pathsJsonResult.ExitCode -ne 0) {
    Write-ErrorLog "Configuracion invalida en ${script:ConfigPathsFile}: no se pudo interpretar YAML."
    exit $script:ExitCodeInputError
  }

  return $pathsJsonResult.Output
}

function Test-JsonArray {
  param([Parameter(Mandatory = $true)][string]$JsonText)

  $tempFilePath = [System.IO.Path]::GetTempFileName()

  try {
    Set-Content -LiteralPath $tempFilePath -Value $JsonText -Encoding utf8
    $jqResult = Invoke-ExternalCommand -FilePath 'jq' -ArgumentList @('-e', 'type == "array"', $tempFilePath)
    return $jqResult.ExitCode -eq 0
  } finally {
    Remove-Item -LiteralPath $tempFilePath -Force -ErrorAction SilentlyContinue
  }
}

function Add-Diagnostic {
  param(
    [string]$Target,
    [string]$Reason
  )

  $script:Diagnostics.Add([PSCustomObject]@{
      Target = $Target
      Reason = $Reason
    })
}

function Get-RepoRoot {
  if (-not (Test-CommandAvailable -Name 'git')) {
    Write-ErrorLog "El comando requerido 'git' no esta disponible en PATH."
    exit $script:ExitCodeInputError
  }

  $gitOutput = & git rev-parse --show-toplevel 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-ErrorLog "Este script debe ejecutarse dentro de un repositorio Git valido."
    exit $script:ExitCodeInputError
  }

  return ($gitOutput | Select-Object -First 1).Trim()
}

function Normalize-Separators {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $Path
  }

  return $Path.Replace('/', '\')
}

function Expand-UserPath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $Path
  }

  $expanded = $Path
  if ($expanded -eq '~') {
    $expanded = $script:HomeDir
  } elseif ($expanded.StartsWith('~/')) {
    $expanded = Join-Path -Path $script:HomeDir -ChildPath ($expanded.Substring(2))
  } elseif ($expanded.StartsWith('~\')) {
    $expanded = Join-Path -Path $script:HomeDir -ChildPath ($expanded.Substring(2))
  }

  $expanded = $expanded.Replace('$HOME', $script:HomeDir)
  $expanded = $expanded.Replace('$DOCUMENTS', $script:DocumentsDir)
  $expanded = $expanded.Replace('$USER', $script:WindowsUser)

  return (Normalize-Separators -Path $expanded)
}

function Resolve-SourcePattern {
  param([string]$Path)

  $expanded = Expand-UserPath -Path $Path
  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return $expanded
  }

  return (Join-Path -Path $script:ConfigsDir -ChildPath (Normalize-Separators -Path $expanded))
}

function Resolve-TargetBase {
  param([AllowNull()][string]$Target)

  if ([string]::IsNullOrWhiteSpace($Target)) {
    return $script:HomeDir
  }

  $expanded = Expand-UserPath -Path $Target

  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return $expanded
  }

  return (Join-Path -Path $script:HomeDir -ChildPath (Normalize-Separators -Path $expanded))
}

function Get-TextPropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }

  return [string]$property.Value
}

function Test-PropertyPresent {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $false
  }

  return $null -ne $Object.PSObject.Properties[$Name]
}

function Test-ConflictingTargetDefinition {
  param([object]$Object)

  return (Test-PropertyPresent -Object $Object -Name 'target') -and
    (Test-PropertyPresent -Object $Object -Name 'exactTarget')
}

function Get-SelectedTargetDefinition {
  param([object]$Entry)

  $override = Get-OverrideTarget -Entry $Entry
  if ($null -ne $override) {
    return $override
  }

  return [PSCustomObject]@{
    UsesExactTarget = $null -ne $Entry.PSObject.Properties['exactTarget']
    ConfiguredTarget = if ($null -ne $Entry.PSObject.Properties['exactTarget']) {
      [string]$Entry.exactTarget
    } else {
      [string]$Entry.target
    }
  }
}

function Test-PlatformMatch {
  param([object]$Config)

  if ($null -eq $Config) {
    return $false
  }

  foreach ($platformAlias in @('win32', 'windows')) {
    $platformFlag = $Config.PSObject.Properties[$platformAlias]
    if ($null -ne $platformFlag) {
      return [bool]$platformFlag.Value
    }
  }

  $platform = $Config.PSObject.Properties['platform']
  if ($null -ne $platform) {
    return $platform.Value -eq 'win32'
  }

  return $false
}

function Get-PropertyArray {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return @()
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property -or $null -eq $property.Value) {
    return @()
  }

  return @($property.Value)
}

function Test-EntryIncluded {
  param([object]$Entry)

  $excludeFor = @(Get-PropertyArray -Object $Entry -Name 'excludeFor')
  foreach ($item in $excludeFor) {
    if (Test-PlatformMatch -Config $item) {
      return $false
    }
  }

  $onlyFor = @(Get-PropertyArray -Object $Entry -Name 'onlyFor')
  if ($onlyFor.Count -gt 0) {
    foreach ($item in $onlyFor) {
      if (Test-PlatformMatch -Config $item) {
        return $true
      }
    }
    return $false
  }

  return $true
}

function Get-OverrideTarget {
  param([object]$Entry)

  foreach ($override in @(Get-PropertyArray -Object $Entry -Name 'overrides')) {
    if (Test-PlatformMatch -Config $override) {
      if (Test-ConflictingTargetDefinition -Object $override) {
        throw 'Configuración inválida: un override no puede definir target y exactTarget al mismo tiempo.'
      }

      $exactTargetValue = Get-TextPropertyValue -Object $override -Name 'exactTarget'
      if ($null -ne $exactTargetValue) {
        return [PSCustomObject]@{
          UsesExactTarget = $true
          ConfiguredTarget = $exactTargetValue
        }
      }

      return [PSCustomObject]@{
        UsesExactTarget = $false
        ConfiguredTarget = [string]$override.target
      }
    }
  }

  return $null
}

function Test-GlobPattern {
  param([string]$Path)
  return $Path.IndexOfAny([char[]]'*?[') -ge 0
}

function ConvertTo-StrippedRegexPattern {
  param([string]$Pattern)

  if ([string]::IsNullOrEmpty($Pattern)) {
    return $null
  }

  $stripped = $Pattern
  if ($stripped.Length -ge 2 -and $stripped.StartsWith('/') -and $stripped.EndsWith('/')) {
    $stripped = $stripped.Substring(1, $stripped.Length - 2)
  }

  try {
    return [regex]::new($stripped)
  } catch {
    throw "Patron regex invalido '$Pattern': $($_.Exception.Message)"
  }
}

function Get-DescendIntoRegex {
  param([object]$Entry)

  $value = Get-TextPropertyValue -Object $Entry -Name 'descendInto'
  if ([string]::IsNullOrEmpty($value)) {
    return $null
  }

  return (ConvertTo-StrippedRegexPattern -Pattern $value)
}

function Get-MarkerFileName {
  param([object]$Entry)

  $value = Get-TextPropertyValue -Object $Entry -Name 'markerFile'
  if ([string]::IsNullOrEmpty($value)) {
    return $null
  }

  return $value
}

function Get-ExcludeRegex {
  param([object]$Entry)

  $value = Get-TextPropertyValue -Object $Entry -Name 'exclude'
  if ([string]::IsNullOrEmpty($value)) {
    return $null
  }

  return (ConvertTo-StrippedRegexPattern -Pattern $value)
}

function Resolve-ConditionPath {
  param([string]$Path)

  $expanded = Expand-UserPath -Path $Path
  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return $expanded
  }

  return (Join-Path -Path $script:HomeDir -ChildPath $expanded)
}

function Test-ConditionPathExists {
  param([string]$Path)

  $resolvedPath = Resolve-ConditionPath -Path $Path
  return (Test-PathEntry -Path $resolvedPath)
}

function Join-RegexPatterns {
  param([AllowNull()][regex[]]$Patterns)

  $combined = $null
  foreach ($pattern in @($Patterns)) {
    if ($null -eq $pattern) {
      continue
    }
    if ($null -eq $combined) {
      $combined = $pattern.ToString()
    } else {
      $combined = "($combined)|($($pattern.ToString()))"
    }
  }

  if ($null -eq $combined) {
    return $null
  }

  return [regex]::new($combined)
}

# Returns the `conditionalExcludes` rules active on this machine as objects
# with the compiled regex and the `whenPathExists` that activated them.
function Get-ActiveConditionalExcludeRules {
  param([object]$Entry)

  $activeRules = [System.Collections.Generic.List[object]]::new()
  foreach ($rule in @(Get-PropertyArray -Object $Entry -Name 'conditionalExcludes')) {
    $patternText = Get-TextPropertyValue -Object $rule -Name 'pattern'
    $conditionPath = Get-TextPropertyValue -Object $rule -Name 'whenPathExists'
    if ([string]::IsNullOrEmpty($patternText) -or [string]::IsNullOrEmpty($conditionPath)) {
      continue
    }

    $pattern = ConvertTo-StrippedRegexPattern -Pattern $patternText
    if (Test-ConditionPathExists -Path $conditionPath) {
      $activeRules.Add([PSCustomObject]@{ Regex = $pattern; ConditionPath = $conditionPath }) | Out-Null
    }
  }

  return $activeRules.ToArray()
}

function Get-ConditionalExcludeRegex {
  param([object]$Entry)

  $activeRules = @(Get-ActiveConditionalExcludeRules -Entry $Entry)
  return (Join-RegexPatterns -Patterns @($activeRules | ForEach-Object { $_.Regex }))
}

# Returns the `whenPathExists` of the first active rule matching the item or
# one of its grouping folders below the glob root.
function Get-ConditionalExcludeReason {
  param(
    [object[]]$ActiveRules,
    [string]$RootPath,
    [string]$ItemPath
  )

  $relativePath = $ItemPath
  if ($ItemPath.StartsWith($RootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    $relativePath = $ItemPath.Substring($RootPath.Length)
  }
  $segments = @($relativePath -split '[\\/]' | Where-Object { $_ -ne '' })

  foreach ($rule in @($ActiveRules)) {
    foreach ($segment in $segments) {
      if ($rule.Regex.IsMatch($segment)) {
        return $rule.ConditionPath
      }
    }
  }

  return ''
}

function Test-FolderShouldDescend {
  param(
    [string]$Name,
    [AllowNull()][regex]$DescendIntoRegex
  )

  if ($null -eq $DescendIntoRegex) {
    return $false
  }

  return $DescendIntoRegex.IsMatch($Name)
}

function Test-FolderExcluded {
  param(
    [string]$Name,
    [AllowNull()][regex]$ExcludeRegex
  )

  if ($null -eq $ExcludeRegex) {
    return $false
  }

  return $ExcludeRegex.IsMatch($Name)
}

function Test-LeafHasMarkerFile {
  param(
    [string]$Path,
    [AllowNull()][string]$MarkerFile
  )

  if ([string]::IsNullOrEmpty($MarkerFile)) {
    return $true
  }

  return (Test-Path -LiteralPath (Join-Path -Path $Path -ChildPath $MarkerFile) -PathType Leaf)
}

function Get-FlattenedEmissionsRecursive {
  param(
    [string]$RootPath,
    [AllowNull()][regex]$DescendIntoRegex,
    [AllowNull()][regex]$ExcludeRegex,
    [AllowNull()][string]$MarkerFile
  )

  $results = [System.Collections.Generic.List[object]]::new()
  if ([string]::IsNullOrWhiteSpace($RootPath) -or -not (Test-Path -LiteralPath $RootPath)) {
    return $results.ToArray()
  }

  $stack = [System.Collections.Generic.Stack[string]]::new()
  $stack.Push($RootPath)

  while ($stack.Count -gt 0) {
    $current = $stack.Pop()
    $children = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($child in $children) {
      $name = $child.Name
      if (Test-FolderExcluded -Name $name -ExcludeRegex $ExcludeRegex) {
        continue
      }

      if (-not $child.PSIsContainer) {
        $results.Add($child) | Out-Null
        continue
      }

      if (Test-FolderShouldDescend -Name $name -DescendIntoRegex $DescendIntoRegex) {
        $stack.Push($child.FullName)
        continue
      }

      if (Test-LeafHasMarkerFile -Path $child.FullName -MarkerFile $MarkerFile) {
        $results.Add($child) | Out-Null
      }
    }
  }

  return @($results | Sort-Object FullName)
}

function Get-ResolvedSources {
  param(
    [string]$OriginalPath,
    [AllowNull()][regex]$DescendIntoRegex = $null,
    [AllowNull()][regex]$ExcludeRegex = $null,
    [AllowNull()][string]$MarkerFile = $null
  )

  $pattern = Resolve-SourcePattern -Path $OriginalPath
  if (Test-GlobPattern -Path $OriginalPath) {
    if ($null -ne $DescendIntoRegex) {
      $rootPath = Split-Path -Path $pattern -Parent
      return @(Get-FlattenedEmissionsRecursive -RootPath $rootPath -DescendIntoRegex $DescendIntoRegex -ExcludeRegex $ExcludeRegex -MarkerFile $MarkerFile)
    }

    $items = @(Get-ChildItem -Path $pattern -Force -ErrorAction SilentlyContinue | Sort-Object Name)

    if ($null -eq $ExcludeRegex -and [string]::IsNullOrEmpty($MarkerFile)) {
      return $items
    }

    $filtered = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $items) {
      if (Test-FolderExcluded -Name $item.Name -ExcludeRegex $ExcludeRegex) {
        continue
      }
      if ($item.PSIsContainer -and -not (Test-LeafHasMarkerFile -Path $item.FullName -MarkerFile $MarkerFile)) {
        continue
      }
      $filtered.Add($item) | Out-Null
    }
    return @($filtered)
  }

  if (-not (Test-Path -LiteralPath $pattern)) {
    return @()
  }

  return @((Get-Item -LiteralPath $pattern -Force))
}

function Resolve-BackupPath {
  param([string]$Target)

  $candidate = "$Target.bak"
  $index = 1
  while (Test-PathEntry -Path $candidate) {
    $candidate = "$Target.bak.$index"
    $index += 1
  }

  return $candidate
}

function Remove-ExistingSymlink {
  param([string]$Path)

  if ($script:DryRun) {
    return
  }

  Remove-Item -LiteralPath $Path -Force
}

function Move-ToBackup {
  param([string]$Path)

  $backupPath = Resolve-BackupPath -Target $Path
  if ($script:DryRun) {
    $script:CountPlannedBackups += 1
  } else {
    Move-Item -LiteralPath $Path -Destination $backupPath -Force
    $script:CountBackups += 1
  }

  Write-ItemLine -Icon $script:Icons.Backup -Label 'respaldo' -Color Yellow -Name (Split-Path -Path $Path -Leaf) -Detail "→ $(Split-Path -Path $backupPath -Leaf)"
  return $backupPath
}

function Get-PathEntry {
  param([string]$Path)

  return Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Test-PathEntry {
  param([string]$Path)

  return $null -ne (Get-PathEntry -Path $Path)
}

function Test-SymlinkPointsToSource {
  param(
    [string]$LinkPath,
    [string]$SourcePath
  )

  $resolvedLinkTarget = Get-SymlinkResolvedTarget -LinkPath $LinkPath
  if ($null -eq $resolvedLinkTarget) {
    return $false
  }

  $resolvedSource = [System.IO.Path]::GetFullPath($SourcePath)
  return [string]::Equals($resolvedLinkTarget.TrimEnd('\', '/'), $resolvedSource.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-SymlinkResolvedTarget {
  param([string]$LinkPath)

  if (-not (Test-IsSymlink -Path $LinkPath)) {
    return $null
  }

  $linkTarget = @((Get-PathEntry -Path $LinkPath).Target) | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($linkTarget)) {
    return $null
  }

  $linkDirectory = Split-Path -Path $LinkPath -Parent
  return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($linkDirectory, $linkTarget))
}

function Test-PathInsideConfigsDir {
  param([AllowNull()][string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($script:ConfigsDir)) {
    return $false
  }

  $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  $resolvedConfigsDir = [System.IO.Path]::GetFullPath($script:ConfigsDir).TrimEnd('\', '/')
  return [string]::Equals($resolvedPath, $resolvedConfigsDir, [System.StringComparison]::OrdinalIgnoreCase) -or
    $resolvedPath.StartsWith($resolvedConfigsDir + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

# Replaces a directory symlink left by a previous run (pointing inside the
# repository configs) with a real directory, and refuses to create links in a
# destination that still resolves inside the repository.
function Initialize-TargetDirectory {
  param([string]$DirectoryPath)

  $resolvedLinkTarget = Get-SymlinkResolvedTarget -LinkPath $DirectoryPath
  if ($null -ne $resolvedLinkTarget -and (Test-PathInsideConfigsDir -Path $resolvedLinkTarget)) {
    $replacementDetail = "(antes symlink a $(Format-DisplaySource -Path $resolvedLinkTarget))"
    if ($script:DryRun) {
      if ($script:PlannedDirectoryReplacements.Add($DirectoryPath)) {
        $script:CountPlannedRemoved += 1
        Write-ItemLine -Icon $script:Icons.Directory -Label 'carpeta real' -Color Blue -Name (Split-Path -Path $DirectoryPath -Leaf) -Detail $replacementDetail
      }
      return
    }

    # Directory.Delete on a link removes only the link, never the linked content.
    [System.IO.Directory]::Delete($DirectoryPath)
    $script:CountRemoved += 1
    Write-ItemLine -Icon $script:Icons.Directory -Label 'carpeta real' -Color Blue -Name (Split-Path -Path $DirectoryPath -Leaf) -Detail $replacementDetail
    return
  }

  if ($script:DryRun -and $script:PlannedDirectoryReplacements.Contains($DirectoryPath)) {
    return
  }

  $existingDirectory = Get-PathEntry -Path $DirectoryPath
  if ($null -ne $existingDirectory) {
    $resolvedDirectory = if ($null -ne $resolvedLinkTarget) { $resolvedLinkTarget } else { $existingDirectory.FullName }
    if (Test-PathInsideConfigsDir -Path $resolvedDirectory) {
      throw "El directorio destino resuelve dentro del repositorio: $DirectoryPath"
    }
  }
}

function Remove-StaleSymlink {
  param(
    [string]$SourcePath,
    [string]$TargetPath,
    [string]$Reason = ''
  )

  $removalDetail = if ([string]::IsNullOrEmpty($Reason)) { '(excluido por condicion)' } else { "(excluido por $Reason)" }

  try {
    if (-not (Test-SymlinkPointsToSource -LinkPath $TargetPath -SourcePath $SourcePath)) {
      return
    }

    if ($script:DryRun) {
      $script:CountPlannedRemoved += 1
    } else {
      Remove-Item -LiteralPath $TargetPath -Force
      $script:CountRemoved += 1
    }
    Write-ItemLine -Icon $script:Icons.Delete -Label 'eliminado' -Color Red -Name (Split-Path -Path $TargetPath -Leaf) -Detail $removalDetail
  } catch {
    $script:CountErrors += 1
    Add-Diagnostic -Target $TargetPath -Reason "Fallo al eliminar symlink excluido por condicion: $($_.Exception.Message)"
    Write-ErrorLog "No se pudo eliminar symlink excluido por condicion $TargetPath"
  }
}

function Test-IsSymlink {
  param([string]$Path)

  $item = Get-PathEntry -Path $Path
  if ($null -eq $item) {
    return $false
  }

  return ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function New-DotfileSymlink {
  param(
    [string]$SourcePath,
    [string]$TargetPath,
    [bool]$HardLink = $false
  )

  $startedAt = Get-Date
  $linkItemType = if ($HardLink) { $script:LinkTypeHard } else { $script:LinkTypeSymbolic }
  $linkLabel = if ($HardLink) { $script:LinkLabelHard } else { $script:LinkLabelSymbolic }

  try {
    if ($HardLink -and -not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
      throw "No se puede crear hard link: el origen '$SourcePath' no es un archivo regular."
    }

    $itemName = Split-Path -Path $TargetPath -Leaf
    $linkDetail = Format-LinkDetail -SourcePath $SourcePath -HardLink $HardLink
    $parentDir = Split-Path -Path $TargetPath -Parent
    if ([string]::IsNullOrWhiteSpace($parentDir)) {
      $parentDir = '.'
    }

    Initialize-TargetDirectory -DirectoryPath $parentDir
    # In dry-run the directory symlink is still in place, so existing entries
    # would be read through it; the replaced directory will start empty.
    $targetDirectoryPendingReplacement = $script:DryRun -and $script:PlannedDirectoryReplacements.Contains($parentDir)

    # Symlinks already pointing to the source are left untouched. Hard links
    # are always recreated: Windows has no cheap inode comparison.
    if (-not $targetDirectoryPendingReplacement -and -not $HardLink -and (Test-SymlinkPointsToSource -LinkPath $TargetPath -SourcePath $SourcePath)) {
      $script:CountUnchanged += 1
      $script:GroupUnchangedCount += 1
      if ($script:VerboseMode) {
        Write-ItemLine -Icon $script:Icons.Unchanged -Label 'sin cambios' -Color DarkGray -Name $itemName -Detail $linkDetail -Unchanged
      }
      return
    }

    if (-not $targetDirectoryPendingReplacement -and (Test-IsSymlink -Path "$TargetPath.bak")) {
      Remove-ExistingSymlink -Path "$TargetPath.bak"
      if ($script:DryRun) {
        $script:CountPlannedRemoved += 1
      } else {
        $script:CountRemoved += 1
      }
      Write-ItemLine -Icon $script:Icons.Delete -Label 'eliminado' -Color Red -Name "$itemName.bak" -Detail '(symlink de respaldo obsoleto)'
    }

    $isReplacement = $false
    if ($targetDirectoryPendingReplacement) {
      $script:CountPlannedCreated += 1
    } elseif (Test-IsSymlink -Path $TargetPath) {
      Remove-ExistingSymlink -Path $TargetPath
      $isReplacement = $true
      if ($script:DryRun) {
        $script:CountPlannedReplaced += 1
      } else {
        $script:CountReplaced += 1
      }
    } elseif (Test-PathEntry -Path $TargetPath) {
      [void](Move-ToBackup -Path $TargetPath)
      $isReplacement = $true
      if ($script:DryRun) {
        $script:CountPlannedReplaced += 1
      } else {
        $script:CountReplaced += 1
      }
    } else {
      if ($script:DryRun) {
        $script:CountPlannedCreated += 1
      } else {
        $script:CountCreated += 1
      }
    }

    $actionIcon = if ($isReplacement) { $script:Icons.Replaced } else { $script:Icons.Created }
    $actionLabel = if ($isReplacement) { 'reemplazado' } else { 'creado' }
    $actionColor = if ($isReplacement) { [ConsoleColor]::Blue } else { [ConsoleColor]::Green }

    if ($script:DryRun) {
      Write-ItemLine -Icon $actionIcon -Label $actionLabel -Color $actionColor -Name $itemName -Detail $linkDetail
    } else {
      if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
      }

      try {
        New-Item -ItemType $linkItemType -Path $TargetPath -Target $SourcePath -Force | Out-Null
        Write-ItemLine -Icon $actionIcon -Label $actionLabel -Color $actionColor -Name $itemName -Detail $linkDetail
      } catch {
        if (-not (Test-IsPrivilegeElevationError -ErrorRecord $_) -or $script:IsElevatedSymlinkMode) {
          throw
        }

        if (-not (Test-ElevationTargetAllowed -TargetPath $TargetPath)) {
          throw "Auto-elevacion bloqueada: el destino '$TargetPath' esta fuera de las rutas permitidas."
        }
        $script:PendingElevatedSymlinks.Add([PSCustomObject]@{ Source = $SourcePath; Target = $TargetPath; HardLink = $HardLink })
        Write-ItemLine -Icon $script:Icons.Elevated -Label 'pendiente' -Color Yellow -Name $itemName -Detail '(requiere elevacion)'
      }
    }

    if ($script:VerboseMode -and -not $script:Quiet) {
      $elapsed = [int]((Get-Date) - $startedAt).TotalSeconds
      Write-BoxRow -Content ("   " + (Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.Time)transcurrido=${elapsed}s" -Color DarkGray))
    }
  } catch {
    $script:CountErrors += 1
    Add-Diagnostic -Target $TargetPath -Reason $_.Exception.Message
    Write-ErrorLog "No se pudo crear $linkLabel $TargetPath -> $SourcePath"
  }
}

function Get-ConfigEntries {
  $pathsJson = Get-YamlPathsJson

  if (-not (Test-JsonArray -JsonText $pathsJson)) {
    Write-ErrorLog "Configuracion invalida en ${script:ConfigPathsFile}: 'paths' debe ser un arreglo."
    exit $script:ExitCodeInputError
  }

  try {
    $entries = ConvertFrom-Json -InputObject $pathsJson
  } catch {
    Write-ErrorLog "Configuracion invalida en ${script:ConfigPathsFile}: no se pudo convertir JSON."
    exit $script:ExitCodeInputError
  }

  return @($entries)
}

function Test-PathEndsWithGlobStar {
  param([string]$Path)

  if ([string]::IsNullOrEmpty($Path)) {
    return $false
  }

  return $Path.EndsWith('/*') -or $Path.EndsWith('\*')
}

# Builds removal operations for symlinks left by previous runs whose sources are
# now excluded by an active `conditionalExcludes` rule. Only symlinks pointing
# to that exact source are removed; regular files are never touched.
function Get-StaleSymlinkRemovals {
  param(
    [string]$EntryPath,
    [string]$TargetBase,
    [object[]]$LinkedSources,
    [System.Collections.Generic.HashSet[string]]$SeenBasenames,
    [AllowNull()][regex]$DescendIntoRegex,
    [AllowNull()][regex]$ExcludeRegex,
    [AllowNull()][string]$MarkerFile,
    [object[]]$ActiveRules = @()
  )

  $rootPath = Split-Path -Path (Resolve-SourcePattern -Path $EntryPath) -Parent
  $linkedPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($linkedSource in @($LinkedSources)) {
    [void]$linkedPaths.Add($linkedSource.FullName)
  }

  $removals = [System.Collections.Generic.List[object]]::new()
  $candidates = @(Get-ResolvedSources -OriginalPath $EntryPath -DescendIntoRegex $DescendIntoRegex -ExcludeRegex $ExcludeRegex -MarkerFile $MarkerFile)
  foreach ($candidate in $candidates) {
    if ($linkedPaths.Contains($candidate.FullName) -or $SeenBasenames.Contains($candidate.Name)) {
      continue
    }

    $targetPath = Join-Path -Path $TargetBase -ChildPath $candidate.Name
    if (-not (Test-SymlinkPointsToSource -LinkPath $targetPath -SourcePath $candidate.FullName)) {
      continue
    }

    $removals.Add([PSCustomObject]@{
        Group    = (Split-Path -Path $targetPath -Parent)
        Source   = $candidate.FullName
        Target   = $targetPath
        HardLink = $false
        Remove   = $true
        Reason   = (Get-ConditionalExcludeReason -ActiveRules $ActiveRules -RootPath $rootPath -ItemPath $candidate.FullName)
      })
  }

  return $removals.ToArray()
}

function Resolve-Operations {
  $operations = [System.Collections.Generic.List[object]]::new()
  $entries = @(Get-ConfigEntries)
  $resolveStartedAt = Get-Date
  $entryIndex = 0

  foreach ($entry in $entries) {
    $entryIndex += 1
    $elapsedSeconds = [int]((Get-Date) - $resolveStartedAt).TotalSeconds
    Write-DotfilerProgress -Id 1 -Current $entryIndex -Total $entries.Count -Status (Get-ResolveProgressStatus -Current $entryIndex -Total $entries.Count -Detail ([string]$entry.path) -ElapsedSeconds $elapsedSeconds)

    if (-not (Test-EntryIncluded -Entry $entry)) {
      continue
    }

    if (Test-ConflictingTargetDefinition -Object $entry) {
      $script:CountErrors += 1
      Add-Diagnostic -Target ([string]$entry.path) -Reason 'Configuración inválida: no se permite definir target y exactTarget al mismo tiempo.'
      Write-Warn "Configuración inválida: no se permite definir target y exactTarget al mismo tiempo en $($entry.path)"
      continue
    }

    try {
      $selectedTargetDefinition = Get-SelectedTargetDefinition -Entry $entry
    } catch {
      $script:CountErrors += 1
      Add-Diagnostic -Target ([string]$entry.path) -Reason $_.Exception.Message
      Write-Warn "$($_.Exception.Message) Ruta: $($entry.path)"
      continue
    }

    $selectedTarget = $selectedTargetDefinition.ConfiguredTarget

    if (-not [string]::IsNullOrWhiteSpace($selectedTarget) -and $selectedTarget -match '^[A-Za-z]+://') {
      Write-Warn "Se omite target invalido para dotfiler.ps1: $selectedTarget"
      continue
    }

    $entryPath = [string]$entry.path
    $descendIntoRegex = $null
    $excludeRegex = $null
    $conditionalExcludeRegex = $null
    $activeConditionalRules = @()
    $markerFile = $null
    $hasFilters = $false

    try {
      $descendIntoRegex = Get-DescendIntoRegex -Entry $entry
      $excludeRegex = Get-ExcludeRegex -Entry $entry
      $activeConditionalRules = @(Get-ActiveConditionalExcludeRules -Entry $entry)
      $conditionalExcludeRegex = Join-RegexPatterns -Patterns @($activeConditionalRules | ForEach-Object { $_.Regex })
      $markerFile = Get-MarkerFileName -Entry $entry
      $hasFilters = ($null -ne $descendIntoRegex) -or ($null -ne $excludeRegex) -or (-not [string]::IsNullOrEmpty($markerFile)) -or
        (Test-PropertyPresent -Object $entry -Name 'conditionalExcludes')
    } catch {
      $script:CountErrors += 1
      Add-Diagnostic -Target $entryPath -Reason $_.Exception.Message
      Write-Warn "$($_.Exception.Message) Ruta: $entryPath"
      continue
    }

    if ($hasFilters -and -not (Test-PathEndsWithGlobStar -Path $entryPath)) {
      Write-Warn "descendInto/markerFile/exclude/conditionalExcludes solo aplican con path terminado en '/*'. Ignorando filtros para: $entryPath"
      $descendIntoRegex = $null
      $excludeRegex = $null
      $conditionalExcludeRegex = $null
      $markerFile = $null
    }

    if ($selectedTargetDefinition.UsesExactTarget) {
      $conditionalExcludeRegex = $null
    }

    $effectiveExcludeRegex = Join-RegexPatterns -Patterns @($excludeRegex, $conditionalExcludeRegex)
    $targetBase = Resolve-TargetBase -Target $selectedTarget

    $sources = @(Get-ResolvedSources -OriginalPath $entryPath -DescendIntoRegex $descendIntoRegex -ExcludeRegex $effectiveExcludeRegex -MarkerFile $markerFile)
    if ($sources.Count -eq 0) {
      if (Test-GlobPattern -Path $entryPath) {
        Write-Warn "El patron no produjo resultados: $entryPath"
      } else {
        $script:CountErrors += 1
        Add-Diagnostic -Target $targetBase -Reason "Ruta de origen inexistente: $entryPath"
        Write-Warn "Ruta de origen invalida o inexistente: $entryPath"
      }
      continue
    }

    if ($selectedTargetDefinition.UsesExactTarget -and (Test-GlobPattern -Path $entryPath)) {
      $script:CountErrors += 1
      Add-Diagnostic -Target $targetBase -Reason "exactTarget no admite patrones wildcard: $entryPath"
      Write-Warn "No se permite exactTarget con patrones wildcard: $entryPath"
      continue
    }

    $seenBasenames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($sourceItem in $sources) {
      $targetPath = if ($selectedTargetDefinition.UsesExactTarget) {
        $targetBase
      } else {
        Join-Path -Path $targetBase -ChildPath $sourceItem.Name
      }

      if (-not $selectedTargetDefinition.UsesExactTarget) {
        if (-not $seenBasenames.Add($sourceItem.Name)) {
          $script:CountErrors += 1
          Add-Diagnostic -Target $targetPath -Reason "Colision de basename para '$($sourceItem.Name)' (primero gana, segundo descartado): $entryPath"
          Write-Warn "Colision de basename '$($sourceItem.Name)' para $entryPath. Conservando el primer source, descartando $($sourceItem.FullName)."
          continue
        }
      }

      $operations.Add([PSCustomObject]@{
          Group    = (Split-Path -Path $targetPath -Parent)
          Source   = $sourceItem.FullName
          Target   = $targetPath
          HardLink = ($entry.hardLink -eq $true)
          Remove   = $false
        })
    }

    if ($null -ne $conditionalExcludeRegex) {
      foreach ($removal in @(Get-StaleSymlinkRemovals -EntryPath $entryPath -TargetBase $targetBase -LinkedSources $sources -SeenBasenames $seenBasenames -DescendIntoRegex $descendIntoRegex -ExcludeRegex $excludeRegex -MarkerFile $markerFile -ActiveRules $activeConditionalRules)) {
        $operations.Add($removal)
      }
    }
  }

  Complete-DotfilerProgress -Id 1
  return $operations
}

function Format-SummaryCell {
  param(
    [string]$Icon,
    [string]$Label,
    [int]$Value
  )

  return ('{0}{1} {2,4}' -f (Get-IconPrefix $Icon), $Label.PadRight($script:SummaryLabelWidth), $Value)
}

function Print-Summary {
  $elapsed = [int]((Get-Date) - $script:StartTime).TotalSeconds
  $created = if ($script:DryRun) { $script:CountPlannedCreated } else { $script:CountCreated }
  $replaced = if ($script:DryRun) { $script:CountPlannedReplaced } else { $script:CountReplaced }
  $backups = if ($script:DryRun) { $script:CountPlannedBackups } else { $script:CountBackups }
  $removed = if ($script:DryRun) { $script:CountPlannedRemoved } else { $script:CountRemoved }
  $columnGap = '     '
  $modeText = if ($script:DryRun) {
    "$(Get-IconPrefix $script:Icons.DryRun)simulacion, no se escribieron cambios"
  } else {
    "$(Get-IconPrefix $script:Icons.RealRun)aplicacion real"
  }
  $errorsCell = Format-SummaryCell -Icon $script:Icons.Error -Label 'errores' -Value $script:CountErrors
  if ($script:CountErrors -gt 0) {
    $errorsCell = Format-AnsiSegment -Text $errorsCell -Color Red -Bold
  }
  $statusText = if ($script:CountErrors -eq 0) {
    Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.Done)Sin errores." -Color Green -Bold
  } else {
    Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.Failed)Finalizado con $($script:CountErrors) error(es)." -Color Red -Bold
  }

  Write-BlockGap
  Write-BoxTop -Title "$(Get-IconPrefix $script:Icons.Summary)Resumen"
  Write-BoxRow -Content ((Format-AnsiSegment -Text (Format-SummaryCell -Icon $script:Icons.Created -Label 'creados' -Value $created) -Color Green -Bold) + $columnGap + (Format-AnsiSegment -Text (Format-SummaryCell -Icon $script:Icons.Replaced -Label 'reemplazados' -Value $replaced) -Color Blue -Bold))
  Write-BoxRow -Content ((Format-SummaryCell -Icon $script:Icons.Unchanged -Label 'sin cambios' -Value $script:CountUnchanged) + $columnGap + (Format-SummaryCell -Icon $script:Icons.Delete -Label 'eliminados' -Value $removed))
  Write-BoxRow -Content ((Format-SummaryCell -Icon $script:Icons.Backup -Label 'respaldos' -Value $backups) + $columnGap + $errorsCell)
  Write-BoxDivider
  Write-BoxRow -Content "$modeText · $(Get-IconPrefix $script:Icons.Time)${elapsed}s · $statusText"
  Write-BoxBottom
}

function Print-Diagnostics {
  if ($script:Diagnostics.Count -eq 0) {
    return
  }

  Write-BlockGap
  Write-BoxTop -Title "$(Get-IconPrefix $script:Icons.Diagnostic)Diagnostico"

  $index = 1
  foreach ($item in $script:Diagnostics) {
    Write-BoxRow -Content ("$(Format-AnsiSegment -Text "$index." -Color Red -Bold) $(Format-DisplayTarget -Path $item.Target)")
    Write-BoxRow -Content ("   " + (Format-AnsiSegment -Text "→ $($item.Reason)" -Color DarkGray))
    $index += 1
  }

  Write-BoxBottom
}

# Groups operations by destination folder keeping config order inside each
# group, so every folder header is printed once.
function Group-OperationsByTarget {
  param([object[]]$Operations)

  $groupNames = @($Operations | ForEach-Object { $_.Group } | Sort-Object -Unique)
  foreach ($groupName in $groupNames) {
    foreach ($operation in $Operations) {
      if ([string]::Equals($operation.Group, $groupName, [System.StringComparison]::OrdinalIgnoreCase)) {
        $operation
      }
    }
  }
}

function Resolve-ItemNameWidth {
  param([object[]]$Operations)

  $longestName = 0
  foreach ($operation in $Operations) {
    $longestName = [Math]::Max($longestName, (Split-Path -Path $operation.Target -Leaf).Length)
  }

  return [Math]::Min($script:MaxItemNameWidth, [Math]::Max($script:MinItemNameWidth, $longestName))
}

function Main {
  Parse-Args -CliArgs $script:CliArgs
  [void](Invoke-InternalElevatedSymlinkMode)

  $script:RootDir = Get-RepoRoot
  $script:ConfigsDir = Join-Path -Path $script:RootDir -ChildPath 'configs'
  $script:ConfigPathsFile = Join-Path -Path $script:RootDir -ChildPath 'symlinks.yml'
  Assert-ConfigPathsFileExists
  Ensure-DotfilerDependencies

  Write-Banner
  $operations = @(Group-OperationsByTarget -Operations @(Resolve-Operations))
  $script:ItemNameWidth = Resolve-ItemNameWidth -Operations $operations
  $lastGroup = $null

  $operationIndex = 0
  foreach ($operation in $operations) {
    $operationIndex += 1
    Write-DotfilerProgress -Id 2 -Current $operationIndex -Total $operations.Count -Status "$(Get-IconPrefix '🔗')Enlazando $(Format-ProgressBar -Current $operationIndex -Total $operations.Count) $operationIndex/$($operations.Count) · $(Split-Path -Path $operation.Target -Leaf)"

    if ($operation.Group -ne $lastGroup) {
      Close-Group
      Set-GroupHeader -GroupPath (Format-DisplayTarget -Path $operation.Group)
      $lastGroup = $operation.Group
    }

    if ($operation.Remove -eq $true) {
      Remove-StaleSymlink -SourcePath $operation.Source -TargetPath $operation.Target -Reason ([string]$operation.Reason)
      continue
    }

    New-DotfileSymlink -SourcePath $operation.Source -TargetPath $operation.Target -HardLink ([bool]$operation.HardLink)
  }
  Close-Group
  Complete-DotfilerProgress -Id 2

  $changedCount = $script:CountCreated + $script:CountReplaced + $script:CountRemoved + $script:CountBackups +
    $script:CountPlannedCreated + $script:CountPlannedReplaced + $script:CountPlannedRemoved + $script:CountPlannedBackups +
    $script:PendingElevatedSymlinks.Count
  if ($script:CountUnchanged -gt 0 -and $changedCount -eq 0 -and -not $script:VerboseMode -and -not $script:Quiet) {
    Write-BlockGap
    Write-FormattedLine -Segments @((Format-AnsiSegment -Text "$(Get-IconPrefix $script:Icons.Unchanged)Todos los enlaces estan al dia ($($script:CountUnchanged))." -Color Green -Bold))
  }

  Complete-PendingElevatedSymlinks
  Print-Summary
  Print-Diagnostics

  if ($script:CountErrors -gt 0) {
    exit $script:ExitCodeRuntimeError
  }

  exit $script:ExitCodeSuccess
}

if ($env:DOTFILER_PS1_SKIP_MAIN -ne '1') {
  Main
}
