# Reglas para wrappers `cx` y `cxd`

## Alcance

Estas instrucciones aplican a las implementaciones de Codex bajo `configs/`, incluyendo Zsh y PowerShell.

## Regla de paridad

- Todo cambio en `configs/zsh/.zsh/functions/codex.zsh` debe revisarse contra `configs/PowerShell/Microsoft.PowerShell_profile.ps1`.
- Todo cambio en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` debe revisarse contra `configs/zsh/.zsh/functions/codex.zsh`.
- Actualizar ambas implementaciones cuando cambie el contrato observable: flags, subcommands, argumentos, defaults, selección de MCP, comportamiento de inicio o salida.
- Si la revisión concluye que no corresponde modificar la otra implementación, documentar la razón en la validación final.

## Completions Zsh

- Si un cambio afecta flags, subcommands, argumentos, defaults o valores sugeridos, revisar y actualizar `configs/zsh/.zsh/completions/_cx` y `configs/zsh/.zsh/completions/_cxd` cuando corresponda.
- Validar que completions sigan alineadas con contrato observable de wrappers; la skill `cx-cxd-parity` contiene workflow detallado.

## Validación específica de shells

- Ejecutar validación de sintaxis en Zsh (`zsh -n ...`) y validación equivalente en PowerShell cuando exista el ejecutable.
- Si la ejecución de validación de uno de los shells no está disponible en el entorno, informar de forma explícita y concreta en la respuesta final.
