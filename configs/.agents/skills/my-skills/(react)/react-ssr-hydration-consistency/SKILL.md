---
name: react-ssr-hydration-consistency
description: Prevents and diagnoses React SSR hydration mismatches in server-rendered Nordic routes and components by keeping server HTML and first client render deterministic. Use whenever implementing, changing, reviewing, or debugging Nordic SSR or hydration, preloaded or query-derived initial UI, server-rendered code that touches browser-only APIs, feature flags, dates, randomness, locale, timezone, media queries, storage, invalid HTML nesting, client-only libraries, hydration warnings, or content changing during initial load—even when user does not mention hydration. Do not use for purely CSR components that never hydrate server HTML.
---

# React SSR Hydration Consistency

## Core invariant

Keep this sequence deterministic:

```text
server source of truth
  → safe serialized snapshot
  → identical first client render
  → browser-only and live updates after hydration
```

Hydration compares server HTML with first client render. A later effect may intentionally update UI, but first client tree must still match server tree. Fix source of divergence instead of suppressing warning.

## Workflow

### 1. Map SSR and hydration boundary

Before editing, locate:

- server route/controller/page that builds render props;
- Nordic `Page state`, serializer, or equivalent preloaded-state channel;
- client entrypoint calling `hydrate` or `hydrateRoot`;
- constructors, lazy initializers, render functions, and HOCs that derive initial state;
- direct reads from `window`, `document`, `navigator`, storage, `matchMedia`, current time, randomness, locale, or timezone.

Trace every value that can change visible markup. Record server value and first client value separately.

### 2. Reproduce exact mismatch

Use same URL, query, user context, device, locale, timezone, and feature-flag assignment seen in failure. Capture:

- React hydration warning and component diff;
- server-rendered markup or relevant subtree;
- preloaded state sent to browser;
- first client props/state before effects;
- browser console and `onRecoverableError` output.

Do not blame CSS, bundles, extensions, or React until server/client values are compared.

### 3. Classify root cause

Classify before choosing fix:

1. Different data source between server and client.
2. Browser-only API read during initial render.
3. Non-deterministic value (`Date`, random value, generated ID).
4. Locale/timezone/device mismatch.
5. Feature flag or external data changed without snapshot.
6. Invalid HTML nesting repaired by browser parser.
7. Client-only library rendered without stable SSR boundary.
8. External DOM mutation, such as browser extension, after code causes are ruled out.

### 4. Fix narrowest source of divergence

Prefer single shared initial source. Keep post-hydration behavior unchanged unless it causes separate defect. Avoid modifying child component when parent supplies inconsistent initial prop.

### 5. Prove consistency

Add behavior-level regression test, run relevant tests and real Nordic build, then verify affected URL in browser with console and network evidence.

## Deterministic initial-state contract

### Server data is authoritative for first render

If server already has request/query/flag/data value, normalize once and serialize it. Client must consume serialized value for first render rather than rereading browser environment.

```js
// Server/controller
const initialParams = pickAllowedInitialParams(validatedQuery);

return res.render(View, {
  initialParams,
  results,
});
```

```js
// View
const initialParams = resolveInitialParams(props.initialParams);

const preloadedState = {
  ...publicProps,
  initialParams,
};

return <Page state={preloadedState}>{/* same initial tree */}</Page>;
```

Treat serialized empty object as authoritative. Falling back to `location.search` when server sent `{}` reintroduces dual source.

```js
const hasSerializedState =
  initialParams !== null &&
  typeof initialParams === 'object' &&
  !Array.isArray(initialParams);

return hasSerializedState ? initialParams : getQueryParams();
```

### Validate and allowlist request-derived state

Validate query/body/params before controller reads them, using `@meli/input-validation` and project route conventions. Copy explicit supported keys into new object; do not spread arbitrary `req.query` into state or service options.

```js
const INITIAL_PARAM_KEYS = ['page', 'search', 'sort'];

const pickAllowedInitialParams = (query = {}) => {
  const params = {};

  INITIAL_PARAM_KEYS.forEach((key) => {
    if (Object.prototype.hasOwnProperty.call(query, key)) {
      params[key] = query[key];
    }
  });

  return params;
};
```

Preserve URL-facing representation in snapshot. Derive separate copy for service-specific conversion, such as one-based to zero-based page.

### Serialize only browser-safe data

Never put these in `Page state`, inline JSON, globals, URL, or hydration props:

- cookies, session IDs, CSRF values, access/refresh tokens;
- authorization headers or request headers;
- secrets, credentials, internal configuration;
- unnecessary PII or full authenticated-user payloads.

Send minimum public fields required to render. Rely on Nordic serializer rather than hand-built script/JSON injection. React escaping does not make sensitive data safe to expose.

## Browser-only APIs

Reading browser state during first client render is unsafe when server cannot produce same value:

- `window`, `document`, `navigator`;
- `localStorage`, `sessionStorage`;
- `matchMedia`, viewport width, DOM measurements;
- browser-only SDKs.

Do not use `typeof window !== 'undefined'` branch that changes markup:

```jsx
// Wrong: server and first client render different trees.
return typeof window === 'undefined' ? <Skeleton /> : <Dashboard />;
```

Render stable shared fallback first, then update after hydration:

```jsx
const [browserPreference, setBrowserPreference] = useState(null);

useEffect(() => {
  setBrowserPreference(readBrowserPreference());
}, []);

return browserPreference === null
  ? <StableFallback />
  : <PreferenceAwareView value={browserPreference} />;
```

If server already knows device/context, serialize it and use same value on client instead of waiting for effect. Prefer existing Nordic/Groot media-query HOC that receives server device context.

## Time, randomness, IDs, locale, and timezone

Avoid values generated independently during render:

- `Date.now()`, `new Date()` used in visible output;
- `Math.random()`;
- counters or module-global IDs;
- locale formatting based on implicit runtime defaults;
- timezone-sensitive formatting with different server/client zones.

Choose matching strategy:

- Calculate once on server and serialize value.
- Use fixed locale/timezone supplied by request context.
- Use stable domain ID from data.
- Use React `useId` only when component tree/order is identical.
- Defer truly browser-specific display until after hydration behind stable placeholder.

Do not “fix” mismatch by freezing stale data forever. Snapshot only initial render; reconcile live data after hydration.

## Data and feature flags

External data or feature flags can change between SSR and hydration. Capture per-request snapshot used to render HTML and serialize same decision/result.

Do not reevaluate initial feature flag in browser before hydration. After hydration, subscribe/refetch only when product behavior requires live updates.

When data cannot be serialized safely, render stable non-sensitive boundary and fetch after hydration. Keep initial server and client boundary identical.

## HTML structure

Browser parser repairs invalid HTML before React hydrates. Check:

- block elements nested inside `<p>`;
- nested interactive elements (`button` inside `button`, link inside link);
- invalid table/list children;
- duplicated/relocated `<html>`, `<body>`, metadata, or form elements;
- different wrapper/tag chosen by server and client.

Fix semantic markup. Do not suppress parser-caused mismatch.

## Client-only libraries

For library that reads browser globals during import/render:

1. Keep SSR boundary deterministic.
2. Render identical placeholder on server and first client render.
3. Load/import library after hydration when possible.
4. Isolate library to smallest client-only subtree.
5. Preserve dimensions to avoid layout shift.

Do not convert whole page to CSR when only one widget is client-only.

## `suppressHydrationWarning`

Use only when difference is unavoidable, local, harmless, and intentionally not reconciled—for example externally controlled timestamp text. Apply at smallest element and document reason.

Never use it to hide:

- different query/props/state sources;
- browser-only branching;
- invalid nesting;
- feature-flag drift;
- missing snapshot;
- broad page/subtree mismatch.

A warning suppression is not proof of consistent DOM.

## Regression test recipe

Prefer real platform components and behavior over mocks. Build same tree for SSR and hydration.

```jsx
const tree = buildTree({ initialParams: { search: 'foo' } });
const serverMarkup = renderToString(tree);
const recoverableErrors = [];
const container = createTestContainerFromTrustedMarkup(serverMarkup);

act(() => {
  hydrateRoot(container, tree, {
    onRecoverableError: (error) => recoverableErrors.push(error),
  });
});

expect(recoverableErrors).toStrictEqual([]);
expect(within(container).getByRole('textbox')).toHaveValue('foo');
```

Test both:

- non-empty serialized state that controls conditional markup;
- serialized empty/default state while browser URL/storage differs, proving snapshot remains authoritative;
- relevant locale/timezone/device/flag scenario;
- no recoverable hydration error;
- observable DOM and interaction, not source-code strings.

Use test-only trusted `renderToString` output when constructing hydration container. Never use untrusted HTML.

## Build and runtime validation

1. Run focused regression tests.
2. Run related existing component/controller tests.
3. Run lint for modified files.
4. Run real Nordic development and production builds.
5. Start app at project development URL.
6. Hard reload affected deep link with exact query/context.
7. Inspect browser console for hydration warnings.
8. Capture snapshot and XHR/fetch statuses without exposing headers/cookies.
9. Report `PASS`, `FAIL`, or `BLOCKED`; never present auth/environment block as success.

Use `nordic-dev-verify` for browser runtime evidence.

## Scope boundaries

- General fetch architecture: use `react-data-fetching-best-practices`.
- Async effect cancellation: use `react-useeffect-abortcontroller`.
- Render performance: use `react-render-performance-patterns`.
- User-facing translations: use `react-i18n-jsx-no-literals`.
- Route input schemas: use `input-validation` alongside this skill.

This skill owns consistency between SSR HTML and first client render.

## Final checklist

- Same source controls server HTML and first client render.
- Serialized empty/default state remains authoritative.
- Request-derived values validated and copied by allowlist.
- No secrets, tokens, headers, sessions, or unnecessary PII serialized.
- No browser-only reads changing initial markup.
- Time/random/IDs/locale/timezone deterministic.
- Data and feature flags use same initial snapshot.
- HTML nesting valid.
- Client-only libraries have stable minimal boundary.
- `suppressHydrationWarning` absent or narrowly justified.
- `renderToString` + `hydrateRoot` regression passes with zero recoverable errors.
- Nordic build passes.
- Browser hard reload checked and result reported with evidence.
