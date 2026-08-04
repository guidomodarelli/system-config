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

Create or update a ticket in **SGP1 — Shipping Groot** from current Git repository changes.
Requires Atlassian MCP and memory MCP.

> **NEVER run `git push` or any git upload command during this skill.**
> Ticket management is independent of repository state.

---

## 🇪🇸 IDIOMA OBLIGATORIO — español en todo contenido visible

Toda salida orientada a personas debe escribirse en español, sin depender del idioma del prompt,
del diff, de los commits ni del contenido existente en JIRA.

Esto incluye, sin excepciones:

- Resumen y descripción del ticket padre.
- Resumen y descripción de cada subtarea.
- Encabezados, secciones, listas y texto descriptivo dentro de JIRA.
- Tablas de resultados, validaciones, mensajes de estado, advertencias, preguntas y respuesta final.
- Notas guardadas en memoria sobre el ticket.
- Contenido textual nuevo o modificado durante una actualización.

Conservar en inglés solo elementos técnicos que deban coincidir exactamente con sistemas externos:
identificadores, claves, labels, nombres de campos y APIs, comandos, código, estados y transiciones
de JIRA (`To Do`, `In Progress`, `Create New Release`, `Done`), valores devueltos por GitHub
(`OPEN`, `CLOSED`, `MERGED`) y nombres propios técnicos.

Si un ticket existente contiene resumen o descripción en inglés, considerarlo contenido desactualizado
y traducirlo al español durante la actualización. No traducir literalmente nombres de símbolos,
archivos, rutas, paquetes, endpoints ni otros términos cuya precisión técnica dependa del original.

Antes de crear o editar cualquier issue, validar que `summary` y `description` estén en español.
Antes de finalizar, validar también que toda salida visible generada por la habilidad esté en español.

---

## ⛔ MANDATORY FIELDS — every issue (parent AND every subtask)

Every `createJiraIssue` and every `editJiraIssue` (when creating/completing an issue)
**MUST** carry ALL of these. None is optional. There is no valid ticket without the three:

| Field | Key | Value | Source |
|---|---|---|---|
| **Labels** | `labels` | `["kraken-user-role"]` + PR label when applicable | fixed + PR association |
| **Quarter** | `customfield_18353` | `[{"id": "<option id>", "value": "<Qx/yy>"}]` | derived from `date +"%m %Y"` (Step 1) |
| **Start date** | `customfield_12410` | `"YYYY-MM-DD"` | first commit date on the branch (new) / parent's value (subtasks & updates) |

### PR association labels

When one or more PR numbers or links are provided explicitly or by unambiguous context, normalize
them in Step 1 and add one label per PR to every issue (parent and every subtask):

`<repository_id>/PR-<number>` — e.g. `groot-ui/PR-42`.

The labels array is the deduplicated union of existing labels, `kraken-user-role`, and every PR
association label. Never replace unrelated labels or remove an earlier PR association.

These labels enable deterministic JQL lookup in Step 2 and avoid duplicate tickets without relying
solely on memory. PR URLs themselves belong only in the parent description.

Rules that are NOT negotiable:

- **Never** create or finalize an issue with any of these three missing.
- **Every subtask inherits all three** — same labels, same quarter, same start date as the parent.
- When PR labels are present, **every subtask carries all of them** — same as the parent.
- Quarter is **always** resolved fresh from the system date — never from memory, never guessed.
- Quarter uses the option-object shape `[{"id","value"}]` — never `[{"name":...}]`.
- If you cannot resolve the quarter option id, **stop and resolve it** (Step 1) before creating anything.
- The task is **not done** until Step 8 confirms all three fields on the parent and every subtask.

Do not skip these because the diff is small, the user asked only for "a quick ticket",
or the fields "seem obvious". They are enforced on 100% of issues.

---

## Step 1 — Resolve repository context, fixed JIRA config, and quarter

Resolve repository root and identifiers before reading diffs or creating tickets:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
```

If remote HEAD is unavailable, choose first existing branch in this order: `develop`, `main`,
`master`. Stop and ask only when none exists.

Resolve `repository_id` in this order:

1. Non-empty `application_name` from `<repo-root>/.fury`.
2. `name` from `<repo-root>/package.json`, removing npm scope when present.
3. Git root directory basename, removing a leading `fury_` or `fury-`.

Use `repository_id` for JIRA summary prefix (`[<repository_id>]`) and memory project. Never
hardcode a repository name and never ask for confirmation only because repository differs from
previous skill executions.

SGP1 config is fixed:

| Field | Value |
|---|---|
| `cloudId` | `a55c251b-e222-488f-8975-3ccdf0a0db6f` |
| `projectKey` | `SGP1` |
| `label` | `kraken-user-role` |
| `assignee_account_id` | `712020:8300527c-0cb7-4412-8303-0306dac20649` |
| `issueTypeName` | `Task` |

**Derive the quarter from the system date:**

```bash
date +"%m %Y"
```

| Month | Quarter |
|---|---|
| 01 – 03 | Q1 |
| 04 – 06 | Q2 |
| 07 – 09 | Q3 |
| 10 – 12 | Q4 |

Example: month `06`, year `2026` → `Q2/26`. Use the last two digits of the year.

Before creating or updating issues, resolve the JIRA option id for that quarter:

1. Fetch issue metadata / edit metadata for the SGP1 issue type being created or updated.
2. Read `customfield_18353` (`Quarters`) allowed values.
3. Select the option whose `value` equals the derived quarter.
4. Set `customfield_18353` with the option object:

```json
[{ "id": "<allowed-value-id>", "value": "<Q derived from system date>" }]
```

Do not use `[{ "name": "<quarter>" }]`; JIRA ignores that shape for this field.

### Resolve and normalize pull requests

Before any JQL lookup or JIRA modification, collect every PR number or link explicitly provided and
any PR identified unambiguously from current branch. Accept only decimal numbers or URLs matching
`https://github.com/<owner>/<repo>/pull/<number>`. Reject all other shapes. Pass validated input as
one quoted argument:

```bash
gh pr view "<validated-number-or-url>" --json number,url,headRefName,baseRefName,state
```

Store results in `PULL_REQUESTS`, with `number`, canonical `url`, `owner/repo`, `repository_id`,
`headRefName`, `baseRefName`, and exact `state` (`OPEN`, `CLOSED`, or `MERGED`).

- A bare number belongs to the current repository. Use a canonical URL for cross-repository PRs.
- Derive `owner/repo` from URL returned by GitHub. Derive each PR's `repository_id` using Step 1
  rules for that repository: `.fury` application name when available, package name when available,
  otherwise GitHub repository basename with standard prefix normalization.
- Deduplicate by canonical URL, then sort by `owner/repo` and number for stable output. A PR number
  alone is not globally unique.
- Never trust or persist unverified URL. If `gh pr view` fails, build API path only from validated
  owner, repository, and decimal number; quote every argument and verify returned `html_url`, number,
  repository, and state match parsed identity. Otherwise stop before modifying JIRA.
- Never infer state from branch existence, commit history, local refs, labels, description, or memory.
- During an update, Step 7 adds every canonical URL already stored in the parent description to
  `PULL_REQUESTS` and resolves it again. New input augments existing associations; it never replaces
  them.

Define `PR_LABELS` from `PULL_REQUESTS` using `<repository_id>/PR-<number>`. Define
`ALL_PRS_MERGED` as true only when collection is non-empty and every state is `MERGED`.

---

## Step 2 — Check for an existing ticket

If user provides a JIRA key, fetch it first and require project `SGP1` plus issue type `Task`. This
explicit parent takes precedence over memory, but not over conflict validation: every PR-label JQL
match must resolve to same key or flow stops. When request is specifically to associate PRs and no
explicit key or label match identifies a parent, ask for parent key instead of creating a ticket.

### 2a — JQL lookup by PR labels (preferred when `PULL_REQUESTS` is non-empty)

Search each value in `PR_LABELS`. Request `summary`, `description`, `status`, `labels`, and
`subtasks`, then group results by parent Task. Confirm canonical PR URL in parent description or
explicit parent key before accepting ambiguous label matches.

- No match → continue to 2b or create a ticket.
- Every match resolves to the same parent → use that ticket and go to Step 7. Add any unmatched PRs
  to this same parent during synchronization.
- Different labels resolve to different parents → stop and report each conflicting PR and ticket.
  Never select one arbitrarily or create a third ticket.
- One label resolves to multiple Tasks → stop and report duplicate JIRA associations.

Memory is a fallback only when no PR label produces a valid match.

### 2b — Memory fallback (when PR labels return nothing)

Search memory for a recent ticket on the same branch or feature:

```
search_episodic_memories(
  query="jira ticket <repository_id> <branch-or-feature-name> SGP1 kraken",
  project="<repository_id>"
)
```

- If a ticket already exists and its description is **incomplete or outdated**, update it with
  `editJiraIssue` — do not create a duplicate.
- If no ticket exists, proceed to create one.

---

## Step 3 — Gather the git diff

Run in parallel with resolved `BASE_BRANCH`:

```bash
git log "$BASE_BRANCH"..HEAD --oneline
git diff "$BASE_BRANCH"..HEAD --stat
git diff "$BASE_BRANCH"..HEAD --name-only
git log "$BASE_BRANCH"..HEAD --reverse --format="%aI" | head -1   ← first commit date (ISO)
test -f package.json && grep -E '"[a-z-]+":\s*"[0-9]' package.json | head -20
```

Extract the **first commit date** (the earliest commit on the branch since it diverged from
`BASE_BRANCH`). Use the `YYYY-MM-DD` portion as the start date for new tickets.

Use commits only to understand scope; never copy commit lists into ticket. Read version numbers
from manifest files directly, never from commit messages.

Read representative changed files by responsibility:

- Production code: components, routes, controllers, services, hooks, utilities, configuration.
- Presentation: styles, templates, stories, assets, user-facing copy.
- Contracts: public types, schemas, API definitions, manifests, migrations.
- Validation: unit, integration, E2E tests, fixtures, snapshots.
- Documentation and release metadata when changed.

Do not assume framework, language, folder layout, or package manager from repository name.

---

## Step 4 — Build the ticket

### Summary format

`[<repository_id>] <descripción imperativa y concisa del cambio principal en español>`

Ejemplo: `[groot-ui] Unifica el debounce de búsqueda en 500 ms`

### Description structure (markdown)

```markdown
## Descripción general
<resumen de 1–2 oraciones en español sobre qué cambió y por qué>

---

## Cambios

### <Área 1>
- <punto en español por cada cambio relevante>

### <Área 2>
- …

### Pruebas
- <cobertura de pruebas agregada o actualizada, en español>

## Pull requests

- [owner/repository#123](https://github.com/owner/repository/pull/123)
```

`## Pull requests` is a canonical technical marker and the only exception to Spanish headings. Add
it only to the parent when `PULL_REQUESTS` is non-empty. Use one item per canonical URL, display
`owner/repo#number`, and do not persist state because it can become stale.

Escribir los demás encabezados y puntos en español, con precisión técnica y sin relleno. No incluir
listas de commits: la descripción debe explicar qué se construyó, no reproducir el historial Git.

---

## Step 5 — Create or update the ticket

### Create

```
createJiraIssue(
  cloudId:          "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  projectKey:       "SGP1",
  issueTypeName:    "Task",
  summary:          "[<repository_id>] <resumen en español>",
  description:      "<descripción en español>",
  contentFormat:    "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels":            ["kraken-user-role", ...PR_LABELS],
    "customfield_18353": [{"id": "<quarter option id>", "value": "<Q derived from system date>"}],
    "customfield_12410": "YYYY-MM-DD"  ← start date = first commit date on the branch (from Step 3)
  }
)
```

Create the parent description with the canonical `Pull requests` section when associations exist.
When `PULL_REQUESTS` is empty, omit the section and `PR_LABELS`.

### Update (if ticket already exists)

Go directly to **Step 7** — do not edit the ticket here. Step 7 handles fetching the current
state, comparing against the diff, and updating parent + subtasks in the correct order.

---

## Step 6 — Create subtasks (new tickets only)

After creating parent, identify natural work units from actual diff and create one subtask per
cohesive area. Common splits:

- One subtask per independent production-code area or public behavior.
- One subtask for contract, configuration, migration, or dependency work when substantial.
- One subtask for tests and documentation when they form meaningful work units.

Avoid empty bookkeeping subtasks and avoid assuming UI work.

Each subtask must inherit **the same labels, quarter, and start date** as the parent:

```
createJiraIssue(
  cloudId:          "a55c251b-e222-488f-8975-3ccdf0a0db6f",
  projectKey:       "SGP1",
  issueTypeName:    "Sub-task",
  parent:           "SGP1-XXXX",          ← key of the parent ticket
  summary:          "<título imperativo y conciso en español>",
  description:      "<descripción en español>",
  contentFormat:    "markdown",
  assignee_account_id: "712020:8300527c-0cb7-4412-8303-0306dac20649",
  additional_fields: {
    "labels":            ["kraken-user-role", ...PR_LABELS],   ← same complete set as parent
    "customfield_18353": [{"id": "<quarter option id>", "value": "<Q derived from system date>"}],
    "customfield_12410": "YYYY-MM-DD"            ← same start date as parent
  }
)
```

Create all subtasks in parallel. Subtask descriptions follow the same Spanish structure as the
parent (`Descripción general` optional, `Cambios` bullets, no commit list).

After creating parent and subtasks, display the created tickets as a summary table in Spanish:

```
| # | Clave | Tipo | Resumen |
|---|---|---|---|
| 1 | [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234) | 📋 Padre | [groot-ui] Unifica el debounce de búsqueda en 500 ms |
| 2 | [SGP1-1235](https://mercadolibre.atlassian.net/browse/SGP1-1235) | 📎 Subtarea | Agrega utilidad de debounce con demora configurable |
| 3 | [SGP1-1236](https://mercadolibre.atlassian.net/browse/SGP1-1236) | 📎 Subtarea | Actualiza componentes de búsqueda para usar debounce compartido |
| 4 | [SGP1-1237](https://mercadolibre.atlassian.net/browse/SGP1-1237) | 📎 Subtarea | Agrega pruebas unitarias para el comportamiento de debounce |
```

---

## Step 7 — Update existing ticket (update path only)

When the user asks to **update** an existing ticket, replace Steps 5–6 with this flow.

### 7a — Fetch current state in parallel

```
getJiraIssue(cloudId, parentKey)               ← parent title + description
getJiraIssue(cloudId, subtask1Key)             ← subtask title + description
getJiraIssue(cloudId, subtask2Key)             ← …
…
```

Fetch all known subtasks in parallel. Use memory (Step 2) or ask the user if the subtask keys are unknown.

Before comparing drift, parse the parent's existing `## Pull requests` section. Resolve every URL
again with Step 1 and union it with new input in `PULL_REQUESTS`; never remove an existing
association because it was omitted from the current request. If a legacy PR label has no URL,
reconstruct it only when it unambiguously identifies a PR in the current repository. Otherwise stop
and request the canonical URL rather than inventing an owner or repository.

Parent description is persistent source of PR associations. After adding stored URLs, deduplicate
and sort `PULL_REQUESTS` again, regenerate `PR_LABELS`, recalculate `ALL_PRS_MERGED`, and repeat
Step 2a conflict checks for complete collection before any edit. Use only recomputed values in all
remaining steps. Stop if late-discovered or new association maps to another parent.

Description must contain at most one canonical section. Merge canonical URLs into it, preserve all
other content without functional drift, and combine read-modify-write with any other parent update.
If no section exists, append it. Subtask descriptions never receive this section.

### 7b — Re-read the diff

Re-run Step 3 to get the current state of the branch. The code is the source of truth — not what was previously in JIRA.

### 7c — Compare and identify drift

For each element, compare what JIRA has vs what the code shows:

| Elemento | Qué verificar |
|---|---|
| Título del padre | ¿Sigue siendo preciso, cubre todo el alcance y está en español? |
| Descripción del padre | ¿Cubre todas las áreas, no contiene puntos obsoletos ni commits y está en español? |
| Títulos de subtareas | ¿Cada título representa una unidad real y autocontenida, y está en español? |
| Descripciones de subtareas | ¿Los puntos coinciden con la implementación, no están obsoletos y están en español? |
| Cobertura | ¿Existen áreas del diff sin cubrir por ninguna subtarea? |

Any human-facing text in English counts as drift and must be translated to Spanish, even when its
technical content remains accurate.

### 7d — Apply updates in parallel

Update only what has drifted. For every issue, preserve unrelated labels and union them with
`kraken-user-role` and all `PR_LABELS`. For the parent, include the merged canonical PR section in
the same write as any summary, description, label, or mandatory-field correction:

```
editJiraIssue(cloudId, parentKey, fields: {
  version: <read-version>, summary: "…", description: "<merged description>",
  labels: ["<existing>", "kraken-user-role", ...PR_LABELS],
  customfield_18353: [{ id: "<quarter-id>", value: "<quarter>" }],
  customfield_12410: "<parent-start-date>"
})
editJiraIssue(cloudId, subtaskKey, fields: {
  summary: "…", labels: ["<existing>", "kraken-user-role", ...PR_LABELS],
  customfield_18353: [{ id: "<quarter-id>", value: "<quarter>" }],
  customfield_12410: "<parent-start-date>"
})
```

Run independent issue edits in parallel, but never concurrent writes to same parent. Read issue
`version`, `updated`, and full description immediately before merge; include that `version` as
optimistic precondition in parent update. On conflict, re-fetch, merge over newest body, and retry
once. If MCP/API cannot enforce version precondition, do not perform description read-modify-write:
report that concurrent-edit safety cannot be guaranteed and ask user to rerun after conflict clears.

### 7e — Create missing subtasks

If the diff contains work areas not covered by any existing subtask, create the missing ones
using the same fields as Step 6: `issueTypeName: "Sub-task"`, `parent`,
`labels: ["kraken-user-role", ...PR_LABELS]`, `customfield_18353` (quarter option id/value from
system date), and `customfield_12410` (start date —
same value as the parent ticket's start date, read from `getJiraIssue` in step 7a).

After updating/creating, display all tickets (updated and new) as a summary table in Spanish:

```
| # | Clave | Tipo | Acción | Resumen |
|---|---|---|---|---|
| 1 | [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234) | 📋 Padre | ✏️ Actualizado | [groot-ui] Unifica el debounce de búsqueda en 500 ms |
| 2 | [SGP1-1235](https://mercadolibre.atlassian.net/browse/SGP1-1235) | 📎 Subtarea | ✏️ Actualizada | Agrega utilidad de debounce con demora configurable |
| 3 | [SGP1-1236](https://mercadolibre.atlassian.net/browse/SGP1-1236) | 📎 Subtarea | — Sin cambios | Actualiza componentes de búsqueda para usar debounce compartido |
| 4 | [SGP1-1237](https://mercadolibre.atlassian.net/browse/SGP1-1237) | 📎 Subtarea | 🆕 Creada | Agrega pruebas de integración para casos límite de debounce |
```

Use `✏️ Actualizado` / `✏️ Actualizada` for modified issues, `🆕 Creado` / `🆕 Creada` for new
ones, and `— Sin cambios` for untouched issues.

---

## Step 8 — Validate parent and subtasks (BLOCKING GATE)

This gate is mandatory. Validate JIRA fields and Jira→PR links here, then repeat association and
status checks after Step 9b so PR→Jira links are included. Task is **not complete** until final pass.

After creating or updating, fetch parent and every subtask in parallel. Verify on every issue:

- [ ] `labels` contains `kraken-user-role` and every value in `PR_LABELS`
- [ ] unrelated existing labels remain present
- [ ] `customfield_18353` contains expected quarter id and value
- [ ] `customfield_12410` contains expected start date

Verify additionally on parent only:

- [ ] exactly one `## Pull requests` section when `PULL_REQUESTS` is non-empty
- [ ] every canonical URL appears exactly once and every previously stored URL remains present
- [ ] no subtask description contains the canonical section

Patch any mismatch and re-fetch. If parent description changed concurrently, apply the one-retry
merge rule from Step 7. Do not close task until every issue and association passes.

Report the result as a markdown table in Spanish:

```
| Ticket | Tipo | Label | Labels de PR | Links de PR | Trimestre | Fecha de inicio |
|---|---|---|---|---|---|---|
| [SGP1-1234](https://mercadolibre.atlassian.net/browse/SGP1-1234) | padre | ✅ | ✅ 2/2 | ✅ 2/2 | ✅ Q3/26 | ✅ 2026-07-07 |
| [SGP1-1235](https://mercadolibre.atlassian.net/browse/SGP1-1235) | subtarea | ✅ | ✅ 2/2 | ➖ solo padre | ✅ Q3/26 | ✅ 2026-07-07 |
```

Use ✅ for correct, ❌ for wrong, `➖ sin asociaciones` when collection is empty, and
`➖ no aplica: solo padre` for subtask link column. Report expected/verified counts.

---

## Step 9 — Transition parent according to aggregate PR state

Transitions apply only to parent. When `PULL_REQUESTS` is non-empty, execute and verify Step 9b
before any status transition; return here only after every PR→Jira link passes. Fetch exact current
status before every transition and never move it backwards.

### Not every associated PR is verified as merged

For a new ticket, keep **Backlog → To Do → In Progress** flow:

```
transitionJiraIssue(cloudId, issueIdOrKey, { id: "331" })   ← "To Do" (status id 10000)
transitionJiraIssue(cloudId, issueIdOrKey, { id: "71" })    ← "Start progress" → In Progress
```

| Step | Transition name | Transition id | Target status |
|---|---|---|---|
| 1 | To Do | 331 | To Do (10000) |
| 2 | Start progress | 71 | In Progress (12834) |

- Transition 71 is only available from "To Do" — step 1 is required first.
- If transition 331 is unavailable, use 51 ("Selected to Development") — same target status 10000.
- Skip statuses parent already reached.
- When `PULL_REQUESTS` is empty, preserve existing behavior and never complete an existing ticket.
- If any PR is `OPEN` or `CLOSED` without merge, do not complete parent; existing ticket keeps its
  status and new ticket ends in **In Progress**.
- If any PR state cannot be verified, do not change JIRA status.
- If parent is already **Done** and any associated PR is not merged, never move it backwards; report
  inconsistency for human review.

### ALL_PRS_MERGED is true — transition to Done

Only a non-empty collection where every PR is verified `MERGED` may leave parent in **Done**,
whether ticket was created now or already existed. Follow ordered status path:

```
To Do → In Progress → Create New Release → Done
```

1. Fetch the parent with `getJiraIssue` and read its exact current status.
2. If it is before **To Do**, apply transition 331; if unavailable, apply 51.
3. Re-fetch. If it is **To Do**, apply transition 71 to reach **In Progress**.
4. Re-fetch and call `getTransitionsForJiraIssue`. Select the available transition whose name or
   target status is exactly `Create New Release`, then pass its returned id to
   `transitionJiraIssue`.
5. Re-fetch and call `getTransitionsForJiraIssue` again. Select the available transition whose
   target status is exactly `Done`, then pass its returned id to `transitionJiraIssue`.
6. Re-fetch the parent and block completion until its status is exactly **Done**.

Rules:

- Resolve the `Create New Release` and `Done` transition ids from JIRA at execution time; do not
  guess or hardcode ids that were not returned for the current issue.
- If the parent already occupies a status in the ordered path, resume from that status and skip
  completed steps. If it is already **Done**, perform no transition and only verify it.
- Never jump directly from **In Progress** to **Done**. **Create New Release** is mandatory.
- After each transition, re-fetch the parent before resolving the next transition.
- If an expected transition is unavailable or a transition does not reach its expected status,
  stop, report current status and available transition names, and do not claim completion.
- After status decision or transition, execute final Step 8 pass described in Step 9b.

---

## Step 9b — Update every PR description with Jira link

When `PULL_REQUESTS` is non-empty, make reverse traceability mandatory for every canonical PR URL.
For each PR:

1. Read `body` and `url` with `gh pr view <canonical-url> --json body,url`.
2. Normalize body to exactly one exact Jira link: if duplicates exist, remove all copies before
   reinserting one; if exactly one already occupies canonical position, leave body unchanged.
3. Insert canonical link immediately after first `#` heading. If body has no heading, prepend link
   plus blank line. Preserve every other byte of existing content.
4. Write multiline body through temporary file:
   `gh pr edit <canonical-url> --body-file <temporary-file>`.
5. Re-read body and verify exact Jira link appears once. Delete temporary file.

Use canonical URL as command argument so PRs from other repositories work independently of current
checkout. If any PR cannot be updated or verified, report URL and stop without claiming complete
cross-traceability; do not roll back PRs already updated and do not duplicate links on retry.

Re-fetch every PR and confirm reverse link before returning to Step 9. After status decision and any
transition, complete Step 8 final pass: re-fetch parent, subtasks, and PRs; confirm URLs, labels,
individual states, final JIRA status, and both directions. Report one row per PR with canonical URL,
GitHub state, JIRA label, Jira→PR result, and PR→Jira result.

---

## Step 10 — Save to memory

After successful final gate, use note memory consistently with stable title
`Ticket JIRA <KEY> para <feature>` and `repository_id` project:

1. Call `search_note` with ticket key.
2. If absent, call `store_note` once.
3. If present, call `update_note` with returned note id.

Body contains ticket key, summary, subtask keys, verified JIRA status, arrays of canonical PR URLs,
association labels and individual GitHub states, plus `ALL_PRS_MERGED`. Memory is discovery context,
never source of truth for PR identity, state, or current JIRA content.

---

## Rules

- **NEVER** run `git push`, `git push --force`, or any git upload command.
- Do not create a duplicate if a ticket already exists — update it instead.
- **The three mandatory fields (labels, quarter, start date) go on EVERY issue — parent and every subtask. No exceptions.** See the "MANDATORY FIELDS" block at the top.
- Label `kraken-user-role` is mandatory for every kraken ticket.
- Every normalized PR requires one `<repository_id>/PR-<number>` label on parent and subtasks.
- Canonical PR URLs live only in one `## Pull requests` section in parent description; preserve earlier associations.
- Resolve every PR identity and state from GitHub before JIRA writes or transitions; never infer them.
- Parent reaches **Done** only when `ALL_PRS_MERGED` is true, through **To Do → In Progress → Create New Release → Done**.
- JQL lookup across every PR label precedes memory; conflicting parent matches block modification.
- Quarter (`customfield_18353`) must always be set; derive it from `date +"%m %Y"` — never from memory. Use the `[{"id","value"}]` shape.
- Start date (`customfield_12410`) must always be set: first commit date on the branch for new tickets (derived from `git log BASE_BRANCH..HEAD --reverse --format="%aI" | head -1`), the parent's value for subtasks and updates.
- Every subtask inherits all parent labels, quarter, and start date, but never parent PR-link section.
- Step 8 is a **blocking gate**: confirm fields, labels, canonical links, preservation, and reverse links.
- Summary and description must be in **Spanish** for the parent and every subtask. All human-facing skill output must also be in Spanish.
- Repository identity, base branch, file layout, language, and framework must be discovered from
  current checkout; none may be hardcoded.
- On update: fetch parent + all subtasks before editing — never update from memory alone.
- On update: run all `editJiraIssue` calls in parallel to minimize round-trips.
- On update: only patch fields that actually changed — do not rewrite accurate content, but always re-verify the mandatory fields survived.
