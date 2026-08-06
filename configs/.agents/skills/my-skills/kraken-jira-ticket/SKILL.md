---
name: kraken-jira-ticket
description: >
  Crea o actualiza un ticket de JIRA (padre + subtareas) en el proyecto Kraken / Shipping Groot
  (SGP1) a partir de cambios de cualquier repositorio Git. Descubre la identidad del repositorio y
  la rama base, construye el alcance desde el diff, sincroniza el ticket padre y sus subtareas,
  valida los campos obligatorios de SGP1, enlaza uno o varios pull requests en ambos sentidos y mueve
  a Done el trabajo cuando todos sus PRs están fusionados. Usar cuando se solicite crear, actualizar
  o sincronizar un ticket de Kraken desde los cambios actuales o asociarlo con pull requests.
---

# Kraken JIRA Ticket

Crear o actualizar ticket en **SGP1 — Shipping Groot** desde cambios del repositorio actual.
Requiere Atlassian MCP, GitHub CLI y memory MCP.

> **NUNCA ejecutar `git push`, `git push --force` ni otro comando de upload Git durante esta skill.**
> Gestión de tickets es independiente de publicación del repositorio.

## Idioma obligatorio

Todo contenido visible para personas debe estar en español:

- Summary y description del padre.
- Summary y description de subtareas.
- Encabezados, bullets, tablas, validaciones, advertencias y respuesta final.
- Notas persistidas en memoria.

Conservar en inglés solo identificadores y valores técnicos que deban coincidir con sistemas externos:
paths, symbols, packages, endpoints, labels, field keys, estados/transiciones JIRA (`To Do`,
`In Progress`, `Create New Release`, `Done`) y estados GitHub (`OPEN`, `CLOSED`, `MERGED`).
`## Pull requests` es única excepción de heading: funciona como marker técnico canónico para trazabilidad.

Si issue existente contiene texto humano en inglés, tratarlo como drift y traducirlo durante update.
Antes de cualquier write, validar `summary` y `description` en español.

## Contrato de responsabilidades

| Artefacto | Responsabilidad |
|---|---|
| Padre JIRA | Descripción general, alcance técnico detallado, cobertura automática y links canónicos de PR |
| Subtareas JIRA | Unidades cohesivas de trabajo derivadas del diff |
| Pull request | Resumen para reviewer, tipo de cambio, pruebas manuales, contratos HTTP y notas opcionales |
| Kraken sobre PR | Agregar o normalizar exclusivamente backlink al padre JIRA |

Reglas de separación:

- No copiar descripción JIRA dentro del PR ni cuerpo PR dentro de JIRA.
- Cobertura automática pertenece al padre JIRA; validación manual pertenece al PR.
- Contratos HTTP orientados a reviewer pertenecen a `Cambios en la API` del PR; JIRA describe área técnica sin duplicar matriz de endpoints.
- Kraken nunca regenera título o body con `pr-description-template`; aplica parche `traceability-only`.
- Subtareas nunca reciben sección de links PR.

## Referencias por fase

- Antes de crear, editar o validar cualquier issue, leer
  [contrato de campos JIRA](references/jira-fields.md).
- Cuando existan asociaciones PR, y siempre durante update aunque no haya PR nuevo, leer
  [contrato de trazabilidad](references/pr-traceability.md).
- Antes de decidir o modificar estado del padre, leer
  [máquina de estados](references/status-transitions.md).

## Invariantes bloqueantes

- No crear duplicado cuando ticket ya existe.
- Padre y cada subtarea terminan con labels, quarter y fecha de inicio verificados.
- Todo PR normalizado produce label `<repository_id>/PR-<number>` en padre y subtareas.
- URLs canónicas viven solo en sección `## Pull requests` del padre.
- Identidad y estado PR siempre provienen de GitHub; nunca inferirlos.
- Lookup por labels precede memoria y conflictos de padre detienen flujo.
- Padre solo llega a `Done` cuando colección PR no está vacía y todos están verificados `MERGED`.
- Trazabilidad bidireccional debe pasar antes de transición.
- Gate final debe pasar antes de memoria y respuesta exitosa.
- Checkout actual y diff contra base son fuente de verdad para alcance.

## Paso 1 — Resolver contexto

Resolver root y base branch:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
```

Si remote HEAD falta, elegir primera branch existente: `develop`, `main`, `master`. Preguntar solo si ninguna existe.

Resolver `repository_id`:

1. `application_name` no vacío en `<repo-root>/.fury`.
2. `name` en `<repo-root>/package.json`, sin scope npm.
3. Basename de root, quitando prefijo `fury_` o `fury-`.

Usar `repository_id` en prefix de summary (`[<repository_id>]`) y como project de memoria. No hardcodear nombre de repositorio.

Leer `jira-fields.md`, derivar quarter desde fecha de sistema y resolver option id antes de cualquier write.

Recolectar números/URLs PR explícitos y PR identificable sin ambigüedad desde branch actual. Si hay PR, leer
`pr-traceability.md`, validar inputs y construir `PULL_REQUESTS`, `PR_LABELS` y `ALL_PRS_MERGED`.

## Paso 2 — Descubrir padre existente

Aplicar precedencia:

1. **Key JIRA explícita:** fetch primero; exigir project `SGP1` y type `Task`.
2. **Lookup JQL por cada `PR_LABELS`:** preferido cuando hay PR. Todos deben resolver al mismo padre; conflicto detiene flujo.
3. **Memoria:** fallback solo cuando labels no encuentran ticket.
4. **Creación:** únicamente cuando intención permite crear y no existe padre.

Para memoria:

```text
search_episodic_memories(
  query="jira ticket <repository_id> <branch-or-feature-name> SGP1 kraken",
  project="<repository_id>"
)
```

Si solicitud es solo asociar PR y no hay key explícita ni label match, pedir key padre; no crear ticket implícitamente.

Durante update, leer siempre `pr-traceability.md`, fetch padre y subtareas, redescubrir URLs persistidas,
renormalizar colección completa y repetir control de conflictos antes de editar.

## Paso 3 — Analizar diff

Ejecutar contra `BASE_BRANCH`:

```bash
git log "$BASE_BRANCH"..HEAD --oneline
git diff "$BASE_BRANCH"..HEAD --stat
git diff "$BASE_BRANCH"..HEAD --name-only
git log "$BASE_BRANCH"..HEAD --reverse --format="%aI" | head -1
test -f package.json && grep -E '"[a-z-]+":\s*"[0-9]' package.json | head -20
```

Usar fecha del primer commit (`YYYY-MM-DD`) como start date de padre nuevo. Commits sirven solo para comprender alcance; no copiar lista a JIRA.

Leer archivos representativos por responsabilidad:

- Producción: components, routes, controllers, services, hooks, utilities, config.
- Presentación: styles, templates, stories, assets, copy.
- Contratos: types públicos, schemas, API definitions, manifests, migrations.
- Validación: unit, integration, E2E, fixtures, snapshots.
- Documentación y release metadata cuando cambien.

No asumir framework, lenguaje, layout o package manager desde nombre de repositorio.

## Paso 4 — Construir modelo deseado

### Summary padre

```text
[<repository_id>] <descripción imperativa y concisa en español>
```

Ejemplo: `[groot-ui] Unifica debounce de búsqueda en 500 ms`.

### Description padre

```markdown
## Descripción general
<qué cambió, qué problema resuelve y por qué es necesario>

---

## Alcance técnico

### <Área 1>
- <implementación, configuración, migración, dependencia, componente o servicio>

### <Área 2>
- <cambio relevante>

---

## Cobertura automática
- <pruebas unitarias, integración, E2E o casos borde agregados/actualizados>

## Pull requests
- [owner/repository#123](https://github.com/owner/repository/pull/123)
```

`## Pull requests` se agrega solo cuando hay asociaciones y sigue contrato de `pr-traceability.md`.

No incluir:

- Pasos de pruebas manuales.
- Sección JIRA `Cambios en la API` o matriz de endpoints del PR.
- Lista de commits.
- Texto copiado literalmente del PR.

### Subtareas

Crear una subtarea por unidad cohesiva real:

- Área independiente de código o comportamiento público.
- Contrato, configuración, migración o dependencia sustancial.
- Cobertura/documentación solo cuando formen unidad significativa.

Evitar subtareas de bookkeeping. Description de subtarea explica su propio alcance en español; no reproduce estructura completa del padre ni incluye links PR.

## Paso 5 — Sincronizar JIRA

### Crear

1. Leer payloads en `jira-fields.md`.
2. Crear padre con description deseada y campos obligatorios.
3. Crear subtareas independientes en paralelo, heredando labels, quarter y start date.
4. Mostrar:

| # | Clave | Tipo | Resumen |
|---|---|---|---|
| 1 | `[SGP1-1234](...)` | 📋 Padre | `<summary>` |
| 2 | `[SGP1-1235](...)` | 📎 Subtarea | `<summary>` |

### Actualizar

1. Fetch padre y todas las subtareas en paralelo.
2. Releer diff actual.
3. Comparar summary, description, áreas, subtareas, cobertura, idioma y campos.
4. Preservar labels y contenido no relacionado.
5. Actualizar solo drift real; corregir siempre campos obligatorios faltantes.
6. Ejecutar edits de issues independientes en paralelo; nunca writes concurrentes sobre mismo padre.
7. Crear subtareas faltantes con campos heredados.
8. Mostrar:

| # | Clave | Tipo | Acción | Resumen |
|---|---|---|---|---|
| 1 | `[SGP1-1234](...)` | 📋 Padre | ✏️ Actualizado | `<summary>` |
| 2 | `[SGP1-1235](...)` | 📎 Subtarea | — Sin cambios | `<summary>` |
| 3 | `[SGP1-1236](...)` | 📎 Subtarea | 🆕 Creada | `<summary>` |

Para cualquier update del padre, tenga PR asociados o no, usar `version`, `updated`, relectura inmediata y un solo retry según `pr-traceability.md`. Nunca sobrescribir description concurrentemente.

## Paso 6 — Sincronizar trazabilidad bidireccional

Si hay PR, ejecutar `pr-traceability.md` en este orden:

1. Normalizar sección `## Pull requests` del padre.
2. Confirmar labels en padre y subtareas.
3. Aplicar parche `traceability-only` a cada PR:
   - backlink bajo `## 📝 Descripción`;
   - fallback primer heading;
   - fallback prepend;
   - no tocar título ni contenido protegido.
4. Re-fetch Jira y GitHub.
5. Verificar Jira→PR y PR→Jira.

Si cualquier asociación falla, detener antes de transición y reportar URL/issue exacto. No afirmar trazabilidad completa.

## Paso 7 — Resolver estado padre

1. Reconsultar estado de cada PR desde GitHub.
2. Recalcular `ALL_PRS_MERGED`.
3. Re-fetch status padre.
4. Leer y ejecutar `status-transitions.md`.
5. Verificar status real después de cada transición.

No continuar al gate final si máquina devuelve bloqueo.

## Paso 8 — Gate final

Re-fetch padre, subtareas y todos los PR. Validar:

- Campos obligatorios según `jira-fields.md`.
- Summary/description en español.
- Cobertura completa del diff sin puntos obsoletos.
- Labels y sección Jira→PR según `pr-traceability.md`.
- Backlink PR→Jira único y contenido PR protegido.
- Estado individual actualizado de cada PR.
- Status padre coherente con `status-transitions.md`.

Corregir mismatch local y revalidar elemento. No reiniciar flujo ni repetir transición ya verificada.

Tabla de campos:

| Ticket | Tipo | Label | Labels PR | Links PR | Quarter | Fecha inicio |
|---|---|---|---|---|---|---|
| `[SGP1-1234](...)` | padre | ✅ | ✅ 2/2 | ✅ 2/2 | ✅ Q3/26 | ✅ 2026-07-07 |
| `[SGP1-1235](...)` | subtarea | ✅ | ✅ 2/2 | ➖ solo padre | ✅ Q3/26 | ✅ 2026-07-07 |

Tabla por PR:

| Pull request | Estado | Label JIRA | Jira→PR | PR→Jira |
|---|---|---|---|---|
| `[owner/repo#123](...)` | `MERGED` | ✅ | ✅ | ✅ |

Usar ✅ correcto, ❌ incorrecto, `➖ sin asociaciones` cuando colección vacía y `➖ no aplica: solo padre` para links de subtarea.

## Paso 9 — Guardar memoria y reportar

Solo después de gate exitoso:

1. `search_note` por key ticket.
2. Si no existe, `store_note`; si existe, `update_note`.
3. Título estable: `Ticket JIRA <KEY> para <feature>`.
4. Project: `repository_id`.
5. Body: key, summary, subtareas, status verificado, URLs canónicas, labels, estados PR y `ALL_PRS_MERGED`.

Memoria sirve para discovery; nunca como fuente de identidad, estado o contenido actual.

## Reglas finales

- Nunca ejecutar upload Git.
- Nunca crear duplicado si existe padre válido.
- Nunca omitir campos obligatorios en padre o subtareas.
- Nunca eliminar labels ajenos o asociaciones previas por omisión del prompt.
- Nunca completar padre sin colección PR no vacía y totalmente `MERGED`.
- Nunca editar título PR desde Kraken.
- Nunca regenerar body PR; solo backlink canónico.
- Nunca actualizar desde memoria sin fetch de Jira/GitHub.
- No cerrar tarea hasta gate final completo.
