---
name: pr-description-template
description: "Provides the standard PR title and concise description template (change type, manual validation, optional API changes, reviewer notes). Use whenever creating or filling a pull request body — explicitly or implicitly — including when running /feature-branch-pr, 'crear PR', 'abrir pull request', 'subir cambios y crear PR', 'gh pr create', or any flow that needs a PR title and description."
allowed-tools: Bash(gh:*) Bash(git:*)
---

# PR Description Template

Use this skill any time a pull request body has to be written or filled. It defines the canonical title + description so every PR looks consistent.

Triggers (explicit or implicit):
- the user runs `/feature-branch-pr` (the [feature-branch-pr](../feature-branch-pr/SKILL.md) skill must use this template for the PR body)
- the user asks to "crear PR", "abrir pull request", "subir cambios y crear PR", "branch + commit + push + PR"
- any flow that ends in `gh pr create` / editing a PR body and needs a title + description

## Rules

- Fill every section from the actual diff — never leave the `*italic placeholders*`. Delete sections that genuinely do not apply (e.g. **Decisiones técnicas relevantes**, **Cambios en la API**, or **Notas para el Revisor**).
- Start the body directly with **Descripción**. The PR title already carries the change summary, so do not repeat it as a body heading.
- Do not add a compact **Tipo** metadata block above **Descripción**. In **Tipo de Cambio**, mark exactly one primary category with `[x]` and leave every other category unmarked with `[ ]`.
- Include ticket or issue links naturally in **Descripción** or **Notas para el Revisor** when relevant; do not create a fixed metadata block for them.
- In **Cambios en la API**, keep only operation groups that apply (**Agregados**, **Modificados**, **Eliminados / Deprecados**) and delete unused lines.
- **Pruebas Manuales** is mandatory: list reproducible steps a reviewer can follow. Mention automated coverage inside **Descripción** only when it adds relevant context. Do **not** state which validations you personally ran.
- Body text is in Spanish; keep code, paths, endpoints, branch and identifier names in English.
- Always apply the PR body directly with `gh`, unless the user explicitly asks for a draft only.
- For an existing PR, locate it with `gh pr view --json number,title,body,url,headRefName,baseRefName` (or use the PR number/URL provided by the user), write the filled template to a temp file, and run `gh pr edit <number-or-url> --title "<title>" --body-file <temp-file>`.
- For a new PR, pass the body to `gh pr create` via `--body-file` (write the filled template to a temp file) rather than a fragile inline `--body` string.
- After `gh pr edit` or `gh pr create`, verify the result with `gh pr view --json title,body,url`.

## Title

Single line, descriptive, English-friendly subject. Example: `Add user status sidebar element to detail views`. Use it only as the PR title; do not repeat it inside the body.

## Body template

```markdown
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
