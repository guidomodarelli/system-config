# Frontend Style Rules — SSR + React + TypeScript

Coding conventions for this stack. Always consult the documentation of the project's SSR framework and design system for their APIs before implementing — these rules cover conventions, not API details.

---

## Components

- Use function components with hooks — no class components.
- Keep components small and single-responsibility. Extract when a component has more than one reason to change.
- Extract complex logic into custom hooks (`use<Name>`).
- Avoid prop drilling beyond two levels — use context or a state manager.
- Never use rest props (`...rest`) — declare all props explicitly.
- **One component per file** — never export more than one component from a single file. A file named `user-card.tsx` exports only `UserCard`.
- **Component placement by scope**:
  - Reusable across pages → `app/ui-components/<component-name>/`
  - Used only within one page → colocated inside `app/pages/<page>/`
- **Atomic size** — keep components at the smallest meaningful unit. A component that mixes concerns (layout + data formatting + interaction) must be split.

## Design system

- Use the project's design system components for all UI elements: buttons, inputs, modals, selects, etc.
- Never build custom replacements for components the design system already provides.
- Use design system props (for example `variant`, `size`, `color`) to control appearance before adding any custom CSS.
- Only add custom CSS when the design system has no prop or component that covers the need.
- Never override internal design system component styles with custom CSS.
- When custom styles are needed, write them as Sass Modules with design system tokens; never hardcode colors, typography, spacing, breakpoints, radius, or elevation.
- Use the project's image component or provider for images, icons, and backgrounds with relative or environment-dependent paths; keep lazy loading and avoid absolute URLs.
- Always consult the design system documentation before selecting a component.

## User-facing copy

- Route every visible React string —labels, buttons, placeholders, helper and error text, toasts, and aria labels— through the project's i18n function (for example, `i18n.gettext`). Reuse existing msgids before creating new ones, and do not hand-edit catalogs that the i18n workflow generates.
- Write labels, buttons, headings, helper text, empty states, confirmations, and progress messages for people who use the product, not for the team that built it.
- Avoid implementation terms in regular UI copy, including `preflight`, `bootstrap`, `provider`, `stack`, `upstream`, `lockfile`, `schema`, `sync`, and `retry` when they describe internal mechanics. Prefer the user-visible action or outcome, such as `Reintentar` instead of `Reintentar preflight`.
- Do not expose internal component names, service names, workflow names, file names, status codes, or infrastructure details in regular UI copy. Keep those details in logs or technical documentation, not in ordinary interface text.
- Keep error messages clear and actionable. Errors may include the minimum technical detail needed to diagnose or resolve the problem, but never expose secrets or unnecessary internal data.
- Review every new or changed user-facing string from the perspective of a non-technical user; if the message explains how the system works instead of what the user can do or expect, rewrite it.

## TypeScript

- Always type props explicitly — no `any`.
- Use `interface` for object shapes; `type` for unions and aliases.
- Never use `enum` — use `const` objects with `as const` or string union types.
- Never use parameter properties in classes.
- Run `tsc --noEmit` after every file change and fix errors immediately.

## Function parameters

- Never use boolean parameters to switch a function's behavior. A call like `getItems(locale, true, true)` is unreadable at the call site, is easy to call with arguments in the wrong order, and every extra flag doubles the hidden combinations, including invalid ones.
- Use a semantic string that names the state or mode instead. When several flags describe one state, collapse them into a single value that only allows valid combinations:

  ```ts
  // ❌ What do `true, true` mean? Is `featuredOnly` without `activeOnly` valid?
  function getItems(locale: string, activeOnly = false, featuredOnly = false) {}
  getItems(locale, true, true);

  // ✅ The call reads as intent and invalid combinations cannot be expressed
  type ItemListScope = 'all' | 'active' | 'active-featured';

  function getItems(locale: string, scope: ItemListScope = 'all') {}
  getItems(locale, 'active-featured');
  ```

- Declare the allowed values as a string union type, or as an `as const` object in `constants/` when the values are reused across modules. Never use `enum` (see TypeScript).
- When replacing an existing boolean parameter, update every call site in the same change; do not keep the boolean and the string side by side.
- This rule covers parameters that select behavior. Boolean props that follow design system or DOM conventions (`disabled`, `checked`, `open`), predicate return values, and boolean fields that come from an upstream payload stay boolean.

## Equality

- Prefer `Object.is(leftValue, rightValue)` over the strict equality operators `===` and `!==` when comparing values.
- Keep `===` or `!==` when `+0` and `-0` must be equivalent, when `NaN` must remain unequal, or when an existing contract explicitly requires strict-equality semantics; do not use `Object.is` for ordering or coercive comparisons.

## Naming

| Entity | Convention | Example |
|--------|-----------|---------|
| Components | PascalCase | `UserProfile` |
| Hooks | camelCase with `use` prefix | `useUserProfile` |
| Files & directories | kebab-case | `user-profile.tsx` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES` |
| Functions & variables | camelCase | `getUserProfile` |

## Module placement

- Keep subrouters focused on route registration, middleware mounting, orchestration, and service calls. Do not add shared utilities or reusable constants inside `api/<resource>/`, `api/services/`, or `services/` modules.
- Place route-specific request schemas and validation middleware built with the project's input validation library in `api/middlewares/validation/`, then re-export them from its `index.js` or `index.ts` barrel. Keep the subrouter responsible for mounting the middleware and handler; see `api-validation-middleware.md`.
- Place shared or reusable utility functions in `utils/` and domain/configuration constants in `constants/`; extract anything reused or carrying domain meaning.

## Performance

- Always use `Array.from(source, callback)` to map collections — arrays and non-array iterables (`Set`, `Map`, `NodeList`) alike — instead of `.map()` or `[...iterable].map()`. It keeps a single mapping idiom and, on non-array iterables, avoids the extra pass of spreading first.
- Avoid unnecessary object cloning with spread — pass objects directly when no mutation is needed.
- Use `React.memo`, `useMemo`, and `useCallback` only when profiling confirms a render bottleneck — not preemptively. When it does, stabilize the handlers passed to memoized children with `useCallback` instead of inline functions.
- Lazy-load routes and heavy components.

## Imports

- When the project's SSR framework re-exports a package, import it from the framework's re-export — never from the underlying package directly.
- Never install packages that the SSR framework already bundles (for example `react` or `react-dom`).
- Check the framework's `package.json` in `node_modules/` before installing any new dependency.
- For lodash availability, mandatory and forbidden methods, see `lodash.md`.

## Logging

- Use the project's logger; never use `console.*` in application code.
- Write each log message with operation, stage, outcome, code, and safe context; never log full payloads or secrets (see `Secrets & PII` in `security.md`).

## Comments

- Comment the WHY, not the WHAT. Well-named identifiers explain themselves.
- Only comment non-obvious constraints, workarounds, or invariants.
- No multi-line comment blocks or docstrings.
