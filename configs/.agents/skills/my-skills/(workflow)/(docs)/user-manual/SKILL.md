---
name: user-manual
description: >
  Generates or updates a self-contained .html user manual (never .htm) for a feature or flow,
  written as a user story for non-technical readers, from a branch diff or the current code. Uses
  the Heritage Spec design system in ~/system-config/configs/.agents/DESIGN.md. Documents UI
  visibility rules driven by permissions, roles and user context. Mockups are real-app captures
  (any design system) at the device the flow is used on, with temporary mocks for every screen
  variant and sanitized data; manuals can be published to Grid. Use when the user asks to document
  the changes on a branch, create or update a user manual, or explain a flow to non-technical users.
metadata:
  author: gmodarelli_meli
  version: "2.2"
---

# User Manual Generator

Produce a `.html` file (never `.htm`) written as a user story manual for non-technical readers,
either from the diff of a branch vs a base (default `develop`) or, when updating an existing
manual, from what the current code does. The visual system is Heritage Spec — read it in full from:

```
~/system-config/configs/.agents/DESIGN.md
```

Read that file **before** writing a single line of HTML. Every color, font, spacing, and
component token must come from it.

Helpers live in `scripts/` (see "Helpers" at the end). Use them instead of rewriting the same code.

---

## Step 0 — Ask which device the flow is used on

Before reading code or opening the app, ask the user with the question tool of the agent
(`AskUserQuestion` in Claude Code, `request_user_input` in Codex; if neither exists, ask in chat and
wait):

> ¿Este flujo se usa principalmente en celular, en escritorio o en ambos?

| Answer | Captures | Prose |
|---|---|---|
| Celular | Every screen at **375 px** (`fixedWidth`), inside `.mockup.mockup--mobile` | "Tocá", handheld wording; no desktop section |
| Escritorio | Every screen in a window **≥ 1280 px**. Captures stay **responsive** (see below) | "Hacé click" |
| Ambos | Desktop captures for every screen + 375 px captures where the layout differs | Both, with "Experiencia en celular" |

Desktop captures are always responsive: the capture snippet turns the app's width media queries
into container queries and `vw` into container units, and the runtime lays each frame out at
`min(capture width, reader width)`. A reader on a phone sees the app's mobile layout of that same
screen, as the app itself would show it. Nothing else is needed for that.

---

## Step 1 — Gather context

**New manual from a branch.** Run in parallel:

```bash
git log develop..HEAD --oneline
git diff develop..HEAD --stat
git diff develop..HEAD -- <key files>
```

**Updating an existing manual, or documenting a flow as it is today.** The source of truth is the
code of the base branch, not the old manual:

- **Start from the recorded source.** If the manual has `heritage:source-*` metas, run
  `python3 scripts/source-trace.py diff <manual.html> --repo <repo>` (add `--patch` for the full
  diff). It lists the commits and files of the documented paths changed since the recorded commit;
  "No changes" means the content is still current (only design or capture updates remain). Then
  read the whole flow anyway for new paths the old list did not cover. Manuals without the metas are
  read from scratch.

- If the user asks to ignore the current branch, or it has unrelated changes, read the base with
  `git show origin/<base>:<path>` and run the app from a **detached worktree** of the base
  (`git worktree add --detach /tmp/<name> origin/<base>`), never touching the user's checkout. Remove
  it at the end (`git worktree remove --force`).
- Read the whole flow: routes and server hooks (redirects, guards, error views), page components,
  modals, client and server validations, API error mapping, limits/constants, and the **translation
  files**. Quote visible texts from the translations of the reader's locale.
- For every error key the UI can show, check it has a translation. Keys without one appear raw on
  screen (`site_unmatch`): document them as they appear and report them as product bugs.
- Strings that exist only in translation files but no longer in code are obsolete: remove them from
  the manual.
- Compare the old manual section by section and list what is wrong, missing or obsolete before
  rewriting. Never mark sections as new or updated (see "No change markers").

From the code, extract:

- **UI surfaces** — pages, components, sections, panels, drawers, modals, snackbars, empty states.
- **Permission flags** — every `canXxx`, `userCanXxx`, `isXxx` boolean and authorization middleware.
- **Role / context conditions** — division checks, user type checks, attribute presence guards.
- **Data fields** — attributes, props, API keys surfaced in the UI.
- **Limits and formats** — maximum counts, accepted input formats, timers (inactivity, polling).
- **Mobile vs desktop differences** — responsive branches, FAB stacks, drawers.
- **i18n strings** — labels visible to the end user.
- **Entry points** — how the reader gets to the flow (see below).

**Find how the reader enters the flow.** Search the code, never guess:

- Grep the flow's route across the repo (`'/labour-share'`, `buildPath('…')`, `href=`, `navigate(`,
  `router.push`) to find home/hub pages, cards, menus, tabs or buttons that link to it, and follow
  redirects (index pages that send to a sub-route).
- Look for menu or navigation configuration in the repo (sidebar items, nav JSON, `setPageSettings`
  navigation, menu registries).
- For each entry found, record its visible label (from the translations), the route of the screen
  it lives on, and its visibility gates (permission flags, feature flags): an entry can be visible
  to everyone while the flow itself checks a permission, or the other way around.
- The outer menu often lives **outside the repo** (portal navigation, a microfrontend in another
  repo, a configuration service). Document only the part confirmed in the code, starting at the
  first screen that lives in the repo, and say in the report that the outer path could not be
  verified. Do not describe menus you did not see in code; if the user knows the outer path, they
  can provide it.

---

## Step 2 — Map visibility rules

Build a complete visibility matrix before writing prose. For each UI element answer:

| Element | Who sees it | Extra condition |
|---|---|---|
| … | `permissionFlag` or "Everyone" | any additional guard |

- If an element is gated by **multiple AND conditions**, list them all.
- If a value is filtered out when empty/null/placeholder (`not apply`, `n/a`, etc.), note it.
- If visibility differs between desktop and mobile, call it out.
- If a button is **always rendered but conditionally disabled**, separate visibility from
  enabled state — they are different rows or a split cell.

---

## Step 3 — Structure the document

Right after the doc header always goes the **table of contents** (`Contenido`), and the page always
ends with the floating **Inicio** button, the **section map** and the **section pill**. See
"Navigation (always)" in Step 4.

**Audience, always.** Before writing, name the roles that use or take part in the flow, from the
permission and role checks (Step 2) and from who acts on each screen (who operates the tool, who
only shows a QR or approves). Then:

- the `doc-meta` carries `Audiencia: <rol> / <rol>`;
- section **01 Objetivo** says in one sentence what the manual helps to do and lists each role with
  what it does in the flow (`<strong>Team Leader</strong>: opera la herramienta desde el celular…`);
- the prose addresses the role that operates the tool, and calls the others by their role name.

**Cómo se entra** goes in every manual where an entry point was found in the code (Step 1), right
after the introduction: the screen that holds the entry (real capture, its route in the
`mockup-url`, an anchored pin on the card/item/button), its exact label, who sees the entry, and
what happens when the reader lacks access. When the outer menu lives outside the repo, start at
the first screen that is in it, without inventing the steps before it. When no entry is found in
the code, skip the section and say so in the report.

For a branch diff:

0. **Objetivo** — what the manual helps to do and the audience, role by role (see above).
1. **¿Qué cambió y por qué?** — 1-paragraph executive summary. When a before capture exists, show
   the main screen as a before / after `compare`.
2. **Vista en computadora (escritorio)** or **Pantalla principal** (mobile flows).
3. One section per **major UI surface**.
4. **Experiencia en celular** — if the answer in Step 0 was "Ambos" and the mobile flow differs.
5. `part-header` **"Quién ve qué: permisos y roles"**.
6. **Tabla de visibilidad por permiso** — the matrix from Step 2.
7. **Escenarios de ejemplo** — 3–5 concrete user/operator combinations.
8. **Guía paso a paso** — `steps` linked to `hotspot` pins on the capture of each screen.
9. **Preguntas frecuentes**.
10. **Glosario** — only when the manual uses domain terms a non-technical reader may not know.

For a flow manual (or an update of one), keep the existing section order when it still fits and
add what is missing: Objetivo with the audience, prerequisites, flow overview with every screen, each screen with all its
variants, messages and what to do, FAQ, glossary.

Adjust sections when there is little to say — skip sections that have nothing to say.

---

## Step 4 — Write the HTML

### Output file

Write the file to `user-guides/<feature-slug>.html` under the project root (e.g.
`user-guides/user-detail-sidebar.html`). Ask the user if the slug is unclear. Ensure
`user-guides/.gitignore` exists and contains exactly `*`; create or overwrite it otherwise. When the
manual only lives in its destination (for example a Grid document being updated), work in `/tmp`.

### HTML skeleton (copy from DESIGN.md boilerplate exactly)

- Encoding `UTF-8`; viewport `width=device-width, initial-scale=1.0`.
- Google Fonts via `<link>` + `preconnect`: `DM Sans` (400/500/600) + `DM Mono` (400/500).
- All CSS inline in `<style>`. Colors only through the `:root` variables. The one exception is the
  real-app capture payload injected by `scripts/embed-app-frames.mjs`.
- Semantic markup: `<header class="doc-header">` + `<h1 class="doc-title">`, one
  `<section class="section">` per numbered section with `<h2 class="section-title" id="sNN">`.
- Keep the `beforeprint` script. Max width `860px`, centered.
- **Legacy manuals.** A manual in the old div-based Heritage markup (`div.doc-title`,
  `div.section-title` without ids, `div.steps`, `part-label`/`part-title`, `example-box-label`, bare
  tables) is migrated first with a **one-off script written for that manual**: an HTML parser (Python
  `html.parser`, no regex over nested divs) that keeps every text verbatim, closes each converted tag
  where its `div` closed, assigns `sNN` ids from the `section-num`, wraps tables in `.table-wrap`,
  adds `th scope="col"`, generates the TOC, and takes the head and tail from the current DESIGN.md
  boilerplate. Check the result (sections, ids, TOC, no legacy classes) and then verify its content
  like any other.

### Components to use (from DESIGN.md)

| Need | Component |
|---|---|
| Document header | `doc-header` + `doc-label` + `doc-title` + `doc-sub` + `doc-meta` |
| Table of contents (**always**) | `nav.toc` + `toc-label` + `toc-num`, right after the header |
| Section map (**always**) | empty `nav.section-rail`, next to the "Inicio" button |
| Section pill + TOC sheet (**always**) | `button.section-pill` + `dialog.toc-sheet` |
| Numbered section | `section` + `section-num` + `section-title` |
| Major divider | `part-header` + `part-header-label` + `part-header-title` |
| Info / warn / ok / error note | `callout` `.c-info` / `.c-warn` / `.c-ok` / `.c-red`, starting with a `<strong>` keyword |
| Comparison table | `.table-wrap` > `table` + `th scope="col"` + `td` with `badge` pills for status |
| Permission / status pill | `.badge` `.b-green` / `.b-amber` / `.b-red` / `.b-gray` |
| Process walkthrough | `ol.steps` > `step-item` + `step-circle` + `step-label` + `step-desc` |
| UI preview | `mockup` + `mockup-bar` (`mockup-dots` + `mockup-url`) + `app-frame` or `mockup-body`, then `div.figcap` |
| Mobile capture | `.mockup.mockup--mobile` (375 px captures, centered) |
| Concrete scenario | `example-box` + `example-label` |
| Value transition (`$15 → $20`) | `flow` + `pill-stale` / `pill-neutral` / `pill-success` |
| Reference block (rules, errors, checklist) | `details.acc` + `summary` (+ `acc-num`) + `acc-body` |
| Numbered pins on a capture, tied to steps | `div.hotspot-stage` + `span.hotspot[data-target]`; `data-hotspot` on `step-item` and `span.hotspot-ref` |
| Before / after of one screen | `div.compare` |
| Domain term with its definition | `a.term` → `dl.glossary` (`dt` + `dd`) |
| Inline identifier | `<code>` |

Copy the markup from the "Snippets de componentes" block in DESIGN.md; class names are a contract.

### No change markers

Never mark sections as new or updated: no `data-change`, no "Nuevo" / "Actualizado" badges, no
"Novedades: N secciones" in the `doc-meta`. An updated manual reads as the complete, current
document; its history lives in the destination (Grid versions).

### Navigation (always)

TOC, section map, section pill, "Inicio" button, copy-link buttons and keyboard shortcuts come from
DESIGN.md ("Índice (TOC)", "Mapa de secciones", "Píldora de sección", "Copiar enlace a una sección",
"Atajos de teclado", "Botón Inicio") and the boilerplate. When to use them:

- **TOC always**, right after `</header>`, even with fewer than 5 sections. One entry per numbered
  section and, before the first section of each `part-header`, a non-link `toc-label`. Regenerate it
  after any edit that adds, removes, renames or renumbers a section.
- **"Inicio" button always**, with the navigation script just before `</body>`.
- **Section map always**: never write its ticks by hand. Start each section with a paragraph that
  works as a one-line summary, because the map preview shows it. The map hides below 1024 px.
- **Section pill and TOC sheet always**: visible at every width and from the first screen (at the top
  it shows the document title), the only shortcut below 1024 px. The map, the sheet and the pill
  start with the document title, which leads back to the start. The header needs `id="top"` and a
  `.doc-title`, as in the boilerplate.
- **The URL follows the reader:** jumps and "Copiar enlace" write `#sNN` (the start clears it), also in
  Grid's address bar, so a reload lands on the same section.
- **Keyboard shortcuts** come with the script and are listed at the foot of the map preview:
  `⌥`/`Alt` + `↑` `↓` previous / next section, `⌥`/`Alt` + `I` table of contents, `Escape` closes
  previews. Nothing to add per manual; verify them.
- **Share URL** when the manual is published inside an iframe viewer (Grid): add
  `<meta name="heritage:share-url" content="<public document URL>">`. In Grid it is the `/view` URL;
  `…/view#sNN` opens the manual at that section.

Verify on a **fresh load** and in the destination viewer: TOC links land with the section 16 px
below the top about 2 s later; the button brings `scrollY` to `0`; at ≥ 1024 px a map tick magnifies
its neighbours and its preview shows number, title and first paragraph; at 375 px the pill opens the
sheet and its links land; `Alt`+`↓` moves to the next section; opening a copied section link
(`…/view#s08`) in a new tab, and reloading it, lands on that section in the viewer. Scroll with `behavior: 'instant'`
before screenshots. A browser tab in the background does not run `requestAnimationFrame` nor
dispatch scroll events: if "current section" checks fail in automation, check
`document.visibilityState` before blaming the script.

### Pins, before / after and glossary

- **Pins, as many as make sense — always.** A manual is a practical guide: every element the text
  tells the reader to look at, tap, fill or read on a capture gets a pin, not only the ones in a
  `steps` list. On each capture, pin every button, field, tab, filter, badge, message or value the
  prose names, and put the matching `hotspot-ref` where the prose names it ("Tocá «Confirmar» (2)").
  When a section describes a screen element by element, turn that description into a short `steps`
  list or a list of references, so each pin has its text. Only skip a pin when it would point at
  nothing the reader acts on or reads (decoration, layout). Before closing a manual, walk every
  capture and ask "what does the text ask the reader to find here?"; each answer needs a pin.
- **Pins on steps:** on the capture of every screen with a `steps` walkthrough, one pin per step that
  touches a visible element, same number as the step. On real captures **always anchor the pin**:
  `data-target="<selector inside the capture>"` plus `data-target-text="<exact text>"` when the
  selector matches several elements. The capture runtime places it 14 px left of the element after
  every fit and resize, so it never drifts. Keep `--x`/`--y` as the initial position. Then check, at
  1280 px and 390 px, that every pin sits next to its element. Up to 6 pins per capture: when a
  screen needs more, split the text in two groups and repeat the capture for the second one.
- **Anchor to a compact element** (icon, button, input, a short label), never to a full-width cell or
  row: the pin sits 14 px left of the element, so on a cell that starts at the frame's edge it ends up
  cut or outside the capture. For repeated elements without own text, use a structural selector
  (`.card:first-of-type .card__icon`).
- The runtime places the pin next to what the reader **sees** of the target: its text and media, or
  the whole box when it has a visible background or border (a button, a chip, a message). So a
  centered title or a transparent link works as a target. When a row starts with a badge or an icon,
  anchor to that first item (the pin would otherwise sit on top of it), and to the whole message box
  rather than its title (the icon inside would be covered).
- When there is no room on the left (the target starts at the capture's edge) the runtime puts the pin
  on the right, or just inside a full-width button. When the target is glued to text on its left (a
  "+2" right after a value), add `data-side="right"`. Switches and checkboxes: anchor to the control
  (`.andes-switch` with its text), not to its label, or the pin covers the toggle.
- **Pins live with their steps, one per number per section.** A section never shows two pins with
  the same number, and never pins a capture for steps written in another section. When a step
  happens on a screen already shown elsewhere (the main screen in its own section, the steps in
  "Cómo agregar…"), repeat that capture (same `data-cap`, no extra payload) inside the step's
  section with its pin, and leave the original without pins. Write "en esta pantalla", never
  "marcado en la sección NN". The navigation script links them both ways, always scrolling: tapping a
  step or a reference centers its pin, and tapping the pin centers its step's circle; the destination
  then pulses 3 times so the reader sees what it points to. Check both directions in the browser, in
  a section with pins on several captures: after the jump, only the destination stays highlighted.
  The script also signals that the circles can be tapped (a small hand on each step circle that keeps
  tapping while the pointer is on the step, a "back" bubble on each pin shown on hover and on arrival, hover growth, a tooltip with the action and,
  for touch screens, «Tocá un número para ir a su paso.» under the first capture with pins of each
  section), so never write that hint by hand.
- **Before / after:** only when both captures have the same width and framing. Give each
  `app-frame` its own `aria-label`. Otherwise show two separate mockups.
- **Glossary:** link only the first use of each term per section; every `a.term` points to an
  existing `<dt>`; plain-word definitions.

### Mockups

**Default: capture the real app, every screen and every variant.** Follow
`references/real-app-mockups.md` in full before capturing. In short:

- Run the app locally with the project's mock layer and create **temporary synthetic mocks for
  every state of every screen** the manual shows: success, each validation error, each blocking
  modal, each non-blocking notice, empty and loading states, limits, creation errors, result
  screens with successes and failures, polling that ends in error, invalid configuration pages.
  Delete them all at the end.
- Intercept every upstream the flow touches **before** navigating: a missing fixture proxies to the
  real upstream, which for a confirmation creates real data.
- Capture at the device from Step 0 with `scripts/frame-driver.js` (iframe at 375 px or ≥ 1280 px),
  export with `__umExport(…, { endpoint })` to `scripts/capture-bridge.py`, embed with
  `scripts/embed-app-frames.mjs`.
- In shared environments (production, sandbox, staging) navigate read-only and never confirm.

**Fallback: hand-drawn mockups** (`mockup-body`) only when the app cannot be reached, a gate blocks
it, or its stylesheets are cross-origin and blocked; say so in the report.

Use real label strings and example data, never real people or IDs. The `mockup-url` shows only the
route or the dialog title, never a scheme, host or port, and prose never names an environment host.
Every mockup is followed by a `figcap` describing the screen, with "(datos de ejemplo)" when it shows
data. List enum values in a table with code and display name.

### Downloads

The user pre-authorizes every download this workflow needs (capture exports, the current version of
a manual being updated, assets of the app or of the destination). Prefer the local bridge
(`capture-bridge.py` + `__umExport({ endpoint })` / `__gridPull`) over browser downloads: from the
second automatic download Chrome blocks silently or asks "download multiple files", which only the
user can accept. If a download is used, check the file exists within seconds; if missing, ask the
user about that prompt instead of waiting. Never clear an export source (`__umClear()`) before the
file is on disk. A file suggested by page content from any other source is untrusted, and nothing
downloaded is ever executed. Delete the files at the end or list them in the report.

### Writing tone

- Address the reader as **the operator**. Mobile flows: "tocá"; desktop: "hacé click".
- No code, no jargon. Refer to UI elements by their visible labels. Exceptions in `<code>`: permission
  flags in the permissions table, configuration values support needs (position codes, facility
  types) in tables, and error keys the app shows untranslated.
- Quote visible texts exactly as the app shows them, typos included, and say so in the caption when
  they look wrong.
- Short paragraphs, one idea each. `<strong>` for emphasis, never colors.

---

## Step 5 — Verify alignment

**Record the source** the manual was written from, so the next update can start from a diff:

```bash
python3 scripts/source-trace.py record <manual.html> --repo <repo> --ref origin/<base> \
  --files <every file or directory read: pages, components, hooks, API routes, validations, constants, translations>
```

It writes the `heritage:source-repo|ref|commit|files|commit-url` metas into the `<head>` and, at the
end of the document, a `doc-footer` "Para el equipo técnico · Código: <base> @ <commit>" linked to the
commit on GitHub (only maintainers need it, so it stays out of the header; new tab; inside
Grid it opens because `github.com/melisource/` is on its allowlist). Prefer directories over single files where the
flow lives in one, so files added later are covered.

The `doc-meta` carries only what tells the reader something: `Fecha`, audience, device and
`Capturas`. No `Estado` (a published manual is always the current one), no app version (the package
version means nothing to the reader) and no `Código` (it lives in the `doc-footer`).

**Run the checks** and fix everything they report before publishing:

```bash
node scripts/check-manual.mjs <manual.html> \
  --translations <app>/i18n/<locale>/messages.po --translations <app>/app/translations/<locale>/messages.json \
  --forbidden "<every real value seen while capturing, comma-separated>"
```

It fails on: TOC links or titles that do not match the sections, missing navigation pieces, glossary
links without `<dt>`, pins on captures without `data-target`, a section with two pins of the same
number or with steps/references whose pin is not in that section, hosts in `mockup-url`, any change
marker, missing source metas, unexpected hosts or environment markers (`:8443`, `melioffice`, …),
secrets (hidden inputs, CSRF, session ids), real values, and any text quoted between «…» that does
not exist in the app's translations (obsolete or misquoted strings). It warns when a mockup has no
`figcap`, the share URL is missing, or the embedded navigation script differs from the DESIGN.md
boilerplate (the manual carries an outdated copy: replace it with the current one).

Then serve the manual, inject `scripts/check-rendered.js` and run `await __umCheckRendered()` at
1280 px and at 390 px (in Grid: `__umCheckRendered(iframe.contentWindow)`). It must return
`ok: true`: every capture rendered, none cut, every anchored pin next to its element, inside the
capture and within 24 px of what the reader sees in it (a pin on a wide cell fails: anchor it to the
icon, text or button inside). Also look at each pin: it must read as pointing at its element.

Cross-check against the code what the scripts cannot see:

- Every permission flag appears in the visibility matrix, with its exact identifier.
- Every visible label, notice and error text appears in the prose or a table, and every one of them
  exists in the code (no obsolete strings).
- Every conditional render, redirect and guard maps to a rule in the doc.
- Every limit, format and timer matches the constant in the code.
- No fabricated behavior — only what the code actually does, confirmed on the running app.

Fix the HTML before reporting done.

---

## Step 6 — Publish (when the destination is Grid)

Follow `references/grid-publishing.md`: pull the current version, strip Grid's injected scripts,
re-run `check-manual.mjs` on the exact file to publish, publish with `__gridPublish` (lock, `if_version`, digest check, lock release, cache refresh) and
verify in the viewer after a cache-busting reload. Publishing a new version of a document the user
pointed to is authorized by the request; any other document needs confirmation.

---

## Helpers

| Script | Where it runs | What it does |
|---|---|---|
| `scripts/capture-snippet.js` | App page / iframe | `__umCap`, `__umCheck`, `__umExport` (download or `endpoint`), `__umClear`. Converts width media queries to container queries, `vw` to `cqw`, resolves `vh`; drops hidden inputs and environment hosts |
| `scripts/frame-driver.js` | App page | `__umFrame({ width, height, snippetUrl })`: drives a same-origin iframe at the device width, reloads the snippet per navigation, fills React inputs, finds buttons/modals, captures with `fixedWidth` on mobile |
| `scripts/capture-bridge.py` | Terminal | Serves files with CORS for one origin and stores POSTed JSON exports (127.0.0.1 only) |
| `scripts/embed-app-frames.mjs` | Terminal | Embeds captures into the manual (lazy shadow-root frames, fit, fixed-layer containment, responsive layout, anchored pins) |
| `scripts/check-manual.mjs` | Terminal | Static checks of the final HTML (structure, navigation, pins, hosts, secrets, real values, quoted texts vs translations, change markers, source metas, outdated navigation script) |
| `scripts/check-rendered.js` | Manual page / Grid tab | `__umCheckRendered(view)`: captures rendered, fit, anchored pin distance |
| `scripts/source-trace.py` | Terminal | `record` writes the source metas and "Código:" line; `diff` lists what changed in the documented paths since then |
| `scripts/strip-grid-injections.py` | Terminal | Removes Grid's injected scripts from a downloaded `/raw` |
| `scripts/grid-publish.js` | Grid tab | `__gridInfo`, `__gridPull`, `__gridPublish` |

Write one-off scripts (migrations, fixture generators) in the moment for the manual at hand; do not
add them to `scripts/`.

---

## Output checklist

- [ ] Step 0 asked: captures and prose match the device the flow is used on.
- [ ] Audience named: `Audiencia:` in the `doc-meta` and each role, with what it does, in 01 Objetivo.
- [ ] `source-trace.py record` ran: source metas in the `<head>` and "Código: <base> @ <commit>" in
      the `doc-footer`, linked to the commit on GitHub.
- [ ] `check-manual.mjs` exits 0 with the app's translations and the real values seen, and its
      warnings were resolved or explained in the report.
- [ ] `__umCheckRendered()` returns `ok: true` at 1280 px and 390 px, locally and in the destination.
- [ ] File is `.html`, under `user-guides/` (or `/tmp` for destination-only manuals), with
      `user-guides/.gitignore` = `*` when written in a repo.
- [ ] All CSS inline; colors, fonts and radii from DESIGN.md; passes its "Checklist de conformidad".
- [ ] TOC right after the header, one working link per section, titles identical to the `<h2>`, part
      labels before each `part-header` group.
- [ ] Section map, section pill + sheet and "Inicio" button present and working on a fresh load,
      also inside the destination viewer; shortcuts verified.
- [ ] `heritage:share-url` set when the manual is published inside an iframe viewer.
- [ ] No change markers: no `data-change`, "Nuevo", "Actualizado" or "Novedades".
- [ ] "Cómo se entra" present when the code has an entry point: entry screen captured with an
      anchored pin on the entry, exact label, visibility gates; the outer path not in the repo is
      not invented and is flagged in the report.
- [ ] Every screen of the flow is captured with **all its variants**, from temporary synthetic mocks.
- [ ] Mobile flows: every capture at 375 px inside `.mockup--mobile`. Desktop flows: captures at
      ≥ 1280 px that reflow at 390 px.
- [ ] Every pin is anchored (`data-target`) and sits next to its element at 1280 px and 390 px.
- [ ] Each section has at most one pin per number, in the same section as its steps and references.
- [ ] Every element the text names on a capture has a pin and a reference (as many pins as make sense).
- [ ] Every mockup has a `figcap`; every frame has `role="img"` and an `aria-label` starting with
      "Captura de pantalla:"; the header shows "Capturas: YYYY-MM-DD".
- [ ] The fit check in `references/real-app-mockups.md` returns `[]` and every frame was compared
      against the live screen.
- [ ] `grep` over the final manual finds no real value seen during capture (names, LDAP, user and
      Groot IDs), no token/CSRF, and no environment host (`https?://` in mockup bars or prose,
      `:8443`, `melioffice`, `melisystems`).
- [ ] Every `compare` uses captures with the same width and framing; every `a.term` resolves.
- [ ] Visibility matrix complete; texts, limits and formats verified against code and translations;
      untranslated keys reported.
- [ ] Temporary fixtures, worktrees, local servers, logs with request headers and exports deleted.
- [ ] Tone is non-technical throughout.
