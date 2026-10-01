# Publishing a manual to Grid

Grid (`grid.adminml.com`) shows each document in an iframe that loads `/d/<documentId>/raw`. There is
no upload button for new versions; the editor saves through the documents API, and the same calls
work from a signed-in tab with `scripts/grid-publish.js`.

## What Grid does with the HTML

- **It injects three scripts every time it serves `/raw`:** a state API (`window.GRID`), a popup
  allowlist (`/* Grid: only allow approved Grid domains… */`) and a URL sync
  (`/* Grid: sync iframe URL mutations… */`). A downloaded `/raw` contains them; uploading it back
  stores copies that pile up version after version. Remove them with
  `scripts/strip-grid-injections.py` before every upload; Grid adds them again when serving.
- **The iframe is same-origin with `allow-same-origin allow-scripts …`.** The clipboard works. The
  manual stores nothing in the browser: the language lives in the iframe URL (`/raw?lang=pt`), so
  reloading the Grid page opens it in Spanish again. Grid serves `/raw` without cache (~300 ms per
  load), which is why the language switch translates in place instead of loading the page again.
- **Deep links need the navigation script:** Grid keeps `…/view#permissions` in its own address bar and loads
  the iframe without the hash, so the browser's native jump never happens. The navigation script reads
  the parent's hash (same origin) on load and on `hashchange`, and jumps to the section. Set
  `<meta name="heritage:share-url" content="https://grid.adminml.com/d/<documentId>/view">` so "Copiar
  enlace" copies that URL. The script's `replaceState` inside the iframe reaches Grid's address bar
  through Grid's URL-sync script.
- **The viewer caches `/raw`.** Right after a save the viewer may still show the previous version
  (the version selector says "vN (latest)" with the old N). Refresh with
  `fetch('/d/<id>/raw', { cache: 'reload' })` and `fetch('/d/<id>/view', { cache: 'reload' })`, then
  reload the page. `__gridPublish` does the first two. Even then the version selector can keep the
  old label for one more reload while the iframe already shows the new content: trust
  `__gridInfo().latestVersion` (or the versions API), and reload again before taking screenshots.
  If the iframe still shows the old content after reloading the page, reload the iframe itself
  (`iframe.contentWindow.location.reload()`, waiting for its `load` event) before checking.

## Workflow

1. **Open the document view** in the browser tab the user is signed in (`/d/<documentId>/view`). Never
   type credentials. Inject `scripts/grid-publish.js` with the browser JavaScript tool.
2. **Inspect:** `await __gridInfo('<documentId>')` → latest version, stored filename and iframe width
   (the viewer is usually 1680 px wide on desktop, so the section map is visible).
3. **Pull the current version** when updating: start `capture-bridge.py --origin
   https://grid.adminml.com --exports /tmp/<work>`, then `await __gridPull('<documentId>', { bridgeUrl:
   'http://127.0.0.1:<port>' })`. It writes `grid-<id>.json` with `{ version, html }`. Strip the
   injections from that `html` before using it as a base.
4. **Write and verify the manual locally** (SKILL.md Steps 1–5): `source-trace.py record`,
   `check-manual.mjs` exiting 0 and `__umCheckRendered()` returning `ok: true` at 1280 and 390 px.
5. **Serve the final file** with `capture-bridge.py --origin https://grid.adminml.com --directory
   <dir-with-the-file>` and get its hash: `shasum -a 256 <file>`.
6. **Publish:**

   ```js
   await __gridPublish({
     documentId: '<documentId>',
     sourceUrl: 'http://127.0.0.1:<port>/<file>.html',
     sha256: '<hash from shasum>',
     expectedVersion: <latest version from step 2>,
   });
   ```

   It aborts if the browser received a different file or the document moved past
   `expectedVersion` (someone else saved). It takes the edit lock, saves with
   `PUT /api/v1/documents/<id>/content?if_version=<expectedVersion>` (`Content-Type: text/html`,
   `x-csrf-token` from the page's `<meta name="csrf-token">`), always releases the lock, and refreshes
   the cache. The result has the new version number.
7. **Verify in the viewer** after a reload: version selector shows the new version, Grid's scripts are
   back (`iframe.contentWindow.GRID` exists), the section map and pill work, and the screenshot matches
   the local check. Inject `check-rendered.js` in the Grid tab and run
   `await __umCheckRendered(document.querySelector('iframe').contentWindow)`: it must return
   `ok: true` (every capture rendered, none cut, pins next to their elements).
8. **Stop the bridge** and delete the pulled and staged files.

## Rules

- Publish only the document the user pointed to. Every new version is reversible through Grid's
  version history; say which version was the previous one in the report.
- Never upload a file that still contains Grid's markers or real data; re-run the `grep` checks of the
  SKILL.md checklist on the exact file you serve.
- If `POST /lock` fails, someone is editing: stop and tell the user instead of retrying.
