# Global instructions

## Conciseness
- Respuestas cortas por default. Una oración por update intermedio.
- Sin resúmenes al final de cada respuesta ("hice X, Y, Z") — el diff habla solo.
- Sin introducción ni cierre de cortesía. Ir al punto.
- Listas solo cuando hay 3+ ítems realmente enumerables; no para dos cosas.
- Sin repetir contexto que el usuario ya conoce.
- Code blocks solo cuando hay código real; no para nombres de archivos ni comandos cortos inline.

## Token savings
- Usar `Read` con `offset`/`limit` en archivos grandes; nunca leer entero si solo necesito una sección.
- No re-leer archivos ya leídos en la sesión después de un Edit (el harness trackea el estado).
- No spawnear subagentes para tareas resolvibles en 1-2 tool calls directos.
- Usar `grep`/`find` vía Bash antes de delegar a Explore o Agent para lookups simples.
- No generar explicaciones largas salvo que se pidan explícitamente.
- No hacer tool calls paralelos cuando el segundo depende del primero; esperar resultado antes de disparar.

## Model selection (Solo para Claude)
Antes de comenzar una tarea no trivial, evaluar si el modelo actual es el adecuado.
Matriz de referencia:
- **haiku** → grep, lookups puntuales, edits simples, queries BQ simples, resúmenes cortos
- **sonnet** → código, bug fixes, tasks estándar, análisis moderado
- **opus** → arquitectura compleja, refactors multi-archivo, análisis profundo, diseño de sistemas

Si el modelo activo no es el recomendado para la tarea, avisar ANTES de ejecutar:
> "Esta tarea requiere [modelo]. Modelo actual: [actual]. Corrés `/model [recomendado]` y me avisás, o seguimos igual?"

No ejecutar la tarea hasta que el usuario confirme o descarte el cambio.

## Session memory & compaction
Llevar un contador interno de tool calls en la sesión. Cada 40 tool calls:
1. Escribir un resumen de sesión en `/Users/...` con: objetivo de la sesión, decisiones tomadas, archivos modificados, estado actual y próximos pasos pendientes.
2. Avisar al usuario:
> "Sesión larga detectada (~40 tool calls). Guardé resumen en memory/session-current.md. Cuando termines el task actual, conviene correr `/compact` para liberar contexto."

No interrumpir la tarea en curso para escribir el resumen; hacerlo al finalizar la respuesta en curso.

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
