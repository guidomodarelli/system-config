# Reglas para wrappers `cx` y `cxd`

## Alcance

Estas instrucciones aplican a las implementaciones de Codex bajo `configs/`, incluyendo Zsh y PowerShell.

## Regla de paridad

- Todo cambio en `configs/zsh/.zsh/functions/codex.zsh` debe evaluarse y reflejarse también en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` cuando aplique.
- Todo cambio en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` debe evaluarse y reflejarse también en `configs/zsh/.zsh/functions/codex.zsh` cuando aplique.

## Validación específica de shells

- Ejecutar validación de sintaxis en Zsh (`zsh -n ...`) y validación equivalente en PowerShell cuando exista el ejecutable.
- Si la ejecución de validación de uno de los shells no está disponible en el entorno, informar de forma explícita y concreta en la respuesta final.
