# Crea un lote de enlaces y devuelve resultados individuales al proceso original.
param(
  [Parameter(Mandatory = $true)][string]$RequestPath,
  [Parameter(Mandatory = $true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'

try {
  $operations = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
  $results = @(foreach ($operation in $operations) {
    try {
      # Sin Force: no sobrescribir archivos aparecidos desde la preparacion del lote.
      New-Item -ItemType SymbolicLink -Path $operation.Target -Target $operation.Source -ErrorAction Stop | Out-Null
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
