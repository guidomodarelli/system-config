---
name: frontend-structure-accessibility-best-practices
description: Enforce semantic HTML, accessibility attributes, component structure, and descriptive naming in MELI/Nordic frontends. Use when creating or updating React components, markup, or styles to keep actions accessible and code organized.
---

# Frontend Structure and Accessibility Best Practices

## Quick start
Use semantic HTML for actions, apply accessibility attributes when behavior is not obvious, and keep each component’s logic and styles separated in dedicated folders with descriptive names.

## Core workflow
1. Choose the most semantic HTML element for each interaction (e.g., `button` for actions).
2. Add `aria-` attributes or roles when semantics or behavior need clarification.
3. Split component logic and styles into dedicated files (e.g., `Component.jsx` and `Component.module.scss`).
4. Place each component in its own folder with related files.
5. Name components and CSS classes descriptively based on purpose.

## Guidelines
- **Semantics**: Use `button`, `a`, `input`, `label`, and `form` appropriately; avoid `div` with click handlers for actions.
- **Accessibility**: Add `aria-label`, `aria-describedby`, `role`, and keyboard handling when behavior is custom or non-standard.
- **Separation**: Keep UI logic and styling in separate files; avoid inline styles for reusable components.
- **Structure**: One component per folder with a clear entry file and a co-located style module.
- **Naming**: Use descriptive, intent-revealing names for components and classes (e.g., `LoginForm`, `UserAvatar`, `ProductCard`).

## Patterns

### Semantic action
```
<button type="button" onClick={handleSearch}>
  {i18n.gettext('Buscar')}
</button>
```

### Accessible non-obvious behavior
```
<div role="button" tabIndex={0} onKeyDown={handleKeyDown} onClick={handleClick} aria-label="Abrir filtros" />
```

### Component structure
```
components/
  ProductCard/
    ProductCard.jsx
    ProductCard.module.scss
```

## Quick checklist
- Semantic HTML used for actions.
- Accessibility roles/aria added where behavior is not obvious.
- Logic and styles separated into dedicated files.
- Each component has its own folder.
- Names are descriptive and purpose-driven.
