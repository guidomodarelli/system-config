# Reglas De Agentes

## Idioma En Salida Visible (Mandatorio)

- Todo texto visible para personas debe estar siempre en español.
- Esto incluye, sin limitarse a:
  - texto de UI/CLI
  - descripciones
  - títulos
  - headers
  - párrafos
  - mensajes de estado, errores y resúmenes

## Excepciones Técnicas (Mandatorio En Inglés)

- Deben mantenerse en inglés:
  - flags (`--dry-run`, `--help`, etc.)
  - comandos
  - nombres de funciones, variables y términos del lenguaje (bash, zsh, etc.)
  - términos técnicos y nomenclatura técnica

## Criterio De Aplicación

- Español para contenido orientado a personas.
- Inglés para elementos técnicos ejecutables o de implementación.

## Regla Específica Para `cx` Y `cxd` (Mandatorio)

- Si una solicitud menciona `cx` o `cxd`, el agente debe verificar SIEMPRE ambos contextos antes de cerrar el trabajo:
  - `PowerShell`: `configs/PowerShell/Microsoft.PowerShell_profile.ps1`
  - `zsh`: `configs/zsh/.zsh/functions/codex.zsh`
- No se permite dar por finalizado un cambio sobre `cx`/`cxd` si solo se revisó un shell.
- La respuesta final debe indicar explícitamente que se verificó `PowerShell` y `zsh`, incluso cuando el cambio se aplique en un solo archivo.
