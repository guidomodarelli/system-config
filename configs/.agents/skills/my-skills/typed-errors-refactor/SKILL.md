---
name: typed-errors-refactor
description: Analiza, diseña y ejecuta refactors de errores tipados en repositorios generales, especialmente JavaScript y TypeScript. Usar siempre cuando el usuario mencione throws o catches genéricos, custom errors, códigos o status inconsistentes, normalización de errores API, filtración de upstream, cause, error boundaries, SSR, cancelación o tests de errores, aunque no pida explícitamente una jerarquía de clases. Preserva comportamiento observable, migra consumers por boundary y agrega tests de contrato sin imponer framework ni patrón de implementación.
compatibility: Requiere acceso al filesystem, git y a las herramientas de validación definidas por el repositorio.
---

# Typed Errors Refactor

## Objetivo

Convertir errores implícitos en contratos explícitos cuando aporten valor en un boundary, sin transformar cada `throw` en una jerarquía innecesaria. La prioridad es preservar comportamiento observable legítimo —códigos, status, retry, fallback, cancelación, copy y side effects— mientras se evita filtrar detalles internos.

Aplicar la skill de forma genérica. Detectar el lenguaje, runtime, arquitectura, validador, logger, transporte y test runner existentes; no imponer Nordic, React, Node, AJV, `schemaValidationMiddleware`, `Result`, clases ni una librería concreta.

## Quick start

1. Resolver repositorio, lenguaje, runtime, comandos, branch/base y alcance.
2. Determinar si el usuario pide análisis, plan o implementación. No editar durante review/análisis sin autorización.
3. Ejecutar baseline de tests y revisar contratos existentes antes de modificar productores.
4. Leer [`error-contract.md`](references/error-contract.md), [`boundary-matrix.md`](references/boundary-matrix.md) y [`testing-matrix.md`](references/testing-matrix.md) según el alcance.
5. Inventariar throws, catches, rejected promises, status/codes, serializadores, logs, loaders, SSR, UI y cancelación.
6. Construir matriz actual → objetivo antes de elegir clases, unions, factories o guards.
7. Migrar por boundary, agregar tests de comportamiento y validar con tooling real del repositorio.

## Inventario mínimo

Adaptar búsquedas al shell y lenguaje. No interpretar el resultado mecánicamente: fixtures, invariantes y cancelaciones pueden tener otra clasificación.

```bash
rg -n "throw |catch|Promise\.reject|\.catch\(" .
rg -n "new Error|AggregateError|Object\.assign\(new Error|throw ['\"]" .
rg -n "error\.(message|name|code|status|cause|response|stack)" .
rg -n "status|reason[_-]?code|errorContext|serialize.*Error|ErrorBoundary|SSR|loader" src app api server lib tests
```

Para cada caso registrar:

| Archivo/símbolo | Fuente | Boundary | Forma actual | Consumers | Efecto observable | Riesgo de exposición |
|---|---|---|---|---|---|---|

Incluir también status HTTP, códigos legacy, mensajes usados como discriminante, retry/backoff, logs, métricas, DTOs públicos, props SSR, fallbacks UI y señales de cancelación.

## Clasificación

Clasificar por semántica y boundary, no solo por el tipo de excepción original:

- `invalid-input` / validation.
- authentication / authorization.
- `not-found`, `conflict` y otras reglas de negocio.
- `dependency-unavailable`, timeout o rate limit.
- `upstream-invalid` cuando la respuesta externa no cumple contrato.
- storage/persistence.
- programmer/unexpected o invariant.
- cancellation (`AbortError`, `CanceledError` o equivalente).

Separar siempre:

- error de dominio;
- mapping de transporte, incluido HTTP status;
- DTO o copy user-facing;
- diagnóstico para logs/telemetry.

No colapsar todo en `UNKNOWN_ERROR`, `500` o `200`. Mantener un fallback final seguro solo para valores no reconocibles.

## Contrato tipado

Consultar [`error-contract.md`](references/error-contract.md). Elegir patrón nativo del repositorio:

- TypeScript: union discriminada, type guard, factory o subclase de `Error` cuando exista una razón real.
- JavaScript: objeto normalizado, factory, guard y JSDoc cuando aporte claridad.
- Otros lenguajes: error/result type idiomático del proyecto.

Contrato mínimo recomendado:

- `code`: identificador estable de máquina, no copy traducible.
- categoría semántica, si el proyecto la usa.
- `cause?: unknown`: diagnóstico interno al envolver, nunca DTO público.
- metadata explícitamente allowlisted por código y limitada a datos seguros.
- retryability u operación equivalente, solo si existe consumidor real.
- mensaje interno separado del mensaje público.

El dominio no debe depender de `httpStatus` numérico. El adapter final decide cómo mapear el error a transporte. No usar `error.message` como contrato estable ni exigir `instanceof` como única detección cuando pueden existir realms, bundles o runtimes distintos.

## Organización física de errores

Cuando el repositorio mantiene errores bajo `api/errors/` u otra carpeta equivalente, agruparlos por dominio funcional para que la estructura refleje sus boundaries:

```text
errors/
├── <domain-a>/
│   ├── index.ts
│   ├── <base-error>.ts
│   └── <specific-error>.ts
├── <domain-b>/
│   └── index.ts
└── <independent-domain>/
    └── index.ts
```

Aplicar estas reglas:

- Mantener una única implementación canónica por clase, factory y type guard. Los índices deben reexportar; nunca duplicar lógica para compatibilidad.
- Usar `index.ts` como entrypoint público del dominio y exportar desde allí los contratos que consumen routes, services, loaders y tests.
- Evitar colisiones entre archivo y carpeta con el mismo basename (`errors/process-contingency.ts` y `errors/process-contingency/`). Si el path público debe conservarse, mover la implementación al directorio y convertir el entrypoint en `index.ts`.
- Conservar shims legacy como archivos que solo reexportan la implementación canónica cuando el path profundo no colisiona con una carpeta nueva. Retirarlos solo después de migrar y validar todos los consumers.
- Mantener imports internos de leaf modules contra sus dependencias canónicas directas, no contra el barrel, para evitar ciclos.
- Preservar el alias que soporte el runtime real (bundler, server y tests); no cambiar a otro alias como efecto incidental del refactor.
- Mantener separados errores server/API y errores client/UI (`api/errors` frente a `app/errors`), especialmente cuando contienen `cause`, respuestas upstream o metadata que no debe llegar al bundle del browser.
- Después de mover módulos, validar resolución de barrels y shims, identidad runtime (`instanceof` cuando exista), type guards, códigos, status, `cause` y metadata mediante tests de comportamiento.

## Migración segura por fases

### Fase 0 — Baseline y caracterización

Capturar tests, respuestas, logs, retry, status, códigos y cancelación existentes. Agregar tests de caracterización cuando un contrato público no esté documentado.

### Fase 1 — Contrato y normalización

Crear tipos, códigos, guards/factories y un normalizer que acepte `unknown`, errores nativos, strings, `null` y errores de terceros. Usar `catch (error: unknown)` en TypeScript. Mantener bridge temporal si hay consumers legacy.

### Fase 2 — Sanitización

Sanitizar primero API, serializadores, logs, telemetry y UI. No mutar el error original para quitar campos: construir DTOs y metadata nuevas con allowlist.

### Fase 3 — Productores

Migrar validadores, reglas de dominio, adapters upstream, persistence y procesos async por módulo. Mantener status, códigos, retry, fallbacks y side effects salvo decisión explícita.

### Fase 4 — Consumers

Migrar rutas, handlers, loaders, SSR, hooks, componentes, jobs y clients para usar guards/codes. Eliminar comparaciones por copy como `message.includes(...)`. Tratar cancelación aparte de errores visibles.

### Fase 5 — Retiro

Buscar throws sin contrato, casts inseguros, bridges, serialización de `cause/stack`, acceso raw a `response` y catches silenciosos. Retirar compatibilidad solo cuando todos los consumers y tests estén migrados.

Ejecutar typecheck, lint y tests focales después de cada fase; luego suite completa y build/runtime cuando existan.

## Seguridad y límites

- Nunca enviar al browser o DTO público raw upstream response, `cause`, `stack`, headers, cookies, tokens, secrets, passwords, CSRF, payloads completos o PII.
- Allowlist metadata por error; limitar nombres, tipos, tamaño y contenido. No usar un `Record<string, unknown>` público sin filtrado.
- Sanitizar logs y truncar input/URLs según convenciones del repositorio.
- Preservar `cause` solo en servidor/diagnóstico controlado.
- No tomar status upstream como autorización ni como semántica de dominio.
- Validar inputs en el boundary con el validador aprobado por el repositorio; no duplicar validación estructural ni reemplazarlo por un middleware legacy sin verificar contrato.
- No silenciar errores sin fallback deliberado, logging seguro y test.
- No modificar auth/authz, CSRF, ownership, retries o métodos HTTP como efecto colateral del refactor.

## Async, cancelación, SSR y UI

Una cancelación intencional no debe mostrar toast o pantalla de error. Propagar `signal`, limpiar listeners/timers y distinguir `AbortError`/equivalentes antes de mapear fallos.

Un React Error Boundary cubre render/lifecycle de descendientes; no reemplaza manejo de handlers, efectos async, Promises, API requests, loaders ni SSR. En SSR/loader, capturar el error server-side y devolver props/DTO controlados, sin stack o causa en HTML. Tests de async, SSR y Error Boundary deben permanecer separados.

## Testing de comportamiento

Consultar [`testing-matrix.md`](references/testing-matrix.md). Cubrir como mínimo:

- éxito y cada variante tipada;
- `unknown` no-`Error`, `null`, string y objeto malformado;
- identidad de `cause` interna;
- mapping upstream → domain → transporte;
- respuesta con shape inválido;
- ausencia de stack, cause, secrets y PII en salida pública/logs;
- retry, fallback y status/código estable;
- cancelación sin feedback de usuario ni actualización stale;
- UI loading/error/empty cuando corresponda;
- SSR props controladas y Error Boundary solo para render.

Testear contratos públicos, integración real del validador cuando sea posible y comportamiento observable. Mockear únicamente dependencias externas en su boundary; no agregar `isTest`, exports artificiales, mocks de SDK interno ni tests que lean strings de archivos fuente.

## Formato de salida

Usar salvo que el usuario pida otro formato:

```markdown
## Alcance y baseline
## Inventario de throws/catches
## Clasificación por boundary
## Contrato tipado propuesto
## Mapping de transporte y sanitización
## Plan de migración
## Tests de comportamiento
## Validación
## Riesgos, incompatibilidades y pendientes
```

Ser explícito sobre errores nativos que se mantienen deliberadamente —por ejemplo invariantes internas, fixtures o cancelación— y sobre cualquier status/código cuyo cambio pueda ser observable.
