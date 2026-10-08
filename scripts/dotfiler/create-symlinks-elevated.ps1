# Crea un lote de enlaces y devuelve resultados individuales al proceso original.
param(
  [Parameter(Mandatory = $true)][string]$RequestPath,
  [Parameter(Mandatory = $true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$symbolicLinkItemType = 'SymbolicLink'
$hardLinkItemType = 'HardLink'

try {
  $operations = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
  $results = @(foreach ($operation in $operations) {
    try {
      # Sin Force: no sobrescribir archivos aparecidos desde la preparacion del lote.
      if ($operation.HardLink -eq $true -and -not (Test-Path -LiteralPath $operation.Source -PathType Leaf)) {
        throw "No se puede crear hard link: el origen '$($operation.Source)' no es un archivo regular."
      }

      $itemType = if ($operation.HardLink -eq $true) { $hardLinkItemType } else { $symbolicLinkItemType }
      New-Item -ItemType $itemType -Path $operation.Target -Target $operation.Source -ErrorAction Stop | Out-Null
      [PSCustomObject]@{ Success = $true; Error = $null }
    } catch {
      [PSCustomObject]@{ Success = $false; Error = $_.Exception.Message }
    }
  })
  ConvertTo-Json -InputObject $results -Depth 4 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
} catch {
  Write-Error "No se pudo procesar el lote de enlaces: $($_.Exception.Message)"
  exit 1
}
