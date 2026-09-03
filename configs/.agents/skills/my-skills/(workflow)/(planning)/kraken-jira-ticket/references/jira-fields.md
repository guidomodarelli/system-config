# Contrato de campos JIRA para SGP1

Leer esta referencia antes de crear, editar o validar cualquier issue de `kraken-jira-ticket`.

## Configuración fija

| Campo | Valor |
|---|---|
| `cloudId` | `a55c251b-e222-488f-8975-3ccdf0a0db6f` |
| `projectKey` | `SGP1` |
| Label fija | `kraken-user-role` |
| `assignee_account_id` | `712020:8300527c-0cb7-4412-8303-0306dac20649` |
| Tipo padre | `Task` |
| Tipo subtarea | `Sub-task` |

## Campos obligatorios

Todo padre y toda subtarea deben terminar con estos tres campos. Ninguno es opcional.

| Campo | Key | Valor esperado |
|---|---|---|
| Labels | `labels` | Unión deduplicada de labels existentes, `kraken-user-role` y todos los `PR_LABELS` |
| Quarter | `customfield_18353` | `[{'id': '<option-id>', 'value': '<Qx/yy>'}]` |
| Fecha de inicio | `customfield_12410` | `YYYY-MM-DD` |

Reglas:

- Nunca crear, actualizar ni finalizar un issue con alguno de estos campos ausente.
- Cada subtarea hereda conjunto completo de labels, quarter y fecha de inicio del padre.
- Preservar labels ajenos; nunca reemplazar colección completa con labels propias.
- Si existen PR asociados, padre y todas las subtareas llevan todos los `PR_LABELS`.
- URLs de PR pertenecen solo a descripción del padre; nunca a subtareas.

## Resolución de quarter

Resolver quarter nuevamente en cada ejecución usando fecha de sistema:

```bash
date +"%m %Y"
```

| Mes | Quarter |
|---|---|
| `01`–`03` | `Q1` |
| `04`–`06` | `Q2` |
| `07`–`09` | `Q3` |
| `10`–`12` | `Q4` |

Formato final: `Qx/yy`. Ejemplo: `08 2026` → `Q3/26`.

Antes de cualquier write:

1. Obtener metadata de creación o edición para tipo de issue correspondiente.
2. Leer allowed values de `customfield_18353` (`Quarters`).
3. Elegir opción cuyo `value` coincida exactamente con quarter derivado.
4. Usar shape:

```json
[{ "id": "<allowed-value-id>", "value": "<Qx/yy>" }]
```

Nunca usar `[{'name': '<quarter>'}]`. Si option id no puede resolverse, detener flujo antes de modificar JIRA.

## Origen de fecha de inicio

| Operación | Valor |
|---|---|
| Crear padre | Fecha del primer commit de rama desde base (`YYYY-MM-DD`) |
| Crear subtarea | Misma fecha del padre |
| Actualizar padre | Fecha persistida en padre; no recalcular ni reemplazar con fecha actual |
| Actualizar subtarea | Misma fecha persistida en padre |

## Matriz de campos por operación

| Operación | Labels | Quarter | Fecha de inicio | Assignee |
|---|---|---|---|---|
| Crear padre | fija + todos los `PR_LABELS` | quarter actual resuelto | primer commit | fijo |
| Crear subtarea | mismos labels del padre | mismo quarter | misma fecha del padre | fijo |
| Actualizar padre | existentes ∪ fija ∪ `PR_LABELS` | quarter actual resuelto | valor persistido del padre | preservar o fijo si falta |
| Actualizar subtarea | existentes ∪ fija ∪ `PR_LABELS` | mismo quarter esperado | fecha del padre | preservar o fijo si falta |

## Payload base de creación

### Padre

```text
createJiraIssue(
  cloudId: "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  projectKey: "SGP1",
  issueTypeName: "Task",
  summary: "[<repository_id>] <resumen en español>",
  description: "<descripción en español>",
  contentFormat: "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels": ["kraken-user-role", ...PR_LABELS],
    "customfield_18353": [{"id": "<quarter-option-id>", "value": "<Qx/yy>"}],
    "customfield_12410": "<first-commit-date>"
  }
)
```

### Subtarea

```text
createJiraIssue(
  cloudId: "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  projectKey: "SGP1",
  issueTypeName: "Sub-task",
  parent: "<parent-key>",
  summary: "<resumen en español>",
  description: "<descripción en español>",
  contentFormat: "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels": ["kraken-user-role", ...PR_LABELS],
    "customfield_18353": [{"id": "<quarter-option-id>", "value": "<Qx/yy>"}],
    "customfield_12410": "<parent-start-date>"
  }
)
```

## Payload base de actualización

Actualizar solo campos con drift, pero incluir siempre correcciones necesarias de campos obligatorios:

```text
editJiraIssue(
  cloudId: "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  issueIdOrKey: "<issue-key>",
  fields: {
    "summary": "<solo si cambió>",
    "description": "<solo si cambió>",
    "labels": ["<existing>", "kraken-user-role", ...PR_LABELS],
    "customfield_18353": [{"id": "<quarter-option-id>", "value": "<Qx/yy>"}],
    "customfield_12410": "<parent-start-date>"
  }
)
```

Para subtareas, omitir descripción si no cambió y usar siempre fecha del padre. Para padre, coordinación de versión y merge de descripción pertenece a `pr-traceability.md` cuando hay asociaciones PR.

## Checklist bloqueante

Verificar por issue en el gate final (Paso 8), sobre la única relectura completa del flujo; no releer después de cada sincronización:

- [ ] `labels` contiene `kraken-user-role`.
- [ ] `labels` contiene todos los `PR_LABELS` esperados.
- [ ] Labels ajenos previos siguen presentes.
- [ ] `customfield_18353` contiene id y value de quarter esperado.
- [ ] `customfield_12410` contiene fecha esperada.
- [ ] Subtareas coinciden con campos heredados del padre.

Corregir cualquier mismatch y releer solo la issue corregida. Flujo no puede finalizar mientras alguna validación falle.
