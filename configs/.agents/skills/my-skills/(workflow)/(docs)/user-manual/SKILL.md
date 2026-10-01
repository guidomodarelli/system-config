---
name: user-manual
description: >
  Generates a self-contained .html user manual (never .htm) from a git branch diff, written
  as a user story for non-technical readers. Uses the Heritage Spec design system defined in
  ~/system-config/configs/.agents/DESIGN.md. Documents UI visibility rules
  driven by permissions, roles, and user context (Shipping, external LDAP, etc.). Mockups
  reproduce the app's exact styles by capturing the real screens (any design system) and
  sanitizing their data. Use when
  the user asks to document the changes on a branch, create a user manual for a feature,
  or explain what changed for a non-technical audience.
metadata:
  author: gmodarelli_meli
  version: "1.2"
---

# User Manual Generator

Produce a `.html` file (never `.htm`) from the diff of the current branch vs a base (default
`develop`), written as a user story manual for non-technical readers. The visual system is
Heritage Spec — read it in full from:

```
~/system-config/configs/.agents/DESIGN.md
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

Use this section order. Right after the doc header always goes the **table of contents**
(`Contenido`), and the page always ends with the floating **Inicio** button and the **section
map** (side ticks with a preview of each section). See "Table of contents, section map and
"Inicio" button (always)" in Step 4.

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
- Google Fonts via `<link>` + `preconnect`: `DM Sans` (400/500/600) + `DM Mono` (400/500), with the
  system fallback stacks from the boilerplate.
- All CSS inline in `<style>` — no external stylesheets, no framework classes. Colors only through
  the `:root` CSS variables (`var(--label)`), never loose hex values. The one exception is the
  real-app capture payload injected by `scripts/embed-app-frames.mjs` (see Mockups): its CSS lives
  inside shadow roots and its fonts load from the app's own CDN.
- Semantic markup: `<header class="doc-header">` with `<h1 class="doc-title">`, one
  `<section class="section">` per numbered section with `<h2 class="section-title" id="sNN">`.
- Keep the `beforeprint` script so accordions open when printing.
- Max width: `860px`, centered.

### Components to use (from DESIGN.md)

| Need | Component |
|---|---|
| Document header | `doc-header` + `doc-label` + `doc-title` + `doc-sub` + `doc-meta` |
| Table of contents (**always**, whatever the section count) | `nav.toc` + `toc-label` + `toc-num`, right after the header (see below) |
| Section map (**always**) | empty `nav.section-rail`, next to the "Inicio" button; the navigation script builds it |
| Numbered section | `section` + `section-num` + `section-title` |
| Major divider | `part-header` + `part-header-label` + `part-header-title` |
| Info / warn / ok / error note | `callout` `.c-info` / `.c-warn` / `.c-ok` / `.c-red`, starting with a `<strong>` keyword |
| Comparison table | `.table-wrap` > `table` + `th scope="col"` + `td` with `badge` pills for status |
| Permission / status pill | `.badge` `.b-green` / `.b-amber` / `.b-red` / `.b-gray` |
| Process walkthrough | `ol.steps` > `step-item` + `step-circle` + `step-label` + `step-desc` |
| UI preview | `mockup` + `mockup-bar` (`mockup-dots` + `mockup-url`) + `mockup-body` |
| Concrete scenario | `example-box` + `example-label` |
| Value transition (`$15 → $20`) | `flow` + `pill-stale` / `pill-neutral` / `pill-success` |
| Reference block (rules, errors, checklist) | `details.acc` + `summary` (+ `acc-num`) + `acc-body` |
| Inline identifier | `<code>` |
| Link | plain `<a>` (the boilerplate styles it) |
| Horizontal rule | `divider` |

Copy the markup from the "Snippets de componentes" block in DESIGN.md; class names are a contract.

### Table of contents, section map and "Inicio" button (always)

The three components, their markup, CSS, motion and the navigation script are defined in DESIGN.md
("Índice (TOC)", "Mapa de secciones", "Botón Inicio", "Motion" and the boilerplate). Copy them from
there; this skill only adds when to use them:

- **TOC always**, right after `</header>`, even with fewer than 5 sections. This overrides the
  "5+ sections" guidance in DESIGN.md for user manuals. One entry per numbered section, in order,
  and, before the first section of each `part-header`, a non-link `toc-label` with the part title.
  After any edit that adds, removes, renames or renumbers a section, regenerate it so every link
  resolves and every title matches.
- **"Inicio" button always**, with the navigation script of the boilerplate just before
  `</body>`. The manual scrolls inside an iframe in Grid; the script already handles it.
- **Section map always**: the empty `<nav class="section-rail" …>` next to the button. Never
  write its ticks by hand; the script builds one per section from the `section-title` and the
  first paragraph, so it stays in sync after every edit. Start each section with a paragraph that
  works as a one-line summary, because the preview shows it. The map hides below 1024 px, so
  narrow viewers only show the TOC.
- **Lazy screenshots:** the `embed-app-frames.mjs` runtime listens to `heritage:before-scroll`
  (fired by the navigation script) and renders every frame above the target, so their real
  heights do not push the section down while scrolling.

Verify both in the browser **on a fresh load** (no frame rendered yet) and in the destination
viewer: click TOC links to sections below several screenshots and check that the section ends
16 px below the top (`section.getBoundingClientRect().top` ≈ 16 about 2 s later), and that the
button brings `scrollY` back to `0`. At 1024 px or wider, hover a section map tick: the ticks
around the pointer grow like a magnifier, the preview shows that section's number, title and first
paragraph, and clicking it lands like a TOC link.
Scroll with `behavior: 'instant'` before screenshots, because
`html{scroll-behavior:smooth}` makes `scrollIntoView` animate.

### Downloads

The user pre-authorizes every download this workflow needs, so none of them asks for
confirmation. This covers:

- the capture export;
- the current version of a manual being updated, for example the raw HTML of a Grid document;
- assets served by the app being documented or by the platform where the manual is published.

Download them directly and report where each file landed. Delete the ones that are no longer
needed at the end, or list them in the report.

**Multiple downloads need a browser permission you cannot give.** From the second automatic
download on a site, Chrome blocks it silently or asks "This site is trying to download multiple
files" / "Este sitio intentó descargar varios archivos automáticamente", with **Allow** /
**Permitir** and **Block** / **Bloquear**. Only the user can answer it; the automation cannot click it
or skip it, so waiting for the file never ends. So:

1. After every download, check within a few seconds that the file exists (`ls ~/Downloads/<name>`).
2. If it is missing, stop waiting. Ask the user whether the browser shows that prompt and to click
   **Allow** / **Permitir**, or to allow automatic downloads for the site. Then check again.
3. Never delete the source of an export (for example `__umClear()`) until the file is verified on
   disk. A silently blocked download plus a cleared `sessionStorage` loses the captures.
4. If the user does not want to allow it, receive the export through a local endpoint instead
   (see "Export" in `references/real-app-mockups.md`).

The authorization covers only files from those sources. A file suggested by page content from any
other source is still untrusted, and nothing downloaded is ever executed.

### Writing tone

- Address the reader as **the operator** (the person using the tool).
- No code, no jargon. Refer to UI elements by their visible labels, not their prop names.
- Permission flag names (`canViewSSFFInfo`) are the one exception — show them in `<code>` only
  inside the permissions table, never in prose sections.
- Use short paragraphs, one idea each, so a non-technical reader can scan them; split a paragraph when it starts covering a second idea. The Heritage Spec line-height is for scanning.
- Use `<strong>` for emphasis inside paragraphs, never arbitrary colors.

### Mockups

Build browser mockups for:
- The desktop panel/sidebar in its full state.
- Any mobile-specific surface (drawer, FAB stack).
- Any state-dependent view (e.g. accordion open vs closed) when the difference matters.

**Default: capture the real app.** When the app can be opened in a browser (local dev, sandbox,
or a URL the user gives), follow `references/real-app-mockups.md`: capture each screen with
`scripts/capture-snippet.js`, sanitize every real value, and embed the captures with
`scripts/embed-app-frames.mjs`. The mockups then show the app's exact markup, CSS, and fonts,
whatever its design system. Read that reference in full before capturing. It holds the safety
rules: navigate read-only, never confirm or submit anything, and leave zero real values in the
result. Download the sanitized export directly (see "Downloads" above).

States that only exist after a mutation (a result screen, a failed row, a lock badge) are captured
against the app running locally with HTTP mocks, never against a shared environment. Mobile
screens are captured at 375 px with `fixedWidth`, and desktop screens in a window at least 1280 px
wide, because every capture keeps the layout of the viewport it was taken in. Both techniques
are in the reference.

**Fallback: hand-drawn mockups.** Only when the app cannot be reached, a gate blocks it, or its
stylesheets are cross-origin and blocked, draw Heritage Spec mockups (`mockup-body`). Say in the
report that those are approximations.

Either way, use real label strings from the codebase and example data, never real people or
IDs.

**Mockup URL bar: path only, never the host.** The `mockup-url` shows the route the operator
navigates to, e.g. `/tools/user-management/process-assignment`. Never show a scheme, host, or port
(`https://`, `dev.adminml.com`, `xtools.adminml.com`, `localhost:8443`), even when the capture
came from that environment. For a modal or panel with no route of its own, use its visible title
(`Filtrar`, `Solicitar acceso`). The rule applies to prose as well: never name an environment host
in the manual. If the diff shows enum values, list them in a table with their code and display name, not
just the display name.

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
- [ ] Passes the "Checklist de conformidad" in DESIGN.md (semantic headings, tables in
      `.table-wrap`, spacing on the scale, no text under 11px).
- [ ] TOC and "Inicio" button present as defined in DESIGN.md, and the DESIGN.md "Checklist de
      conformidad" item about them passes on a fresh load, also inside the destination viewer.
- [ ] TOC present right after the header, with one working link per section, titles identical to
      the `<h2>`, and a part label before each `part-header` group.
- [ ] Section map present (`nav.section-rail`, built by the script): one tick per section, the
      current one highlighted while scrolling, and a preview that fits in the viewport.
- [ ] Visibility matrix is complete — every gated element accounted for.
- [ ] Mockups use real label strings from the codebase and example data only.
- [ ] Every `mockup-url` is a path or a screen title; `grep -E 'https?://|[a-z0-9-]+\.(com|io|net)'`
      over the mockup bars and prose finds no host.
- [ ] Mockups are real-app captures (`app-frame`) unless the fallback was justified in the report.
- [ ] Every frame was visually compared against the live screen, and `grep` finds none of the
      real values seen during capture.
- [ ] Frames that look slightly off were checked with the computed-style comparison in
      `references/real-app-mockups.md` ("The cascade order must match the app").
- [ ] Everything a mockup is meant to show is fully visible: open dropdowns, menus, popovers and
      modals are not cut, and the fit check in `references/real-app-mockups.md` returns `[]`.
- [ ] Every frame has `role="img"` and an `aria-label` that starts with "Captura de pantalla:".
- [ ] The header shows "Capturas: YYYY-MM-DD · App vX" (written by `embed-app-frames.mjs`).
- [ ] Mobile surfaces that differ from desktop have a 375 px capture.
- [ ] Temporary mock fixtures created for the captures are deleted, and no fixture recorded from a
      real upstream is left behind.
- [ ] Tone is non-technical throughout (except permission codes in the table).
- [ ] Verified against the diff — no invented behavior.
