---
name: pr-description-template
description: "Provides the standard PR title and description template (icons, headings, automated/manual tests, checklists). Use whenever creating or filling a pull request body — explicitly or implicitly — including when running /feature-branch-pr, 'crear PR', 'abrir pull request', 'subir cambios y crear PR', 'gh pr create', or any flow that needs a PR title and description."
allowed-tools: Bash(gh:*) Bash(git:*)
---

# PR Description Template

Use this skill any time a pull request body has to be written or filled. It defines the canonical title + description so every PR looks consistent.

Triggers (explicit or implicit):
- the user runs `/feature-branch-pr` (the [feature-branch-pr](../feature-branch-pr/SKILL.md) skill must use this template for the PR body)
- the user asks to "crear PR", "abrir pull request", "subir cambios y crear PR", "branch + commit + push + PR"
- any flow that ends in `gh pr create` / editing a PR body and needs a title + description

## Rules

- **Always announce the skill**: before writing the PR body, state that you are using the `pr-description-template` skill.
- Fill every section from the actual diff — never leave the `*italic placeholders*`. Delete sections that genuinely do not apply (e.g. **Cambios en la API** when there are no API changes).
- Pick exactly one box in **Tipo de Cambio**.
- **Pruebas Automatizadas** and **Pruebas Manuales** are mandatory sections: list the tests and the manual steps a reviewer follows. Do **not** state which validations you personally ran.
- Body text is in Spanish; keep code, paths, endpoints, branch and identifier names in English.
- Pass the body to `gh pr create` via `--body-file` (write the filled template to a temp file) rather than a fragile inline `--body` string.

## Title

Single line, descriptive, English-friendly subject. Example: `Add user status sidebar element to detail views`.

## Body template

```markdown
# 🏷️ Título descriptivo del cambio

> **Tipo:** ✨ Feature · 🐛 Bugfix · 🧹 Refactor · ⚙️ Chore
> **Referencia:** *(link a ticket / issue, si aplica)*

---

## 📝 Descripción

### ❓ ¿Qué problema resuelve?
*Contexto del problema de negocio o técnico. ¿Por qué es necesario este cambio?*

### 💡 ¿Cuál fue la solución?
*Resumen técnico de la implementación. Componentes, servicios y archivos clave modificados.*

### ❓ ¿Por qué este enfoque y no otro?
*Decisiones de diseño relevantes y alternativas descartadas.*

---

## 🚀 Tipo de Cambio

- [ ] 🐛 **Bug Fix** — corrige un problema sin romper funcionalidad existente
- [ ] ✨ **New Feature** — agrega funcionalidad nueva
- [ ] 💥 **Breaking Change** — altera comportamiento existente
- [ ] 🧹 **Refactor** — reestructura sin cambiar comportamiento
- [ ] 📄 **Documentation** — solo documentación
- [ ] ⚙️ **Chore** — dependencias, config, CI/CD

---

## 🎨 Evidencia Visual

| 🔴 Antes | 🟢 Después |
| :---: | :---: |
| *(imagen / gif)* | *(imagen / gif)* |

---

## 🧪 Pruebas Automatizadas

> _Tests unitarios y de integración incluidos en este PR._

- [ ] 🧩 Unit tests para `<Componente>`
- [ ] 🔗 Integration tests para `<Servicio / flujo>`
- [ ] 🧷 Casos borde cubiertos (errores, estados vacíos, *loading*)

---

## 🖐️ Pruebas Manuales

> _Pasos para que el revisor reproduzca el comportamiento._

**🌐 Entorno de prueba:** `<URL / ambiente>`

**Pasos:**
1. Navegar a `<ruta>`.
2. Realizar `<acción>`.
3. Verificar que `<resultado esperado>`.

**Escenarios a cubrir:**
- ✅ *Happy path* — flujo principal funciona
- ⚠️ *Edge case* — entradas inválidas / límites
- 🔒 *Permisos* — roles y visibilidad según contexto de usuario

---

## 🔄 Cambios en la API *(si aplica)*

- ➕ **Agregados:** `POST /api/v1/...`
- ✏️ **Modificados:** `PUT /api/v1/.../{id}`
- ➖ **Eliminados / Deprecados:** `GET /api/v1/...`

---

## ✅ Checklist del Autor

- [ ] 🎨 El código sigue las guías de estilo del proyecto
- [ ] 🔍 Hice *self-review* del diff
- [ ] 💬 Comenté las zonas más complejas
- [ ] 📚 Actualicé la documentación relevante *(si aplica)*
- [ ] 🚫 No introduzco nuevos *warnings*
- [ ] 🧪 Agregué / actualicé tests para los cambios

---

## 👀 Notas para el Revisor

> _Dónde enfocar la atención, dudas abiertas o puntos a discutir._
```
