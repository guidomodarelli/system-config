---
description: Rules for the agents.
alwaysApply: true
---

# User Rules

## Idioma y comunicación

- Responder en español por defecto para toda comunicación visible al usuario.
- Los planes del agente deben escribirse siempre en español.
- Las preguntas al usuario deben escribirse siempre en español.
- Los updates intermedios, respuestas finales, resúmenes, validaciones y próximos pasos deben escribirse siempre en español.
- Los hallazgos de review deben presentarse siempre en español, aunque el prompt de review, el código o la conversación estén en inglés.
- Los títulos y cuerpos de comentarios inline de review (`::code-comment{...}`) deben escribirse siempre en español.
- Si se usa GitHub CLI/API para crear o actualizar comentarios de review, el comentario publicado debe estar en español.
- Mantener en inglés solo código, identificadores, paths, comandos, logs, errores literales, nombres de APIs, nombres propios técnicos y texto que deba conservarse exactamente.

### Validación mínima de idioma

Antes de cerrar una respuesta o cambio, confirmar que:
- El plan, si existe, está escrito en español.
- Las preguntas visibles al usuario, si existen, están escritas en español.
- Los hallazgos de review, si existen, están escritos en español.
- Los comentarios inline de review, si existen, tienen título y cuerpo en español.
- Los comentarios publicados en GitHub, si existen, están en español.

## Memoria persistente (MCP `memory`) — Mandatorio

- Al inicio de cada sesión o tarea, consultar la integración MCP `memory` para recuperar contexto relevante del usuario y del proyecto.
- Tratar lo recuperado como contexto de fondo: si una memoria nombra un archivo, símbolo o flag, verificar que siga existiendo antes de recomendarlo.
- Cuando se descubra un hecho duradero, guardarlo mediante la integración de memoria siguiendo el alcance y la persistencia definidos por el repositorio actual.

## Rules canónicas adicionales

- Antes de analizar o modificar cualquier código, leer y aplicar `~/.agents/rules/payload-validation-boundaries.md`.
- Esa rule es fuente única para distinguir payload backend/upstream de input y DTO público middleend; no duplicar ni contradecir su contrato en skills, repositorios o instrucciones derivadas.

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
- Nombrar variables, funciones, métodos, clases, archivos, carpetas y demás elementos de forma clara, coherente, concisa, completa y autoexplicativa. → ver "Naming, literales y errores".
- Evitar abreviaciones innecesarias y nombres de una sola letra, salvo convenciones ampliamente aceptadas y justificadas por el contexto. → ver "Naming, literales y errores".
- Documentar con JSDoc o TSDoc cuando el lenguaje, la complejidad o la intención del código lo hagan relevante. → Skill: `enforce-jsdoc-tsdoc`
- Extraer valores hardcodeados con significado funcional a constantes o archivos de configuración cuando mejore la claridad, la reutilización o el mantenimiento. → ver "Naming, literales y errores".
- Modularizar por responsabilidad y organizar el código en estructuras cohesionadas como `utils/`, `constants/`, `services/`, `adapters/` u otras equivalentes cuando corresponda. → ver "Naming, literales y errores" y Skill: `refactor-structure-a11y`
- Priorizar eliminacion de duplicidad, alta cohesión, bajo acoplamiento y principios SOLID cuando aporten valor real al diseño. → Skills: `refactor-structure-a11y`, `mock-first-testing-design`
- Antes de implementar cambios relevantes, identificar módulos y responsabilidades; después del cambio, verificar que cada módulo conserve una responsabilidad clara. → Skill: `refactor-structure-a11y`
- Tras cada edición significativa, incluir una validación breve de 1 a 2 líneas indicando si se cumplió el objetivo del cambio y corregir si no se logró.
- En cambios relevantes, listar y justificar brevemente las principales decisiones de diseño tomadas.
## Naming, literales y errores

### Naming
- Todo identificador (variables, funciones, métodos, clases, enums, types, interfaces, constants, archivos, carpetas, params de arrow functions) debe ser clear, coherent en el codebase, concise, complete y self-explanatory.
- Evitar single-letter salvo loop counters (`i`, `j`, `k`) y contexto matemático (`x`, `y`, `z`). Nunca `(x) => x.id`; usar `(user) => user.id`.
- En `catch`, usar `error` o variante descriptiva (`dbError`, `caughtError`); nunca `e`.
- Evitar abreviaciones salvo universales en el dominio (`id`, `url`, `api`). Un concepto → un nombre (no `user`/`usr`/`u`).
- Carpetas: usar convencionales (`utils/`, `services/`, `components/`, `store/`, `constants/`, `adapters/`) o lowercase kebab-case (`data-fetchers/`).

### Literales hardcodeados
- Extraer literales con significado de negocio, reusados, o env-dependent (status, roles, route fragments, timeouts, retry limits, paginación, feature flags, currency, site values) a constantes nombradas o config.
- Mantener inline lo trivial: `0`, `1`, `-1`, `true`, `false`, empty strings de init, y one-off en scope chico donde el nombre sería más ruidoso que el valor.
- Antes de crear constante, buscar el mismo valor en el codebase. Constante en el scope más angosto que evite duplicación (local → module-level → domain constants file). Config cuando varía por entorno/site/brand/deployment. Reusar `constants/`, `config/`, `settings/` existentes antes de crear estructura.
- Preferir config (no constante) cuando el valor representa endpoints, bucket/topic names, app ids, límites de servicios externos, o se espera tunear sin cambiar lógica de negocio.
- Nombrar por rol, no por valor; incluir unidades (`REQUEST_TIMEOUT_MS`, `DEFAULT_PAGE_SIZE`). No encodear historia de implementación en el nombre.
- Evitar malas extracciones: no crear constante por cada literal mecánicamente, no alejar el valor más de lo necesario, no agrupar literales no relacionados en un `constants.js` genérico, no crear config para invariantes de compile-time, no renombrar constantes compartidas salvo que el refactor lo incluya explícitamente.
- Tras extraer, actualizar imports, tests, mocks y snapshots que dependían del literal.

### Mensajes de error
- Errores y logs específicos y accionables. Evitar genéricos ("Error", "Request failed", "Something went wrong") salvo que estén wrappeados con contexto preciso.
- Incluir la operación (`Component:function failed`), los identificadores mínimos para debuggear (`roleId`, `domainId`, `userId`, `requestId`, valores de filtro/query) y, cuando aplique, contexto de la dependencia: nombre del service/client, HTTP method + path (o endpoint name) y status code, y correlation id (`x-request-id`, trace id).
- Nunca incluir secrets, tokens, cookies, authorization headers ni PII completa; preferir IDs estables. Si se incluye input del usuario, sanitizar y truncar.
- Diferenciar user-facing (corto, claro, safe, puede llevar error code + request id) de logs (contexto técnico + error/stack original).
- Al wrappear/rethrow, adjuntar el error original como `cause`. Sin silent failures: no swallow sin fallback deliberado y log con contexto.
- Si el mismo error se usa en varios lugares, centralizar la construcción del mensaje en un helper.

## Ubicación de habilidades (AgentSkills)
- Mis **AgentSkills** están en: `~/.agents/skills`.
