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

## Workspaces Generados Por Skills

- Una carpeta `*-workspace` con `SKILL.md` directamente en su primer nivel es una skill legítima y debe conservarse.
- Una carpeta `*-workspace` sin `SKILL.md` de primer nivel es un workspace temporal generado por una skill y no debe guardarse en el repositorio.
- Git no puede expresar directamente esa condición de existencia; `.gitignore` cubre artefactos generados conocidos y la validación final debe eliminar workspaces temporales antes de cerrar.
