# Mockups with the app's exact styles

Hand-drawn mockups drift from the product: fonts, spacing, component shapes, and colors end up
approximated. When the app being documented can be opened in a browser, capture the real screens
instead. The result is design-system agnostic: it works with Andes, Material, Tailwind, Bootstrap,
or custom CSS, because it copies whatever markup and stylesheets the page actually uses.

## What the technique does

1. Opens the running app and, for each screen or state the manual shows, clones the real DOM
   fragment plus its ancestors as empty shells, so descendant selectors keep matching.
2. Keeps only the CSS rules that match that fragment, including `@media`, `@supports`,
   `@keyframes` and `@font-face`, with relative `url()` values made absolute.
3. Replaces every piece of real data with example values before anything leaves the page.
4. Renders each capture inside its own shadow root in the manual, so the app's CSS and the
   Heritage Spec CSS never collide.

## Tools

- `scripts/capture-snippet.js` — paste it into the page with the browser JavaScript tool. It
  installs `__umCap`, `__umCheck`, `__umExport` and `__umClear`, and stores captures in
  `sessionStorage` so they survive navigation within the same origin. Re-paste it after each
  navigation.
- `scripts/embed-app-frames.mjs` — Node, no dependencies. Injects the captures into the manual
  and is safe to re-run.

## Workflow

### 1. Pick the environment

- Use the URL the user gives. Otherwise prefer a local dev server or a sandbox/test environment.
- Production is acceptable **only for read-only navigation**, and only when the user points to it.
- If authentication, SSO, or TLS gates appear, the user completes them; never type credentials.

### 2. Plan the captures

List every mockup the manual needs, with a stable `name` and the state to reach. For example:
`main`, `filters`, `filters-experience`, `bulk-step1`, `modal-default`, `session-queue`.

Reach each state **from the UI** the way a user would: open menus, modals, dropdowns, toggles,
and fill fields locally.

**Never confirm, submit, save, delete, or apply anything.** If a state only exists after a
mutation (for example a "success" result), describe it in prose instead of creating it. Close
modals with Cancel or ✕. If a read-only lookup is needed to populate a view (for example adding
IDs to a local queue), it is allowed, but the final confirmation is not.

### 3. Capture

```js
// after pasting capture-snippet.js
__umCap('main', document.querySelector('.page-root'), { pairs: [['Real Name', 'Ada Lovelace'], ['9282', '621601']] });
__umCap('filters', document.querySelector('[role="dialog"]'), { floating: true, pairs });
__umCap('card-list', document.querySelector('.list'), {
  pairs,
  transform: (clone) => clone.querySelectorAll('.list__row:nth-child(n+3)').forEach((row) => row.remove()),
});
```

- `element`: the smallest node that shows the whole state. For portals, modals, and popovers,
  capture the dialog or popover itself and pass `floating: true`.
- `transform(clone)`: trim long lists (keep 1–3 rows), drop pagination, or remove content the
  manual does not document. Never edit the live page.
- Check the returned `blockedSheets`. A cross-origin stylesheet that blocks `cssRules` is not
  copied; report it and fall back to a hand-drawn mockup if the capture loses its styles.
- Close transient layers (dropdowns, tooltips, focus rings) before capturing unless they are the
  point of the mockup. Blur the active element first.

### 4. Sanitize: mandatory, no exceptions

- Build `pairs` from the **real values visible in the fragment**: names, surnames, initials in
  avatars, user and entity IDs, usernames/LDAP, emails, phones, addresses, leaders, internal
  facility or tenant names, and free text typed by real users. Replace them with obvious example
  values used consistently across all captures (the same example person everywhere).
- `pairs` also cover `aria-label`, `title`, `alt`, `value`, `placeholder`, `href`, `id`, `for` and
  ancestor attributes, not just visible text.
- Replace longer strings first (a full name before a first name).
- Before exporting, run `__umCheck([...all real values seen])`. It must return `[]`. If not,
  recapture with more pairs, or post-process the stored HTML.
- After embedding, `grep` the final manual for the same values. Zero hits is the requirement.

### 5. Export and embed

- Download without asking (see "Downloads" in `SKILL.md`). Run `__umExport('app-captures.json')`,
  which saves it to the browser's downloads folder, then `__umClear()` to wipe `sessionStorage`.
- In the manual, put an empty host inside each mockup, after the `mockup-bar`:

  ```html
  <div class="mockup">
    <div class="mockup-bar">…</div>
    <div class="app-frame" data-cap="filters"></div>
  </div>
  <div class="figcap">Panel “Filtrar” con los seis filtros (datos de ejemplo).</div>
  ```

- Embed:

  ```bash
  node <skill-dir>/scripts/embed-app-frames.mjs ~/Downloads/app-captures.json user-guides/<slug>.html --page-background=<app page background>
  ```

  `--page-background` is the app's page color, so cards and modals sit on the same background as
  in the product. Read it from the app's `body` computed style.

### 6. Verify visually

Serve the manual locally (`python3 -m http.server --bind 127.0.0.1`), open it in the browser and
compare every frame against the live screen. Fix anything that differs: a floating layer still
off-flow, a shell adding height, or a missing font. Also confirm that the frames render in the
final destination (for example the Grid viewer). Delete the downloaded JSON when done, or tell
the user where it is.

## Fallback

Use hand-drawn Heritage Spec mockups (`mockup-body`) only when the app cannot be opened, a gate
blocks access, or stylesheets are cross-origin and blocked. In that case, say in the report that
the mockups are approximations.
