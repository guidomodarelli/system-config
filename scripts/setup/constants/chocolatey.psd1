@{
  # Política de reintentos para operaciones de paquetes del setup.
  MaximumAttempts = 3
  RetryDelaySeconds = 2

  # El primer grupo captura el código HTTP; solo errores transitorios.
  TransientHttpErrorPattern = '(?im)(?:Failed to fetch|Response status code|HTTP[ /])[^\r\n]*\b(408|429|500|502|503|504)\b'
  ResolverFailurePattern = '(?im)Failed to fetch results from V2 feed|Unable to find package|NuGetResolverInputException'

  # Formato de choco list --limit-output; {0} recibe el id escapado.
  InstalledPackagePattern = '^{0}\|[^\s|]+$'
}
