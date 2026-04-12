$ErrorActionPreference = 'Stop'

$script:ExitCodeSuccess = 0
$script:ExitCodeRuntimeError = 1
$script:ExitCodeInputError = 2

$script:DryRun = $false
$script:UseColor = $true
$script:UseIcons = $true
$script:Quiet = $false
$script:VerboseMode = $false
$script:CliArgs = @($args)
$script:IsElevatedSymlinkMode = $false
$script:ElevatedSymlinkSource = $null
$script:ElevatedSymlinkTarget = $null

$script:RootDir = $null
$script:ConfigsDir = $null
$script:ConfigPathsFile = $null
$script:HomeDir = [Environment]::GetFolderPath('UserProfile')
$script:WindowsUser = $env:USERNAME
$script:StartTime = Get-Date

$script:CountCreated = 0
$script:CountReplaced = 0
$script:CountBackups = 0
$script:CountSimulated = 0
$script:CountErrors = 0
$script:CountPlannedCreated = 0
$script:CountPlannedReplaced = 0
$script:CountPlannedBackups = 0

$script:Diagnostics = [System.Collections.Generic.List[object]]::new()

function Write-ColorLine {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [ConsoleColor]$Color = [ConsoleColor]::Gray,
    [switch]$ErrorStream
  )

  if ($ErrorStream) {
    $formattedMessage = $Message
    if ($script:UseColor) {
      $ansiColor = switch ($Color) {
        ([ConsoleColor]::Red) { '31' }
        ([ConsoleColor]::Yellow) { '33' }
        ([ConsoleColor]::Blue) { '34' }
        ([ConsoleColor]::Green) { '32' }
        ([ConsoleColor]::Magenta) { '35' }
        ([ConsoleColor]::DarkGray) { '90' }
        default { '37' }
      }

      $formattedMessage = "$([char]27)[$ansiColor" + "m$Message$([char]27)[0m"
    }

    [Console]::Error.WriteLine($formattedMessage)
    return
  }

  if ($script:UseColor) {
    Write-Host $Message -ForegroundColor $Color
  } else {
    Write-Output $Message
  }
}

function Write-Info {
  param([string]$Message)
  if (-not $script:Quiet) {
    Write-ColorLine -Message "[ INFO ] $Message" -Color Blue
  }
}

function Write-Warn {
  param([string]$Message)
  Write-ColorLine -Message "[ AVISO ] $Message" -Color Yellow -ErrorStream
}

function Write-ErrorLog {
  param([string]$Message)
  Write-ColorLine -Message "[ ERROR ] $Message" -Color Red -ErrorStream
}

function Write-Success {
  param([string]$Message)
  if (-not $script:Quiet) {
    Write-ColorLine -Message "[ OK ] $Message" -Color Green
  }
}

function Write-Group {
  param([string]$GroupPath)
  if (-not $script:Quiet) {
    Write-ColorLine -Message "[ GRUPO ] $GroupPath" -Color Magenta
  }
}

function Write-HelpText {
  @'
Uso: .\scripts\dotfiler\dotfiler.bat [opciones]

Opciones:
  --dry-run   Muestra los cambios planificados sin escribir archivos
  --no-color  Desactiva los colores
  --plain     Desactiva colores e iconos
  --verbose   Muestra tiempo por operacion
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

function Get-ElevatedSymlinkProcessArguments {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath
  )

  $processArguments = @(
    '-NoLogo',
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $ScriptPath,
    '--internal-create-link',
    '--internal-source', $SourcePath,
    '--internal-target', $TargetPath
  )

  $quotedProcessArguments = $processArguments | ForEach-Object {
    ConvertTo-WindowsProcessArgument -Value $_
  }

  return ,$quotedProcessArguments
}

function Invoke-ElevatedSymlinkCreation {
  param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath
  )

  $powerShellExecutable = Get-PowerShellExecutablePath
  $quotedProcessArguments = Get-ElevatedSymlinkProcessArguments -ScriptPath $PSCommandPath -SourcePath $SourcePath -TargetPath $TargetPath

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

    New-Item -ItemType SymbolicLink -Path $script:ElevatedSymlinkTarget -Target $script:ElevatedSymlinkSource -Force | Out-Null
  } catch {
    Write-ErrorLog "No se pudo crear symlink elevado $($script:ElevatedSymlinkTarget) -> $($script:ElevatedSymlinkSource)"
    Write-ErrorLog $_.Exception.Message
    exit $script:ExitCodeRuntimeError
  }

  exit $script:ExitCodeSuccess
}

function Test-CommandAvailable {
  param([string]$Name)
  return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Remove-YamlInlineComment {
  param([string]$Line)

  if ($null -eq $Line) {
    return ''
  }

  $inSingleQuote = $false
  $inDoubleQuote = $false

  for ($index = 0; $index -lt $Line.Length; $index += 1) {
    $char = $Line[$index]

    if ($char -eq "'" -and -not $inDoubleQuote) {
      if ($inSingleQuote -and $index + 1 -lt $Line.Length -and $Line[$index + 1] -eq "'") {
        $index += 1
        continue
      }

      $inSingleQuote = -not $inSingleQuote
      continue
    }

    if ($char -eq '"' -and -not $inSingleQuote) {
      $escaped = $index -gt 0 -and $Line[$index - 1] -eq '\'
      if (-not $escaped) {
        $inDoubleQuote = -not $inDoubleQuote
      }
      continue
    }

    if ($char -eq '#' -and -not $inSingleQuote -and -not $inDoubleQuote) {
      if ($index -eq 0 -or [char]::IsWhiteSpace($Line[$index - 1])) {
        return $Line.Substring(0, $index).TrimEnd()
      }
    }
  }

  return $Line.TrimEnd()
}

function Split-YamlKeyValue {
  param([string]$Text)

  $inSingleQuote = $false
  $inDoubleQuote = $false

  for ($index = 0; $index -lt $Text.Length; $index += 1) {
    $char = $Text[$index]

    if ($char -eq "'" -and -not $inDoubleQuote) {
      if ($inSingleQuote -and $index + 1 -lt $Text.Length -and $Text[$index + 1] -eq "'") {
        $index += 1
        continue
      }

      $inSingleQuote = -not $inSingleQuote
      continue
    }

    if ($char -eq '"' -and -not $inSingleQuote) {
      $escaped = $index -gt 0 -and $Text[$index - 1] -eq '\'
      if (-not $escaped) {
        $inDoubleQuote = -not $inDoubleQuote
      }
      continue
    }

    if ($char -eq ':' -and -not $inSingleQuote -and -not $inDoubleQuote) {
      return [PSCustomObject]@{
        Key      = $Text.Substring(0, $index).Trim()
        HasValue = $true
        Value    = $Text.Substring($index + 1).Trim()
      }
    }
  }

  return [PSCustomObject]@{
    Key      = $null
    HasValue = $false
    Value    = $null
  }
}

function ConvertFrom-YamlScalar {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) {
    return $null
  }

  $value = $Text.Trim()
  if ($value.Length -eq 0) {
    return ''
  }

  if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
    return $value.Substring(1, $value.Length - 2).Replace("''", "'")
  }

  if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
    return [regex]::Unescape($value.Substring(1, $value.Length - 2))
  }

  switch -Regex ($value) {
    '^(true|True|TRUE)$' { return $true }
    '^(false|False|FALSE)$' { return $false }
    '^(null|Null|NULL|~)$' { return $null }
  }

  return $value
}

function Parse-YamlNode {
  param(
    [System.Collections.Generic.List[object]]$Tokens,
    [ref]$Index
  )

  if ($Index.Value -ge $Tokens.Count) {
    throw "Estructura YAML incompleta."
  }

  $current = $Tokens[$Index.Value]
  if ($current.Content.StartsWith('- ')) {
    return Parse-YamlSequence -Tokens $Tokens -Index $Index -Indent $current.Indent
  }

  return Parse-YamlMapping -Tokens $Tokens -Index $Index -Indent $current.Indent
}

function Parse-YamlSequence {
  param(
    [System.Collections.Generic.List[object]]$Tokens,
    [ref]$Index,
    [int]$Indent
  )

  $items = [System.Collections.Generic.List[object]]::new()

  while ($Index.Value -lt $Tokens.Count) {
    $token = $Tokens[$Index.Value]
    if ($token.Indent -ne $Indent -or -not $token.Content.StartsWith('- ')) {
      break
    }

    $itemText = $token.Content.Substring(2).Trim()
    $Index.Value += 1

    if ([string]::IsNullOrWhiteSpace($itemText)) {
      if ($Index.Value -ge $Tokens.Count -or $Tokens[$Index.Value].Indent -le $Indent) {
        $items.Add($null)
      } else {
        $items.Add((Parse-YamlNode -Tokens $Tokens -Index $Index))
      }
      continue
    }

    $pair = Split-YamlKeyValue -Text $itemText
    if (-not $pair.HasValue) {
      $items.Add((ConvertFrom-YamlScalar -Text $itemText))
      continue
    }

    $map = [ordered]@{}
    if ($pair.Value.Length -gt 0) {
      $map[$pair.Key] = ConvertFrom-YamlScalar -Text $pair.Value
    } elseif ($Index.Value -lt $Tokens.Count -and $Tokens[$Index.Value].Indent -gt $Indent) {
      $map[$pair.Key] = Parse-YamlNode -Tokens $Tokens -Index $Index
    } else {
      $map[$pair.Key] = $null
    }

    while ($Index.Value -lt $Tokens.Count) {
      $nextToken = $Tokens[$Index.Value]
      if ($nextToken.Indent -le $Indent) {
        break
      }
      if ($nextToken.Indent -eq ($Indent + 2) -and -not $nextToken.Content.StartsWith('- ')) {
        $nextPair = Split-YamlKeyValue -Text $nextToken.Content
        if (-not $nextPair.HasValue) {
          throw "Propiedad YAML invalida: $($nextToken.Content)"
        }

        $Index.Value += 1
        if ($nextPair.Value.Length -gt 0) {
          $map[$nextPair.Key] = ConvertFrom-YamlScalar -Text $nextPair.Value
        } elseif ($Index.Value -lt $Tokens.Count -and $Tokens[$Index.Value].Indent -gt $nextToken.Indent) {
          $map[$nextPair.Key] = Parse-YamlNode -Tokens $Tokens -Index $Index
        } else {
          $map[$nextPair.Key] = $null
        }
        continue
      }

      break
    }

    $items.Add([PSCustomObject]$map)
  }

  return @($items)
}

function Parse-YamlMapping {
  param(
    [System.Collections.Generic.List[object]]$Tokens,
    [ref]$Index,
    [int]$Indent
  )

  $map = [ordered]@{}

  while ($Index.Value -lt $Tokens.Count) {
    $token = $Tokens[$Index.Value]
    if ($token.Indent -ne $Indent -or $token.Content.StartsWith('- ')) {
      break
    }

    $pair = Split-YamlKeyValue -Text $token.Content
    if (-not $pair.HasValue) {
      throw "Propiedad YAML invalida: $($token.Content)"
    }

    $Index.Value += 1
    if ($pair.Value.Length -gt 0) {
      $map[$pair.Key] = ConvertFrom-YamlScalar -Text $pair.Value
      continue
    }

    if ($Index.Value -lt $Tokens.Count -and $Tokens[$Index.Value].Indent -gt $Indent) {
      $map[$pair.Key] = Parse-YamlNode -Tokens $Tokens -Index $Index
    } else {
      $map[$pair.Key] = $null
    }
  }

  return [PSCustomObject]$map
}

function ConvertFrom-SimpleYaml {
  param([string]$Path)

  $tokens = [System.Collections.Generic.List[object]]::new()

  foreach ($rawLine in (Get-Content -LiteralPath $Path)) {
    if ($rawLine -match "`t") {
      throw "El YAML no puede usar tabulaciones para indentacion."
    }

    $lineWithoutComments = Remove-YamlInlineComment -Line $rawLine
    if ([string]::IsNullOrWhiteSpace($lineWithoutComments)) {
      continue
    }

    $trimmedLine = $lineWithoutComments.TrimStart(' ')
    $tokens.Add([PSCustomObject]@{
        Indent  = $lineWithoutComments.Length - $trimmedLine.Length
        Content = $trimmedLine
      })
  }

  if ($tokens.Count -eq 0) {
    throw 'El archivo YAML esta vacio.'
  }

  $index = 0
  $result = Parse-YamlNode -Tokens $tokens -Index ([ref]$index)
  if ($index -ne $tokens.Count) {
    throw "No se pudo interpretar completamente el YAML cerca de '$($tokens[$index].Content)'."
  }

  return $result
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

function Get-ResolvedSources {
  param([string]$OriginalPath)

  $pattern = Resolve-SourcePattern -Path $OriginalPath
  if (Test-GlobPattern -Path $OriginalPath) {
    $items = @(Get-ChildItem -Path $pattern -Force -ErrorAction SilentlyContinue | Sort-Object Name)
    return $items
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
    Write-Info "Eliminaria symlink anterior $Path"
    return
  }

  Remove-Item -LiteralPath $Path -Force
  Write-Info "Symlink anterior eliminado $Path"
}

function Move-ToBackup {
  param([string]$Path)

  $backupPath = Resolve-BackupPath -Target $Path
  if ($script:DryRun) {
    $script:CountPlannedBackups += 1
    Write-Info "Crearia respaldo $backupPath"
    return $backupPath
  }

  Move-Item -LiteralPath $Path -Destination $backupPath -Force
  $script:CountBackups += 1
  Write-Info "Respaldo creado $backupPath"
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
    [string]$TargetPath
  )

  $startedAt = Get-Date

  try {
    if ($script:DryRun) {
      $script:CountSimulated += 1
    }

    $parentDir = Split-Path -Path $TargetPath -Parent
    if ([string]::IsNullOrWhiteSpace($parentDir)) {
      $parentDir = '.'
    }

    if (Test-IsSymlink -Path "$TargetPath.bak") {
      Remove-ExistingSymlink -Path "$TargetPath.bak"
    }

    if (Test-IsSymlink -Path $TargetPath) {
      Remove-ExistingSymlink -Path $TargetPath
      if ($script:DryRun) {
        $script:CountPlannedReplaced += 1
      } else {
        $script:CountReplaced += 1
      }
    } elseif (Test-PathEntry -Path $TargetPath) {
      [void](Move-ToBackup -Path $TargetPath)
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

    if ($script:DryRun) {
      Write-Info "Crearia symlink $TargetPath -> $SourcePath"
    } else {
      if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
      }

      try {
        New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath -Force | Out-Null
        Write-Success "Symlink creado $TargetPath -> $SourcePath"
      } catch {
        if (-not (Test-IsPrivilegeElevationError -ErrorRecord $_) -or $script:IsElevatedSymlinkMode) {
          throw
        }

        Write-Info "Reintentando symlink con elevacion $TargetPath"
        Invoke-ElevatedSymlinkCreation -SourcePath $SourcePath -TargetPath $TargetPath
        Write-Success "Symlink creado con elevacion $TargetPath -> $SourcePath"
      }
    }

    if ($script:VerboseMode -and -not $script:Quiet) {
      $elapsed = [int]((Get-Date) - $startedAt).TotalSeconds
      Write-ColorLine -Message "[ TIEMPO ] transcurrido=${elapsed}s" -Color DarkGray
    }
  } catch {
    $script:CountErrors += 1
    Add-Diagnostic -Target $TargetPath -Reason $_.Exception.Message
    Write-ErrorLog "No se pudo crear symlink $TargetPath -> $SourcePath"
  }
}

function Get-ConfigEntries {
  if (-not (Test-Path -LiteralPath $script:ConfigPathsFile)) {
    Write-ErrorLog "No se encontro el archivo de configuracion: $script:ConfigPathsFile"
    exit $script:ExitCodeInputError
  }

  try {
    $config = ConvertFrom-SimpleYaml -Path $script:ConfigPathsFile
  } catch {
    Write-ErrorLog "Configuracion invalida en ${script:ConfigPathsFile}: no se pudo interpretar YAML."
    exit $script:ExitCodeInputError
  }

  $pathsProperty = $config.PSObject.Properties['paths']
  if ($null -eq $pathsProperty -or $pathsProperty.Value -isnot [System.Collections.IEnumerable] -or $pathsProperty.Value -is [string]) {
    Write-ErrorLog "Configuracion invalida en ${script:ConfigPathsFile}: 'paths' debe ser un arreglo."
    exit $script:ExitCodeInputError
  }

  return @($pathsProperty.Value)
}

function Resolve-Operations {
  $operations = [System.Collections.Generic.List[object]]::new()

  foreach ($entry in (Get-ConfigEntries)) {
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

    $targetBase = Resolve-TargetBase -Target $selectedTarget

    $sources = @(Get-ResolvedSources -OriginalPath ([string]$entry.path))
    if ($sources.Count -eq 0) {
      if (Test-GlobPattern -Path ([string]$entry.path)) {
        Write-Warn "El patron no produjo resultados: $($entry.path)"
      } else {
        $script:CountErrors += 1
        Add-Diagnostic -Target $targetBase -Reason "Ruta de origen inexistente: $($entry.path)"
        Write-Warn "Ruta de origen invalida o inexistente: $($entry.path)"
      }
      continue
    }

    if ($selectedTargetDefinition.UsesExactTarget -and (Test-GlobPattern -Path ([string]$entry.path))) {
      $script:CountErrors += 1
      Add-Diagnostic -Target $targetBase -Reason "exactTarget no admite patrones wildcard: $($entry.path)"
      Write-Warn "No se permite exactTarget con patrones wildcard: $($entry.path)"
      continue
    }

    foreach ($sourceItem in $sources) {
      $targetPath = if ($selectedTargetDefinition.UsesExactTarget) {
        $targetBase
      } else {
        Join-Path -Path $targetBase -ChildPath $sourceItem.Name
      }
      $operations.Add([PSCustomObject]@{
          Group  = (Split-Path -Path $targetPath -Parent)
          Source = $sourceItem.FullName
          Target = $targetPath
        })
    }
  }

  return $operations
}

function Print-Summary {
  $endTime = Get-Date
  $elapsed = [int]($endTime - $script:StartTime).TotalSeconds
  $mode = if ($script:DryRun) { 'Simulacion' } else { 'Aplicacion real' }
  $created = if ($script:DryRun) { $script:CountPlannedCreated } else { $script:CountCreated }
  $replaced = if ($script:DryRun) { $script:CountPlannedReplaced } else { $script:CountReplaced }
  $backups = if ($script:DryRun) { $script:CountPlannedBackups } else { $script:CountBackups }
  $status = if ($script:CountErrors -eq 0) { '[OK] Sin errores' } else { '[X] Con errores' }

  Write-ColorLine -Message '--------------------------------------------------------' -Color DarkGray
  Write-ColorLine -Message 'RESUMEN' -Color Blue
  Write-Output ("Inicio (local): {0}" -f $script:StartTime.ToString('yyyy-MM-ddTHH:mm:ssK'))
  Write-Output ("Fin (local):    {0}" -f $endTime.ToString('yyyy-MM-ddTHH:mm:ssK'))
  Write-Output ("Tiempo total:   {0}s" -f $elapsed)
  Write-Output ("Modo:           {0}" -f $mode)
  Write-Output ("Creados:        {0}" -f $created)
  Write-Output ("Reemplazados:   {0}" -f $replaced)
  Write-Output ("Respaldos:      {0}" -f $backups)
  Write-Output ("Omitidos:       {0}" -f $script:CountSimulated)
  Write-Output ("Errores:        {0}" -f $script:CountErrors)
  Write-Output ("Estado:         {0}" -f $status)

  if ($script:DryRun) {
    Write-Info "Modo simulacion activo, no se escribieron cambios en el sistema de archivos."
  }
}

function Print-Diagnostics {
  if ($script:Diagnostics.Count -eq 0) {
    return
  }

  Write-ColorLine -Message '--------------------------------------------------------' -Color DarkGray
  Write-ColorLine -Message 'DIAGNOSTICO' -Color Blue

  $index = 1
  foreach ($item in $script:Diagnostics) {
    Write-Output ("[ ERROR ] {0}) destino={1} | causa={2}" -f $index, $item.Target, $item.Reason)
    $index += 1
  }
}

function Main {
  Parse-Args -CliArgs $script:CliArgs
  [void](Invoke-InternalElevatedSymlinkMode)

  $script:RootDir = Get-RepoRoot
  $script:ConfigsDir = Join-Path -Path $script:RootDir -ChildPath 'configs'
  $script:ConfigPathsFile = Join-Path -Path $script:RootDir -ChildPath 'symlinks.yml'

  $operations = @(Resolve-Operations)
  $lastGroup = $null

  foreach ($operation in $operations) {
    if ($operation.Group -ne $lastGroup) {
      Write-Group -GroupPath $operation.Group
      $lastGroup = $operation.Group
    }

    New-DotfileSymlink -SourcePath $operation.Source -TargetPath $operation.Target
  }

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
