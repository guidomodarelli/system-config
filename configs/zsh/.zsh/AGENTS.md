# Reglas Para Codex En `.zsh`

## Scope

Estas instrucciones aplican a todo el árbol bajo `configs/zsh/.zsh/`.

## Regla Para `cx`

- Si modificás la función `cx` en `functions/codex.zsh`, debés revisar si corresponde actualizar el completion `_cx` en `completions/_cx`.
- Si el cambio en `cx` agrega, elimina o altera flags, subcomandos, argumentos posicionals, valores sugeridos o comportamiento visible en autocomplete, también debés actualizar `completions/_cx` en el mismo cambio.
- Si modificás `cx` en `functions/codex.zsh`, también debés actualizar la implementación equivalente en `../../PowerShell/Microsoft.PowerShell_profile.ps1` para mantener paridad de comportamiento.
- Si modificás la implementación de `cx` en `../../PowerShell/Microsoft.PowerShell_profile.ps1`, también debés reflejar ese cambio en `functions/codex.zsh` para mantener paridad de comportamiento.
- Si un cambio en cualquiera de las dos implementaciones afecta flags, subcomandos, argumentos, defaults o completions, debés revisar y actualizar ambas superficies afectadas en el mismo cambio.
- No des por terminado un cambio sobre `cx` sin validar explícitamente si el completion quedó alineado con la implementación.
- No des por terminado un cambio sobre `cx` sin validar explícitamente que Zsh, PowerShell y el completion `_cx` sigan alineados entre sí cuando corresponda.
