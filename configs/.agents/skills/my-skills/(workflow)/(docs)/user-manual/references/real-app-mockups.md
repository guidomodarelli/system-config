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
- If the page's Content Security Policy blocks evaluated code, serve the snippet from a local
  server that binds to `127.0.0.1` and sends CORS headers, then inject it as a `<script>` carrying
  the page's own nonce:

  ```js
  const source = await fetch('http://localhost:8767/capture-snippet.js').then((response) => response.text());
  const script = document.createElement('script');
  script.nonce = [...document.scripts].map((existing) => existing.nonce).find(Boolean);
  script.textContent = source;
  document.head.appendChild(script);
  ```

- Keep each browser JavaScript call under the tool timeout (about 45 s). Split long flows (open,
  fill, confirm, wait for polling, capture) into several calls; a timed-out call can stop halfway
  and leave the page in an intermediate state.
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

**In any shared environment (production, sandbox, staging), never confirm, submit, save, delete,
or apply anything.** Close modals with Cancel or ✕. A read-only lookup that populates a view (for
example adding IDs to a local queue) is allowed; the final confirmation is not.

**States that only exist after a mutation** (a result screen with successes and failures, a
"pending segments" result, a lock badge, a row marked "Failed") are captured against the app
running **locally with HTTP mocks**. There, confirming is safe because the request never leaves the
machine:

1. Start the app in its local development mode with the project's mock layer (for Nordic apps,
   the `nordic-local-mocks` skill). Use the fixtures the project already has for those scenarios
   and pick inputs that hit them (for example the operator IDs and access that the scenario
   fixture keys on).
2. Before confirming, check which requests the flow makes and that each one has a fixture. With
   recording mock layers such as `frontend-mocks`, **a missing fixture proxies to the real upstream
   and writes its response to disk**, real data and headers included.
3. After each flow, run `git status --short mocks/` (or the mock directory). Delete every fixture
   that was recorded from a real upstream right away. Treat anything it shows as seen real data
   and add it to the sanitization pairs.
4. When a scenario needs a fixture that does not exist, create a temporary one with synthetic data
   only: no `headers` property and no keys that start with `x-`. List every temporary file (for
   example in `/tmp/um-temp-fixtures.txt`) and delete them all when the captures are done.
5. Report any real personal data found in committed fixtures; do not copy it into the manual.

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
- `floating: true` also releases the viewport-based `max-height` of inner scroll areas whose
  content already fits (a modal body capped at `100vh - N`). Otherwise the manual cuts them at
  its own viewport height.

#### Mobile captures (375 px)

When the mobile layout differs from desktop, capture it too. `@media` queries evaluate against
the **viewport**, and in the manual that is the reader's screen, not the frame. So mobile rules
must be resolved at capture time:

1. Load the same route in a same-origin iframe 375 px wide with `border:0`; a border shrinks
   `innerWidth`. Same origin means the iframe shares `sessionStorage` with the tab.

   ```js
   const frame = document.createElement('iframe');
   frame.style.cssText = 'position:fixed;top:0;left:0;width:375px;height:812px;z-index:99999;background:#fff;border:0';
   frame.src = location.pathname;
   document.body.appendChild(frame);
   ```

2. Inject the snippet into `frame.contentDocument` (with the nonce, as above), reach the state
   inside the iframe, and capture with `flattenMedia: true`:

   ```js
   frame.contentWindow.__umCap('main-mobile', frame.contentDocument.querySelector('.page-root'), { pairs, flattenMedia: true });
   ```

   `flattenMedia` keeps the `@media` rules that match the 375 px viewport without their wrapper,
   drops the ones that do not match, and records `viewportWidth`. Check it worked: the capture's
   rules must contain no `@media` text.
3. React-controlled inputs inside the iframe need the native setter plus an `input` event:
   `Object.getOwnPropertyDescriptor(frame.contentWindow.HTMLInputElement.prototype, 'value').set.call(input, value)`.
4. `embed-app-frames.mjs` gives every fixed-viewport capture its own stylesheet, so its flattened
   rules never restyle the desktop captures, and it renders the capture 375 px wide, centered.

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

- Download without asking (see "Downloads" in `SKILL.md`). Run
  `__umExport('app-captures.json', { appVersion: '<version from package.json>' })`, which saves
  it to the browser's downloads folder with `meta { capturedAt, appVersion }`.
- **Verify the file on disk before `__umClear()`.** From the second download on a site, Chrome may
  block it silently or show a "download multiple files" prompt that only the user can accept
  (**Allow** / **Permitir**). If the file does not appear within a few seconds, ask the user about
  that prompt instead of waiting. If downloads stay blocked, POST the payload to the local snippet
  server instead: an endpoint bound to `127.0.0.1` that accepts only the app's origin and plain
  `[a-z0-9-]+.json` file names.
- Sanitization pairs match **within one text node or attribute**. A value split across elements
  (`ID: <span>50</span>`), or text such as `ID: 50` with no delimiter to anchor a pair, can
  survive. `__umCheck` catches it; fix it by post-processing the exported HTML before embedding.
- In the manual, put an empty host inside each mockup, after the `mockup-bar`:

  ```html
  <div class="mockup">
    <div class="mockup-bar">…</div>
    <div class="app-frame" data-cap="filters"></div>
  </div>
  <div class="figcap">Panel “Filtrar” con los seis filtros (datos de ejemplo).</div>
  ```

- The `mockup-url` holds only the path of the captured page (`/tools/user-management`) or the
  dialog title, never the host of the environment it was captured from.

- Embed:

  ```bash
  node <skill-dir>/scripts/embed-app-frames.mjs ~/Downloads/app-captures.json user-guides/<slug>.html --page-background=<app page background>
  ```

  `--page-background` is the app's page color, so cards and modals sit on the same background as
  in the product. Read it from the app's `body` computed style.

- Pass several exports to combine sessions (for example old captures plus new local-mock and
  mobile captures). Rule indexes are remapped, and for a repeated capture name the later file wins:

  ```bash
  node <skill-dir>/scripts/embed-app-frames.mjs old.json local.json mobile.json user-guides/<slug>.html --page-background=#ededed --host-css=design-system-host.css
  ```

- `--host-css=<file>` adds rules for the design system's floating layers when the generic host CSS
  is not enough, for example releasing a modal's inner scroll area or pinning a popover root:

  ```css
  [data-capture-root] .andes-modal__scroll,[data-capture-root] .andes-modal__content{max-height:none!important;overflow:visible!important;}
  ```

- The script writes `<span data-app-frames-meta>Capturas: YYYY-MM-DD · App vX</span>` into the
  header's `doc-meta` (and replaces it on re-runs), so readers know how current the screens are.
- The runtime renders frames lazily (IntersectionObserver, 800 px ahead). Each host gets
  `role="img"` and `aria-label="Captura de pantalla: <figcap>"`, while the rendered capture is
  `inert` and `aria-hidden`. `beforeprint` renders everything for print and PDF.

### 6. Everything you want to show must be fully visible

A capture that shows a dropdown, menu, popover, tooltip or modal is only useful if that layer is
**entirely inside the frame**. The embed runtime fits each frame after rendering:

- trims captured empty space above and below;
- keeps floating layers (popovers, the modal ✕) inside with 16px of air;
- narrows the content when a fixed-position layer sticks out of a fluid root;
- scales down as a last resort.

Still, measure every frame in the browser. Lazy frames only render when visible, and
IntersectionObserver does not fire in a background tab, so first force every frame to render with
`window.dispatchEvent(new Event('beforeprint'))` and wait a few seconds. The check must return
`[]`:

```js
[...document.querySelectorAll('.app-frame')].flatMap((host) => {
  const page = host.shadowRoot.querySelector('.app-frame__page');
  const pageRect = page.getBoundingClientRect();
  const box = { l: Infinity, t: Infinity, r: -Infinity, b: -Infinity };
  page.querySelectorAll('[data-capture-root], [data-capture-root] *').forEach((element) => {
    const rect = element.getBoundingClientRect();
    const style = getComputedStyle(element);
    if (!rect.width || !rect.height || style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return;
    box.l = Math.min(box.l, rect.left); box.t = Math.min(box.t, rect.top);
    box.r = Math.max(box.r, rect.right); box.b = Math.max(box.b, rect.bottom);
  });
  const gaps = [box.t - pageRect.top, pageRect.bottom - box.b, box.l - pageRect.left, pageRect.right - box.r].map(Math.round);
  return gaps.some((gap) => gap < 16) ? [[host.dataset.cap, gaps]] : [];
});
```

Then look at a screenshot of each frame that shows an open layer. If a layer is cut, recapture it
from a position where it opens inside its container, or trim the fragment with `transform`.

### 7. Verify visually

Serve the manual locally (`python3 -m http.server --bind 127.0.0.1`), open it in the browser and
compare every frame against the live screen. Scroll with `behavior: 'instant'` before each
screenshot, because `html{scroll-behavior:smooth}` makes `scrollIntoView` animate and the
screenshot lands mid-scroll. Fix anything that differs: a floating layer still
off-flow, a shell adding height, or a missing font. Also confirm that the frames render in the
final destination (for example the Grid viewer). Delete the downloaded JSON when done, or tell
the user where it is.

## Fallback

Use hand-drawn Heritage Spec mockups (`mockup-body`) only when the app cannot be opened, a gate
blocks access, or stylesheets are cross-origin and blocked. In that case, say in the report that
the mockups are approximations.
