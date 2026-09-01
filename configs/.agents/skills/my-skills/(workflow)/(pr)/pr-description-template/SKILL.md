---
name: pr-description-template
description: "Provides the standard PR title and concise description template (change type, manual validation, optional API changes, reviewer notes) plus a traceability-only mode that preserves existing PR content. Use whenever creating, filling, or intentionally restructuring a pull request body — explicitly or implicitly — including /feature-branch-pr, 'crear PR', 'abrir pull request', 'subir cambios y crear PR', or gh pr create."
allowed-tools: Bash(gh:*) Bash(git:*)
---

# PR Description Template

Use this skill any time a pull request body has to be written or filled. It defines the canonical title + description so every PR looks consistent.

## Alcance estricto

Ejecutar únicamente acciones necesarias para componer, aplicar o verificar título y body del PR solicitado.

- Leer diff solo como evidencia para redactar descripción; no tratarlo como pedido implícito de review.
- No iniciar code review, security audit, dependency audit, performance review ni análisis adicional salvo pedido explícito.
- No ejecutar tests, builds, linters, scanners ni validaciones del repositorio salvo pedido explícito.
- No invocar skills, agentes o workflows ajenos a composición del PR salvo pedido explícito o delegación directa del flujo llamador. Si una regla de mayor prioridad obliga una invocación, limitarla a determinar aplicabilidad; no expandir alcance.
- No modificar código, dependencias o configuración.
- No crear ni actualizar Jira, labels, review comments, approvals, merge ni estado del PR.
- Writes permitidos: crear PR cuando flujo llamador lo pida, o editar únicamente title/body del PR explícitamente solicitado.
- En modo `traceability-only`, único write permitido es backlink body-only delegado; no retemplar PR.
- Si una acción no es requisito directo para descripción pedida, omitirla.

## Aplicación directa obligatoria

- Cuando el usuario invoque `/pr-description-template` o mencione explícitamente esta skill, interpretar la solicitud como una orden de aplicar el cambio directamente sobre el PR; no responder con un borrador para copiar manualmente.
- Localizar el PR asociado mediante `gh pr view --json number,title,body,url,headRefName,baseRefName`. Para un PR existente, aplicar la modificación con `gh pr edit <number-or-url> --body-file <temp-file>` y agregar `--title` únicamente cuando corresponda a una composición completa. Para un PR nuevo, usar `gh pr create --body-file <temp-file>` cuando el flujo llamador haya pedido crearlo.
- Verificar cada escritura con `gh pr view --json title,body,url` antes de informar resultado.
- No imprimir en chat el title, body, template ni contenido completo generado. Informar únicamente operación realizada, PR afectado, URL y verificación; si la operación falla o no existe un PR aplicable, informar bloqueo concreto sin pegar un body alternativo.
- Solo devolver contenido de title/body si el usuario solicita explícitamente un borrador, preview o contenido sin aplicación directa.

Triggers (explicit or implicit):
- the user runs `/feature-branch-pr` (the [feature-branch-pr](../feature-branch-pr/SKILL.md) skill must use this template for the PR body)
- the user asks to "crear PR", "abrir pull request", "subir cambios y crear PR", "branch + commit + push + PR"
- any flow that ends in `gh pr create` / editing a PR body and needs a title + description

## Modes

### Full composition

Use for new PRs or when the user explicitly asks to fill or restructure the complete title/body. Apply the template below from the actual diff.

### Traceability-only patch

Use when another skill updates an existing PR only to add or normalize traceability metadata.

- Do not regenerate the template or edit the PR title.
- Do not add or recompute the initial `<sub>` file-count metadata.
- Do not modify **Tipo de Cambio**, **Pruebas Manuales**, **Cambios en la API**, optional sections, reviewer notes, or unrelated ticket links.
- A canonical Jira backlink may be inserted as the first content under `## 📝 Descripción`; this is not the removed top-level **Referencia** metadata block.
- Delegate position, legacy cleanup, deduplication, concurrency, and byte-preservation rules to [pr-traceability.md](../kraken-jira-ticket/references/pr-traceability.md).
- Read `title`, `body`, and `url`; edit only through `gh pr edit <url> --body-file <temp-file>` without `--title`.
- Re-read the PR and verify title identity plus protected body content after the patch.

### Initial file-count metadata

Apply only during `full composition`, before writing the body. Obtain the changed paths from the actual PR comparison range (`base...head`), not from the whole repository, a line-count statistic, or unrelated working-tree changes. For a caller that already resolved the range, reuse its exact `git diff --name-only` output.

- Exclude paths containing a `test`, `tests`, `__tests__`, `mock`, `mocks`, or `__mocks__` path segment.
- Exclude basenames with `.test.*`, `.spec.*`, or `.mock.*` suffixes.
- Exclude image extensions (`.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.avif`, `.ico`, `.bmp`, `.tif`, `.tiff`) and stylesheet extensions (`.scss`, `.sass`).
- From paths that remain, count only names ending in `.js`, `.jsx`, `.ts`, or `.tsx`, case-insensitively. This includes dotfiles such as `.eslintrc.js`; count files, not changed lines.
- Emit `0` when no eligible path remains. If comparison range cannot be determined, stop and report the concrete blocker instead of inventing a number.

Use a path-based count equivalent to:

```bash
git diff --name-only "$BASE_REF...$HEAD_REF" |
awk '
  {
    path = tolower($0)
    if (path ~ /(^|\/)(__tests__|__mocks__|tests?|mocks?)(\/|$)/) next
    if (path ~ /(^|\/)([^\/]*[-_.])?(test|tests|mock|mocks)([-_.][^\/]*)?\.[^\/]+$/) next
    if (path ~ /(^|\/)[^\/]+\.(spec)\.[^\/]+$/) next
    if (path ~ /\.(png|jpe?g|gif|svg|webp|avif|ico|bmp|tif|tiff|scss|sass)$/) next
    if (path ~ /\.[tj]sx?$/) count++
  }
  END { print count + 0 }
'
```

Place exactly one line, `<sub>📄 Archivos de código modificados: N</sub>`, as the first body content, followed by one blank line and `## 📝 Descripción`. Replace `N` with computed integer; never leave placeholder text. Do not add this line in `traceability-only`.

## Full-composition rules

- Fill every section from the actual diff — never leave the `*italic placeholders*`. Delete sections that genuinely do not apply (e.g. **Decisiones técnicas relevantes**, **Cambios en la API**, or **Notas para el Revisor**).
- Start the body with the generated `<sub>` file-count line, then one blank line and **Descripción**. The PR title already carries the change summary, so do not repeat it as a body heading.
- Do not add a compact **Tipo** metadata block above **Descripción**. In **Tipo de Cambio**, mark exactly one primary category with `[x]` and leave every other category unmarked with `[ ]`.
- Include ordinary ticket or issue links naturally in **Descripción** or **Notas para el Revisor**; do not create a fixed metadata block.
- When fully composing an existing PR, preserve every canonical `🎫 Jira: [...]` backlink already present. Extract backlinks before replacing body and reinsert each once as first content under `## 📝 Descripción`; never drop established traceability.
- New or legacy backlink normalization follows traceability-only mode; full composition preserves known canonical backlinks but does not invent Jira associations.
- In **Cambios en la API**, keep only operation groups that apply (**Agregados**, **Modificados**, **Eliminados / Deprecados**) and delete unused lines.
- **Pruebas Manuales** is mandatory: list reproducible steps a reviewer can follow. Mention automated coverage inside **Descripción** only when it adds relevant context. Do **not** state which validations you personally ran.
- Body text is in Spanish; keep code, paths, endpoints, branch and identifier names in English.
- Apply complete PR body directly with `gh`, unless user explicitly asks for draft only.
- For an existing PR under full composition, locate it with `gh pr view --json number,title,body,url,headRefName,baseRefName`, write filled template to temp file, and run `gh pr edit <number-or-url> --title "<title>" --body-file <temp-file>`.
- For a new PR, pass body to `gh pr create` via `--body-file` rather than fragile inline `--body` string.
- After `gh pr edit` or `gh pr create`, verify result with `gh pr view --json title,body,url`.

## Title

Single line, descriptive, English-friendly subject. Example: `Add user status sidebar element to detail views`. Use it only as the PR title; do not repeat it inside the body.

## Body template

```markdown
<div align="right"><sup>📄 Archivos de código modificados: N</sup></div>

## 📝 Descripción

### ❓ ¿Qué problema resuelve?
*Contexto del problema de negocio o técnico. ¿Por qué es necesario este cambio?*

### 💡 ¿Cuál fue la solución?
*Resumen técnico de la implementación. Componentes, servicios y archivos clave modificados.*

### 🤔 Decisiones técnicas relevantes *(si aplica)*
*Trade-offs, alternativas descartadas o restricciones que ayuden a comprender la solución. Eliminar esta sección cuando no aporte contexto.*

---

## 🚀 Tipo de Cambio

> _Marcar una sola categoría principal con `[x]` y dejar las demás sin marcar._

- [ ] 🐛 **Bug Fix** — corrige comportamiento defectuoso
- [ ] ✨ **New Feature** — agrega funcionalidad nueva
- [ ] 💥 **Breaking Change** — modifica un contrato o comportamiento incompatible
- [ ] ⚡ **Performance** — mejora tiempos, uso de recursos o escalabilidad
- [ ] 🧹 **Refactor** — reestructura código sin cambiar comportamiento
- [ ] 🧪 **Tests** — agrega o mejora cobertura sin cambiar producción
- [ ] 📄 **Documentation** — actualiza documentación sin cambiar código funcional
- [ ] 🏗️ **Build** — modifica compilación, empaquetado o herramientas de build
- [ ] 👷 **CI/CD** — modifica pipelines, checks o automatización de entrega
- [ ] ⬆️ **Dependencies** — actualiza, agrega o elimina dependencias
- [ ] ⚙️ **Chore** — mantenimiento sin impacto funcional directo
- [ ] ↩️ **Revert** — revierte un cambio anterior

---

## 🖐️ Pruebas Manuales

> _Pasos reproducibles para validar el cambio._

**🌐 Entorno:** `<URL / ambiente, si aplica>`

1. `<Acción a realizar>` → `<Resultado esperado>`
2. `<Acción a realizar>` → `<Resultado esperado>`

---

## 🔄 Cambios en la API *(si aplica)*

- ➕ **Agregados:** `POST /api/v1/...`
- ✏️ **Modificados:** `PUT /api/v1/.../{id}`
- ➖ **Eliminados / Deprecados:** `GET /api/v1/...`

---

## 👀 Notas para el Revisor *(si aplica)*

> _Dónde enfocar la atención, dudas abiertas o puntos a discutir. Eliminar esta sección cuando no haya notas relevantes._
```
