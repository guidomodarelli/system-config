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
$script:PreferredCommandPaths = @{}
$script:LastOutputWasSeparator = $false

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

  $script:LastOutputWasSeparator = $false
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

function Write-SymlinkLine {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][ConsoleColor]$LabelColor,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$SourcePath
  )

  $segments = [System.Collections.Generic.List[string]]::new()
  $segments.Add('[ ')
  $segments.Add((Format-LabelText -Text $Label -Color $LabelColor))
  $segments.Add(' ] ')

  $linkIcon = Get-OptionalIcon -Icon '⇢'
  if (-not [string]::IsNullOrWhiteSpace($linkIcon)) {
    $segments.Add((Format-IconText -Text $linkIcon -Color Blue))
    $segments.Add(' ')
  }

  $segments.Add($Prefix)
  $segments.Add(' ')
  $segments.Add((Format-PathText -Text $TargetPath))
  $segments.Add(' ')
  $segments.Add((Format-AnsiSegment -Text '→→' -Color Magenta -Bold))
  $segments.Add(' ')
  $segments.Add((Format-PathText -Text $SourcePath))

  Write-FormattedLine -Segments $segments.ToArray()
}

function Write-Info {
  param([string]$Message)
  if (-not $script:Quiet) {
    Write-FormattedLine -Segments @('[ ', (Format-LabelText -Text 'INFO' -Color Blue), " ] $Message")
  }
}

function Write-Warn {
  param([string]$Message)
  Write-FormattedLine -Segments @('[ ', (Format-LabelText -Text 'AVISO' -Color Yellow), " ] $Message") -ErrorStream
}

function Write-ErrorLog {
  param([string]$Message)
  Write-FormattedLine -Segments @('[ ', (Format-LabelText -Text 'ERROR' -Color Red), " ] $Message") -ErrorStream
}

function Write-Success {
  param([string]$Message)
  if (-not $script:Quiet) {
    Write-FormattedLine -Segments @('[ ', (Format-LabelText -Text 'OK' -Color Green), " ] $Message")
  }
}

function Write-Separator {
  if (-not $script:Quiet -and -not $script:LastOutputWasSeparator) {
    Write-ColorLine -Message '────────────────────────────────────────────────────────' -Color DarkGray
    $script:LastOutputWasSeparator = $true
  }
}

function Write-PlainLine {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [ConsoleColor]$Color = [ConsoleColor]::Gray
  )

  Write-ColorLine -Message $Message -Color $Color
  $script:LastOutputWasSeparator = $false
}

function Write-Group {
  param([string]$GroupPath)
  if (-not $script:Quiet) {
    $segments = [System.Collections.Generic.List[string]]::new()
    $segments.Add('[ ')
    $segments.Add((Format-LabelText -Text 'GRUPO' -Color Magenta))
    $segments.Add(' ] ')

    $groupIcon = Get-OptionalIcon -Icon '▸'
    if (-not [string]::IsNullOrWhiteSpace($groupIcon)) {
      $segments.Add((Format-IconText -Text $groupIcon -Color Magenta))
      $segments.Add(' ')
    }

    $segments.Add((Format-PathText -Text $GroupPath))
    Write-FormattedLine -Segments $segments.ToArray()
  }
}

function Format-TableCell {
  param(
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][int]$Width
  )

  if ($Value.Length -gt $Width) {
    return $Value.Substring(0, $Width)
  }

  return $Value.PadRight($Width)
}

function Write-TableRow {
  param(
    [Parameter(Mandatory = $true)][string]$Metric,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $metricColumnWidth = 32
  $valueColumnWidth = 25

  $metricCell = Format-TableCell -Value $Metric -Width $metricColumnWidth
  $valueCell = Format-TableCell -Value $Value -Width $valueColumnWidth
  Write-PlainLine -Message ("║ {0} ║ {1} ║" -f $metricCell, $valueCell) -Color DarkGray
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
      Write-SymlinkLine -Label 'INFO' -LabelColor Blue -Prefix 'Crearia symlink' -TargetPath $TargetPath -SourcePath $SourcePath
    } else {
      if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
      }

      try {
        New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath -Force | Out-Null
        Write-SymlinkLine -Label 'OK' -LabelColor Green -Prefix 'Symlink creado' -TargetPath $TargetPath -SourcePath $SourcePath
      } catch {
        if (-not (Test-IsPrivilegeElevationError -ErrorRecord $_) -or $script:IsElevatedSymlinkMode) {
          throw
        }

        Write-Info "Reintentando symlink con elevacion $TargetPath"
        Invoke-ElevatedSymlinkCreation -SourcePath $SourcePath -TargetPath $TargetPath
        Write-SymlinkLine -Label 'OK' -LabelColor Green -Prefix 'Symlink creado con elevacion' -TargetPath $TargetPath -SourcePath $SourcePath
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
  $metricColumnWidth = 32
  $valueColumnWidth = 25
  $metricBorderWidth = $metricColumnWidth + 2
  $valueBorderWidth = $valueColumnWidth + 2
  $topBorder = ('╔' + ('═' * $metricBorderWidth) + '╦' + ('═' * $valueBorderWidth) + '╗')
  $middleBorder = ('╠' + ('═' * $metricBorderWidth) + '╬' + ('═' * $valueBorderWidth) + '╣')
  $bottomBorder = ('╚' + ('═' * $metricBorderWidth) + '╩' + ('═' * $valueBorderWidth) + '╝')
  $mode = if ($script:DryRun) { 'Simulacion' } else { 'Aplicacion real' }
  $created = if ($script:DryRun) { $script:CountPlannedCreated } else { $script:CountCreated }
  $replaced = if ($script:DryRun) { $script:CountPlannedReplaced } else { $script:CountReplaced }
  $backups = if ($script:DryRun) { $script:CountPlannedBackups } else { $script:CountBackups }
  $status = if ($script:CountErrors -eq 0) { '[OK] Sin errores' } else { '[X] Con errores' }
  $createdLabel = if ($script:DryRun) { 'Creados (plan)' } else { 'Creados' }
  $replacedLabel = if ($script:DryRun) { 'Reemplazados (plan)' } else { 'Reemplazados' }
  $backupsLabel = if ($script:DryRun) { 'Respaldos (plan)' } else { 'Respaldos' }

  Write-Separator
  Write-PlainLine -Message 'RESUMEN' -Color Blue
  Write-PlainLine -Message $topBorder -Color DarkGray
  Write-TableRow -Metric 'Metrica' -Value 'Valor'
  Write-PlainLine -Message $middleBorder -Color DarkGray
  Write-TableRow -Metric 'Inicio (local)' -Value $script:StartTime.ToString('yyyy-MM-ddTHH:mm:ssK')
  Write-TableRow -Metric 'Fin (local)' -Value $endTime.ToString('yyyy-MM-ddTHH:mm:ssK')
  Write-TableRow -Metric 'Tiempo total (s)' -Value ([string]$elapsed)
  Write-TableRow -Metric 'Modo ejecucion' -Value $mode
  Write-TableRow -Metric $createdLabel -Value ([string]$created)
  Write-TableRow -Metric $replacedLabel -Value ([string]$replaced)
  Write-TableRow -Metric $backupsLabel -Value ([string]$backups)
  Write-TableRow -Metric 'Omitidos' -Value ([string]$script:CountSimulated)
  Write-TableRow -Metric 'Errores' -Value ([string]$script:CountErrors)
  Write-TableRow -Metric 'Estado' -Value $status
  Write-PlainLine -Message $bottomBorder -Color DarkGray

  if ($script:DryRun) {
    Write-Info "Modo simulacion activo, no se escribieron cambios en el sistema de archivos."
  }

  Write-Separator
  if ($script:CountErrors -eq 0) {
    Write-PlainLine -Message '[ FIN ] Configuracion de symlinks finalizada.' -Color Green
  } else {
    Write-PlainLine -Message ("[ FIN ] Finalizado con {0} error(es)." -f $script:CountErrors) -Color Red
  }
}

function Print-Diagnostics {
  if ($script:Diagnostics.Count -eq 0) {
    return
  }

  Write-Separator
  Write-PlainLine -Message 'DIAGNOSTICO' -Color Blue

  $index = 1
  foreach ($item in $script:Diagnostics) {
    Write-PlainLine -Message ("[ ERROR ] {0}) destino={1} | causa={2}" -f $index, $item.Target, $item.Reason)
    $index += 1
  }
}

function Main {
  Parse-Args -CliArgs $script:CliArgs
  [void](Invoke-InternalElevatedSymlinkMode)

  $script:RootDir = Get-RepoRoot
  $script:ConfigsDir = Join-Path -Path $script:RootDir -ChildPath 'configs'
  $script:ConfigPathsFile = Join-Path -Path $script:RootDir -ChildPath 'symlinks.yml'
  Assert-ConfigPathsFileExists
  Ensure-DotfilerDependencies

  $operations = @(Resolve-Operations)
  $lastGroup = $null

  foreach ($operation in $operations) {
    if ($operation.Group -ne $lastGroup) {
      Write-Separator
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
