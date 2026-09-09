# Reglas para wrappers `cx` y `cxd`

## Alcance

Estas instrucciones aplican a las implementaciones de Codex bajo `configs/`, incluyendo Zsh y PowerShell.

## Regla de paridad

- Todo cambio en `configs/zsh/.zsh/functions/codex.zsh` debe evaluarse y reflejarse también en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` cuando aplique.
- Todo cambio en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` debe evaluarse y reflejarse también en `configs/zsh/.zsh/functions/codex.zsh` cuando aplique.
- No se permite cerrar una tarea relacionada con `cx` o `cxd` sin revisar explícitamente ambos archivos.
- Si la ejecución de validación de uno de los shells no está disponible en el entorno, se debe informar de forma explícita y concreta en la respuesta final.

### Checklist mínimo antes de cerrar cambios de `cx`/`cxd`

- Confirmar revisión de:
  - `configs/zsh/.zsh/functions/codex.zsh`
  - `configs/PowerShell/Microsoft.PowerShell_profile.ps1`
- Ejecutar validación de sintaxis en Zsh (`zsh -n ...`) y validación equivalente en PowerShell cuando exista el ejecutable.
- Incluir en la respuesta final un bloque breve de estado con:
  - `Verificado zsh: <sí/no + evidencia>`
  - `Verificado PowerShell: <sí/no + evidencia>`
