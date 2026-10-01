# Portuguese version

Read this only when the user asked for a Portuguese version in Step 0. The markup, the language
script and the switch behavior are in DESIGN.md ("Selector de idioma"); this file covers how to
translate and how to verify.

## Source of truth: the app's own catalogs

Read both locales from the branch you document, for example:

```bash
git show origin/develop:i18n/es-AR/messages.po
git show origin/develop:i18n/pt-BR/messages.po
git show origin/develop:app/translations/pt-BR/messages.json
```

- Build the Spanish → Portuguese map by **msgid**: the msgid is the Spanish source text. The es-AR
  catalog can be stale (a string missing there is shown as its msgid), so never require it in es-AR.
- Read plurals too: `msgid_plural` with `msgstr[0]` / `msgstr[1]`.
- Library texts are not in the app catalog. Add them by hand from the library's own pt-BR text, for
  example the `@kraken/static` error page ("Ir à página principal") or relative dates ("há 1 minuto").

## What stays in Spanish (or English)

The Portuguese version shows what a pt-BR operator really sees. Before translating any app text,
check in the source that it is translated:

- **Strings passed to `gettext` through a ternary or a variable**
  (`gettext(count === 1 ? '{0} operador seleccionado' : '{0} operadores seleccionados', …)`). The
  extractor does not pick them up, they are missing from pt-BR, and the app shows them in Spanish. The
  capture and the quote in the text stay in Spanish.
- **Texts hardcoded in the server** (for example an English `errorTitle`): same in every language.
- **Texts from another platform** (Training in App tours, platform "No autorizado" pages): they are
  not in the catalog and cannot be verified, so quote them verbatim.
- **Example data** (names, facilities, codes, process names) and values the operator types.

## Captures

Translate a copy of each capture (`<name>--pt`): text nodes plus `placeholder`, `aria-label`, `title`
and `alt`. Leave `<style>` and `<script>` alone. Report every text left untranslated and review it
against the list above.

- **Sentences split by inline markup:** a catalog key like
  `!Perfecto! Los {1}{0} colaboradores{2} escaneados te seran asignados` renders as
  `…Los <b>3 colaboradores</b> escaneados…`. Translate the whole paragraph with its markup, not node
  by node.
- **Labels built as `{prefix}: {data}`** (pending-change tags, `Agregar: Inventory • Cycle Count`):
  translate only the prefix.
- **Placeholders:** catalog keys with `{0}` match texts with values ("Podés buscar hasta 100 IDs…").
  Use that matching only on capture texts and quotes, never on prose.

## Text

- Same section ids, same structure, `data-cap="<name>--pt"` in every frame.
- **Quotes are app texts.** «…» and “…” always quote an app string; in Portuguese they hold the exact
  pt-BR catalog string, with its values filled in, never a paraphrase. A truncated quote («Este
  usuario está inactivo…») becomes the first sentence of the pt-BR string plus "…". Values the operator
  types (`prueba`, `sin motivo`) go in `<em>`, not in quotes: `check-manual.mjs` checks every quote
  against the catalogs.
- **Only exact catalog matches in prose.** Matching `{0}` keys against prose mixes languages
  ("Quitar de la lista…" → "Remover de la lista…"). Translate prose yourself.
- **Pins:** a `data-target` that names an app text (`button[aria-label="Quitar Ada Lovelace"]`) and a
  `data-target-text` point at the Portuguese capture's text ("Remover Ada Lovelace").
- **Header:** `Público:` instead of `Audiencia:`; `data-title` follows the Spanish title format
  ("Gestão de operadores e contingência · Manual do usuário"). The capture runtime names frames
  "Captura de tela:" by itself when `<html lang>` is pt-BR, and writes the capture date in both headers.
- Glossary terms keep the word the reader sees in the app (`facility`), so `a.term` still resolves.

## Verify

1. `check-manual.mjs` with `--translations` (es-AR) and `--translations-pt` (pt-BR): 0 errors in both
   languages. For Spanish it also accepts the pt-BR msgids.
2. `__umCheckRendered` in both languages (`?lang=pt`), at desktop width and at 390 px.
3. In the destination viewer: the manual opens in Spanish, the switch opens the other language at the
   start of the section being read (its number 16 px below the top, like a TOC jump, not the exact
   scroll position, which drifts because the translation has another length), and the viewer's
   address bar keeps `#sNN`.

When measuring in the shared browser, the user may be using it too: a language change you did not
trigger is a click of theirs. Measure inside an iframe you create, and wait for the new document
instead of the `load` event. If the emulated viewport is wider than the real window, fixed elements
look cut at the edge; compare `innerWidth` with `outerWidth` before reporting an overflow.
