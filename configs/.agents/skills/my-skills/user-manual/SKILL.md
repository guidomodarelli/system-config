---
name: user-manual
description: >
  Generates a self-contained .html user manual (never .htm) from a git branch diff, written
  as a user story for non-technical readers. Uses the Heritage Spec design system defined in
  /Users/gmodarelli/system-config/configs/.agents/DESIGN.md. Documents UI visibility rules
  driven by permissions, roles, and user context (Shipping, external LDAP, etc.). Use when
  the user asks to document the changes on a branch, create a user manual for a feature,
  or explain what changed for a non-technical audience.
compatibility: Requires git. Designed for Claude Code in MELI/Nordic repos under ~/ghq/work/.
metadata:
  author: gmodarelli_meli
  version: "1.0"
---

# User Manual Generator

Produce a `.html` file (never `.htm`) from the diff of the current branch vs a base (default
`develop`), written as a user story manual for non-technical readers. The visual system is
Heritage Spec — read it in full from:

```
/Users/gmodarelli/system-config/configs/.agents/DESIGN.md
```

Read that file **before** writing a single line of HTML. Every color, font, spacing, and
component token must come from it.

---

## Step 1 — Gather context

Run these in parallel:

```bash
# 1. All commits on this branch
git log develop..HEAD --oneline

# 2. Changed files summary
git diff develop..HEAD --stat

# 3. Full diff of the most relevant files (view, controller, styles, i18n)
git diff develop..HEAD -- <key files>
```

From the diff, extract:

- **New UI surfaces** — components, sections, panels, drawers, accordions added or replaced.
- **Permission flags** — every `canXxx`, `userCanXxx`, `isXxx` boolean that gates a render.
- **Role / context conditions** — division checks (`isShippingDivision`), user type checks
  (`isExternalLdapUser`), attribute presence guards (`.filter(Boolean)`).
- **New data fields** — attributes, props, API keys surfaced in the UI.
- **Mobile vs desktop differences** — responsive branches, FAB stacks, drawers.
- **i18n strings added** — new labels visible to the end user.

---

## Step 2 — Map visibility rules

Build a complete visibility matrix before writing prose. For each UI element answer:

| Element | Who sees it | Extra condition |
|---|---|---|
| … | `permissionFlag` or "Everyone" | any additional guard |

Rules to follow when building the matrix:

- If an element is gated by **multiple AND conditions**, list them all.
- If a value is filtered out when empty/null/placeholder (`not apply`, `n/a`, etc.), note it.
- If visibility differs between desktop and mobile, call it out.
- If a button is **always rendered but conditionally disabled**, separate visibility from
  enabled state — they are different rows or a split cell.

---

## Step 3 — Structure the document

Use this section order:

1. **¿Qué cambió y por qué?** — 1-paragraph executive summary for a non-technical reader.
2. **Vista en computadora (escritorio)** — browser mockup + prose walkthrough.
3. One section per **major new UI surface** (accordion, drawer, badge group, etc.).
4. **Experiencia en celular** — if the mobile flow differs.
5. `part-header` separator **"Quién ve qué: permisos y roles"**
6. **Tabla de visibilidad por permiso** — the full matrix from Step 2.
7. **Escenarios de ejemplo** — 3–5 concrete user/operator combinations.
8. **Guía paso a paso** — numbered steps with the `steps` component.
9. **Preguntas frecuentes** — answer the questions a non-technical user would actually ask.

Adjust sections when the diff is small — skip sections that have nothing to say.

---

## Step 4 — Write the HTML

### Output file

Always write the file to `user-guides/<feature-slug>.html` under the project root, where
`feature-slug` is derived from the branch name or the main feature described
(e.g. `user-guides/user-detail-sidebar.html`). Ask the user if the slug is unclear.

Before writing the HTML, ensure the `user-guides/` folder is ignored by git:

```bash
# Check whether the gitignore guard already exists
cat <project-root>/user-guides/.gitignore 2>/dev/null
```

- If the file does **not** exist, or its content is not exactly `*` (a single asterisk, no
  trailing spaces or extra lines), create or overwrite it:

  ```
  user-guides/.gitignore
  ───────────────────────
  *
  ```

- If it already contains exactly `*`, leave it untouched.

Create the `user-guides/` directory if it does not exist before writing either file.

### HTML skeleton (copy from DESIGN.md boilerplate exactly)

- Encoding: `UTF-8`.
- Viewport: `width=device-width, initial-scale=1.0`.
- Google Fonts import: `DM Sans` (400/500/600) + `DM Mono` (400/500).
- All CSS inline in `<style>` — no external stylesheets, no framework classes.
- Max width: `860px`, centered.

### Components to use (from DESIGN.md)

| Need | Component |
|---|---|
| Document header | `doc-header` + `doc-label` + `doc-title` + `doc-sub` + `doc-meta` |
| Numbered section | `section` + `section-num` + `section-title` |
| Major divider | `part-header` + `part-header-label` + `part-header-title` |
| Info / warn / ok / error note | `callout` `.c-info` / `.c-warn` / `.c-ok` / `.c-red` |
| Comparison table | `table` + `th` + `td` with `badge` pills for status |
| Permission / status pill | `.badge` `.b-green` / `.b-amber` / `.b-red` / `.b-gray` |
| Process walkthrough | `steps` + `step-circle` + `step-label` + `step-desc` |
| UI preview | `mockup` + `mockup-bar` (3 dots + URL) + `mockup-body` |
| Inline identifier | `<code>` |
| Horizontal rule | `divider` |

### Writing tone

- Address the reader as **the operator** (the person using the tool).
- No code, no jargon. Refer to UI elements by their visible labels, not their prop names.
- Permission flag names (`canViewSSFFInfo`) are the one exception — show them in `<code>` only
  inside the permissions table, never in prose sections.
- Use short paragraphs (3–5 lines max). The Heritage Spec line-height is for scanning.
- Use `<strong>` for emphasis inside paragraphs, never arbitrary colors.

### Mockups

Build browser mockups for:
- The desktop panel/sidebar in its full state.
- Any mobile-specific surface (drawer, FAB stack).
- Any state-dependent view (e.g. accordion open vs closed) when the difference matters.

Use real values from the codebase when possible (real attribute keys, real display names,
real label strings). If the diff shows enum values, list them in a table with their code and
display name, not just the display name.

---

## Step 5 — Verify alignment

After writing, cross-check against the diff:

- Every permission flag in the diff appears in the visibility matrix.
- Every new i18n label appears in the prose or a table.
- Every conditional render in the view (ternary, `&&`, `.filter()`) maps to a rule in the doc.
- No fabricated behavior — only what the code actually does.
- The `<code>` for permission flags in the table matches the exact identifier in the source.

If a discrepancy is found, fix the HTML before reporting done.

---

## Output checklist

- [ ] File is `.html` (not `.htm`).
- [ ] Placed under `user-guides/` in the project root.
- [ ] `user-guides/.gitignore` exists and contains exactly `*`.
- [ ] All CSS is inline — no external deps beyond Google Fonts.
- [ ] Heritage Spec colors, fonts, and radii match DESIGN.md exactly (no hard-coded values
      that differ from the spec).
- [ ] Visibility matrix is complete — every gated element accounted for.
- [ ] Mockups use real values from the codebase.
- [ ] Tone is non-technical throughout (except permission codes in the table).
- [ ] Verified against the diff — no invented behavior.
