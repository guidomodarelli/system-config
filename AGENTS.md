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

## Regla Para Especificaciones

- Al escribir, actualizar o revisar specs, consultar y aplicar la guía visual de `configs/.agents/DESIGN.md`.
- Si una spec no puede seguir esa guía por una restricción técnica o de formato, dejar explícita la razón en la respuesta final.

## Regla Específica Para `cx` Y `cxd` (Mandatorio)

- Si una solicitud menciona `cx` o `cxd`, el agente debe verificar SIEMPRE ambos contextos antes de cerrar el trabajo:
  - `PowerShell`: `configs/PowerShell/Microsoft.PowerShell_profile.ps1`
  - `zsh`: `configs/zsh/.zsh/functions/codex.zsh`
- No se permite dar por finalizado un cambio sobre `cx`/`cxd` si solo se revisó un shell.
- La respuesta final debe indicar explícitamente que se verificó `PowerShell` y `zsh`, incluso cuando el cambio se aplique en un solo archivo.

## Regla De Testing Para `@andes` (Mandatorio)

```yaml
policy:
  id: "andes-no-mock-components"
  enabled: true

  actions:
    - enforce_test_rule:
        target: "@andes_components"
        rule: "no_mocks"
        mode: "required_always"

  validate:
    - check: "andes_components_are_not_mocked"
      expected: true
      on_fail:
        severity: "error"
        message: "Nunca mockear componentes importados desde @andes en tests."
```
