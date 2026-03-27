---
name: react-i18n-jsx-no-literals
description: Enforces i18n.gettext for all user-facing strings in React (JSX literals, modal titles, buttons, placeholders, helper/error text, toast messages, labels, aria/sr labels) to satisfy @meli-lint/react/i18n-jsx-no-literals. Use when fixing lint errors about missing i18n.gettext or when adding/changing user-facing text in React components; add useI18n from nordic/i18n and wrap literals, preserving existing module conventions.
---

# React i18n JSX No Literals

## Quick start
Apply `i18n.gettext(...)` to every user-facing string and add `useI18n` when missing, following Nordic i18n conventions and the lint rule `@meli-lint/react/i18n-jsx-no-literals`.

## Core workflow
1. Locate JSX literals and user-facing strings in props (title, placeholder, label, helper, error, tooltip, aria, etc.).
2. Import `useI18n` from `nordic/i18n` unless the file already uses a different i18n module (keep existing convention).
3. Add `const { i18n } = useI18n();` (or equivalent) in the component.
4. Wrap literals and user-facing strings with `i18n.gettext(...)`.
5. For interpolations, use placeholders: `i18n.gettext('Texto {0}', value)`.
6. Avoid translating user-generated content or IDs unless they are user-facing literal labels.
7. Keep existing non-user-facing literals untouched (CSS classes, test ids, enum keys, data attributes).

## Treat these as user-facing
- JSX text nodes: `<p>Texto</p>`
- Props that render text: `title`, `label`, `placeholder`, `helper`, `description`, `srLabel`, `aria-label`, `alt`, `tooltip`, `emptyMessage`, `buttonText`, toast/notification messages
- Error messages shown to users (including in modals or notifications)
- Tag labels, chip labels, menu items, dropdown options

## Do not translate
- CSS class names, ids, keys, data attributes
- Internal enum values, route names, analytics event names
- Variables that already contain translated text from backend (unless explicitly required)

## Patterns

### Basic JSX literal
```jsx
<p>{i18n.gettext('Filtrar')}</p>
```

### Props with literals
```jsx
<Modal title={i18n.gettext('Filtrar')} />
<Input placeholder={i18n.gettext('Buscar...')} />
```

### Interpolation
```jsx
i18n.gettext('Eliminar filtro: {0}', value)
```

### Conditional literal
```jsx
{checked ? i18n.gettext('Habilitado') : i18n.gettext('Deshabilitado')}
```

### Using existing translated values
```jsx
// If label is already a translated key/value
<p>{i18n.gettext(label)}</p>
```

## Quick checklist
- `useI18n` imported and used
- No raw user-facing literals in JSX
- All user-facing string props wrapped
- Interpolations use `{0}` placeholders
- Non-user-facing literals left untouched
