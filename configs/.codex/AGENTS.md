---
description: Rules for the agents.
alwaysApply: true
---

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

# User Rules

## Idioma y comunicación

- Los planes del agente deben escribirse siempre en español.
- Las preguntas al usuario deben escribirse siempre en español.
- Los hallazgos de review deben presentarse siempre en español.

### Validación mínima de idioma

Antes de cerrar una respuesta o cambio, confirmar que:
- El plan, si existe, está escrito en español.
- Las preguntas visibles al usuario, si existen, están escritas en español.
- Los hallazgos de review, si existen, están escritos en español.

## Memoria persistente (MCP `memory`) — Mandatorio

- Al inicio de cada sesión o tarea, antes de planificar o responder, consultar la memoria con el MCP `memory` (`search_nodes`/`read_graph`) para recuperar contexto relevante del usuario y del proyecto.
- Tratar lo recuperado como contexto de fondo (refleja lo que era cierto al guardarse): si una memoria nombra un archivo, símbolo o flag, verificar que siga existiendo antes de recomendarlo.
- Cuando se descubra un hecho duradero (preferencia del usuario, decisión de proyecto, gotcha técnico reusable), guardarlo con el MCP `memory` y commitearlo en `system-config` (el grafo vive en `configs/.mcp-memory/memory.json`, symlinkeado a `~/.mcp-memory/memory.json`).

## Reglas de testing (obligatorias)
- Antes de dar un cambio por terminado, ejecutar los tests relevantes y asegurar que pasen.
- Si se agrega, modifica o elimina funcionalidad, se deben agregar o actualizar los tests correspondientes.
- Si no es posible ejecutar tests en el entorno actual, se debe informar explícitamente qué faltó validar y por qué.
- Preferir tests reales sobre mocks de librerías de UI, plataforma o SDK internos en cualquier proyecto: no mockear librerías internas o de plataforma del proyecto. Solo mockear estas dependencias por pedido explícito del usuario o imposibilidad técnica justificada; en esos casos, explicar por qué el mock es necesario y mantenerlo lo más acotado posible.
- Las librerías internas o de plataforma no deben estar mockeadas antes, durante ni después de un test; no usar `jest.mock`, `jest.doMock`, `jest.unmock` ni `jest.dontMock` para esas dependencias. Los tests deben ejercer la integración real o aislarse en un borde propio del proyecto.
- Nunca testear el contenido textual exacto de un archivo fuente ni analizar sus strings internos como objetivo del test. Los tests deben validar comportamiento observable, contratos públicos, integración real, invocación posible, render, efectos esperados o errores controlados, no detalles de implementación como imports escritos de una forma específica.
- No agregar tests que solo verifiquen que un módulo compila, se importa, se bundlea o se invoca en un arnés artificial si no validan comportamiento relevante del producto o contrato público real. Para problemas de build/bundle/runtime, preferir validar con el comando real de build, una prueba de integración existente del flujo afectado o una prueba E2E/funcional que reproduzca el escenario real.
- Excepción: cualquier mock en tests o setup de tests puede conservarse cuando tenga una justificación técnica válida y documentada, por ejemplo evitar timers, listeners globales o efectos de runtime que impiden que Jest finalice. No eliminarlo sin reemplazar esa protección por una solución equivalente validada.

## Reglas globales de diseño y mantenimiento
- Nombrar variables, funciones, métodos, clases, archivos, carpetas y demás elementos de forma clara, coherente, concisa, completa y autoexplicativa. → Skill: `enforce-naming-conventions`
- Evitar abreviaciones innecesarias y nombres de una sola letra, salvo convenciones ampliamente aceptadas y justificadas por el contexto. → Skill: `enforce-naming-conventions`
- Documentar con JSDoc o TSDoc cuando el lenguaje, la complejidad o la intención del código lo hagan relevante. → Skill: `jsdoc-required-javascript`
- Extraer valores hardcodeados con significado funcional a constantes o archivos de configuración cuando mejore la claridad, la reutilización o el mantenimiento. → Skill: `frontend-structure-accessibility-best-practices`
- Modularizar por responsabilidad y organizar el código en estructuras cohesionadas como `utils/`, `constants/`, `services/`, `adapters/` u otras equivalentes cuando corresponda. → Skills: `enforce-naming-conventions`, `frontend-structure-accessibility-best-practices`
- Priorizar eliminacion de duplicidad, alta cohesión, bajo acoplamiento y principios SOLID cuando aporten valor real al diseño. → Skills: `frontend-structure-accessibility-best-practices`, `mock-first-testing-design`
- Antes de implementar cambios relevantes, identificar módulos y responsabilidades; después del cambio, verificar que cada módulo conserve una responsabilidad clara. → Skill: `frontend-structure-accessibility-best-practices`
- Tras cada edición significativa, incluir una validación breve de 1 a 2 líneas indicando si se cumplió el objetivo del cambio y corregir si no se logró.
- En cambios relevantes, listar y justificar brevemente las principales decisiones de diseño tomadas.
- Antes de instalar o declarar una dependencia directa solo para resolver `import/no-extraneous-dependencies`, analizar primero si corresponde actualizar la configuración de ESLint `settings.import/core-modules` u otra configuración equivalente del resolver. Si esa configuración resuelve correctamente el caso y la dependencia ya llega por la plataforma/framework, preferir esa solución y no modificar `package.json`.

## Ubicación de habilidades (AgentSkills)
- Mis **AgentSkills** están en: `~/.agents/skills`.

## Regla de paridad para wrappers `cx`/`cxd` (mandatoria)
- Todo cambio en `configs/zsh/.zsh/functions/codex.zsh` debe evaluarse y reflejarse también en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` cuando aplique.
- Todo cambio en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` debe evaluarse y reflejarse también en `configs/zsh/.zsh/functions/codex.zsh` cuando aplique.
- No se permite cerrar una tarea relacionada con `cx` o `cxd` sin revisar explícitamente ambos archivos.
- Si la ejecución de validación de uno de los shells no está disponible en el entorno, se debe informar de forma explícita y concreta en la respuesta final.

### Checklist mínimo antes de cerrar cambios de `cx`/`cxd`
- Confirmar revisión de:
  - `configs/zsh/.zsh/functions/codex.zsh`
  - `configs/PowerShell/Microsoft.PowerShell_profile.ps1`
- Ejecutar validación de sintaxis en `zsh` (`zsh -n ...`) y validación equivalente en `PowerShell` cuando exista el ejecutable.
- Incluir en la respuesta final un bloque breve de estado con:
  - `Verificado zsh: <sí/no + evidencia>`
  - `Verificado PowerShell: <sí/no + evidencia>`

## Reglas específicas para repositorios bajo `~/ghq/work/` (carga condicional)

- Las reglas de plataforma Nordic/MELI (tooling obligatorio, código en inglés y testing específico de `@andes`/`@meli`/`nordic`/`@kraken`) viven en un archivo aparte para no aplicarse fuera de su contexto.
- Condición de carga: leer y aplicar `~/system-config/configs/.codex/AGENTS.work.md` **solo** cuando el directorio de trabajo actual esté ubicado dentro de `~/ghq/work/`.
- Si el repositorio no está bajo esa ruta, no leer ese archivo ni aplicar esas reglas.
