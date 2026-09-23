---
name: pr-description-template
description: "Provides the standard PR title and concise description template (change type, manual validation, optional API changes, reviewer notes) plus a traceability-only mode that preserves existing PR content. Use whenever creating, filling, or intentionally restructuring a pull request body — explicitly or implicitly — including /feature-branch-pr, 'crear PR', 'abrir pull request', 'subir cambios y crear PR', or gh pr create."
allowed-tools: Bash(gh:*) Bash(git:*) Bash(bash:*)
---

# PR Description Template

Use this skill any time a pull request body has to be written or filled. It defines the canonical title + description so every PR looks consistent.

## Strict scope

Run only the actions needed to compose, apply, or verify the title and body of the requested PR.

- Read the diff only as evidence to write the description; do not treat it as an implicit review request.
- Do not start a code review, security audit, dependency audit, performance review, or any other analysis unless explicitly asked.
- Do not run tests, builds, linters, scanners, or repository validations unless explicitly asked.
- Do not invoke skills, agents, or workflows unrelated to PR composition unless explicitly asked or directly delegated by the calling flow. If a higher-priority rule forces an invocation, limit it to deciding applicability; do not expand scope.
- Do not modify code, dependencies, or configuration.
- Do not create or update Jira, labels, review comments, approvals, merge, or PR state.
- Allowed writes: create the PR when the calling flow asks for it, or edit only the title/body of the explicitly requested PR.
- In `traceability-only` mode, the only allowed write is the delegated body-only backlink; do not re-template the PR.
- Skip any action that is not a direct requirement of the requested description.

## Direct application

- When the user invokes `/pr-description-template` or names this skill, treat the request as an order to apply the change directly to the PR; do not answer with a draft to copy by hand.
- Locate the PR with `gh pr view --json number,title,body,url,headRefName,baseRefName`. For an existing PR, apply the change with `gh pr edit <number-or-url> --body-file <temp-file>` and add `--title` only for a full composition. For a new PR, use `gh pr create --body-file <temp-file>` when the calling flow asked to create it.
- Verify every write with `gh pr view --json title,body,url` before reporting the result.
- Do not print the title, body, template, or full generated content in chat. Report only the operation, affected PR, URL, and verification. If the operation fails or no PR applies, report the concrete blocker without pasting an alternative body.
- Return title/body content only when the user explicitly asks for a draft, preview, or content without direct application.

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
- Do not add or recompute the initial file-count metadata line.
- Do not modify **Tipo de Cambio**, **Pruebas Manuales**, **Cambios en la API**, **Notas para el Revisor**, or unrelated ticket links.
- A canonical Jira backlink may be inserted as the first content under `## 📝 Descripción`; this is not the removed top-level **Referencia** metadata block.
- Delegate position, legacy cleanup, deduplication, concurrency, and byte-preservation rules to [pr-traceability.md](../kraken-jira-ticket/references/pr-traceability.md).
- Read `title`, `body`, and `url`; edit only through `gh pr edit <url> --body-file <temp-file>` without `--title`.
- Re-read the PR and verify title identity plus protected body content after the patch.

### Initial file-count metadata

Apply only during `full composition`, before writing the body. Count files from the actual PR comparison range (`base...head`), never from the whole repository, a line-count statistic, or unrelated working-tree changes.

Run [scripts/count-reviewable-files.sh](scripts/count-reviewable-files.sh) from this skill directory. It counts reviewable product code only (JavaScript and TypeScript files a reviewer must read to judge behavior) and excludes dot directories and dotfiles, root `config/` and `settings/`, tests, mocks, fixtures, snapshots, e2e, stories, `.d.ts` declarations, and tooling configuration.

- New PR: `bash <skill-dir>/scripts/count-reviewable-files.sh "<base-ref>...<head-ref>"`.
- Existing PR: fetch the PR head into a named ref, which also works for PRs from forks and counts only pushed commits, then pass that range:

  ```bash
  git fetch origin "<baseRefName>" "+refs/pull/<number>/head:refs/remotes/origin/pr/<number>"
  bash <skill-dir>/scripts/count-reviewable-files.sh "origin/<baseRefName>...origin/pr/<number>"
  git update-ref -d "refs/remotes/origin/pr/<number>"
  ```

- A caller that already resolved the range may pipe its exact `git diff --name-only` output into the script instead of passing a range.
- Do not diff against `FETCH_HEAD` (with two refspecs it points to the base, so the range is empty) and do not use `gh pr view --json files` (it returns at most 100 files).
- If the range cannot be determined or the fetch fails, stop and report the concrete blocker instead of inventing or estimating a number.

Place exactly one line, `<div align="right"><sup>📄 Archivos de código modificados: N</sup></div>`, as the first body content, followed by one blank line and `## 📝 Descripción`. Replace `N` with the script output; never leave placeholder text. Do not add this line in `traceability-only`.

## Full-composition rules

- Fill every section from the actual diff; never leave `*italic placeholders*`. Delete optional sections (**Cambios en la API**, **Notas para el Revisor**) when they do not apply.
- The template contains only content that is published. Do not add instructions, hints, or blockquotes for the author to the body.
- Start the body with the file-count line, then one blank line and **Descripción**. The PR title already carries the change summary, so do not repeat it as a body heading.
- Do not add a compact **Tipo** metadata block above **Descripción**. In **Tipo de Cambio**, mark exactly one primary category with `[x]` and leave every other category unmarked with `[ ]`.
- Include ordinary ticket or issue links naturally in **Descripción** or **Notas para el Revisor**; do not create a fixed metadata block.
- When fully composing an existing PR, preserve every canonical `🎫 Jira: [...]` backlink already present. Extract backlinks before replacing the body and reinsert each once as first content under `## 📝 Descripción`; never drop established traceability.
- New or legacy backlink normalization follows traceability-only mode; full composition preserves known canonical backlinks but does not invent Jira associations.
- In **Cambios en la API**, keep only the operation groups that apply (**Agregados**, **Modificados**, **Eliminados / Deprecados**) and delete unused lines.
- **Pruebas Manuales** is mandatory. List reproducible steps a reviewer can follow. When the change has no behavior a reviewer can exercise (only documentation, agent instructions, or tooling), replace the environment and steps with one line: `No aplica: <motivo>`. Do not state which validations you personally ran; mention automated coverage inside **Descripción** only when it adds relevant context.
- **Notas para el Revisor** holds relevant technical decisions (trade-offs, discarded alternatives, constraints) and where to focus the review. Delete it when there is nothing relevant.
- Body text is in Spanish; keep code, paths, endpoints, branch and identifier names in English.
- Apply the complete PR body directly with `gh`, unless the user explicitly asks for a draft only.
- For an existing PR under full composition, locate it with `gh pr view --json number,title,body,url,headRefName,baseRefName`, write the filled template to a temp file, and run `gh pr edit <number-or-url> --title "<title>" --body-file <temp-file>`.
- For a new PR, pass the body to `gh pr create` via `--body-file` rather than a fragile inline `--body` string.
- After `gh pr edit` or `gh pr create`, verify the result with `gh pr view --json title,body,url`.

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

## 🚀 Tipo de Cambio

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

## 🖐️ Pruebas Manuales

**🌐 Entorno:** `<URL / ambiente, si aplica>`

1. `<Acción a realizar>` → `<Resultado esperado>`
2. `<Acción a realizar>` → `<Resultado esperado>`

## 🔄 Cambios en la API *(si aplica)*

- ➕ **Agregados:** `POST /api/v1/...`
- ✏️ **Modificados:** `PUT /api/v1/.../{id}`
- ➖ **Eliminados / Deprecados:** `GET /api/v1/...`

## 👀 Notas para el Revisor *(si aplica)*

*Decisiones técnicas relevantes (trade-offs, alternativas descartadas, restricciones) y dónde enfocar la revisión.*
```
