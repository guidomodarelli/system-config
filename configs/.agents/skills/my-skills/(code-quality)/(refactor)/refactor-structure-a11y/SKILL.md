---
name: refactor-structure-a11y
description: Enforce semantic HTML, accessibility attributes, component structure, descriptive naming, modularization by responsibility, hardcoded value extraction, duplication elimination, and cohesion/coupling principles in frontends. Use when creating or updating React components, markup, styles, or refactoring frontend code.
---

# Frontend Structure and Accessibility Best Practices

## Quick start
Use semantic HTML for actions, apply accessibility attributes when behavior is not obvious, and keep each component's logic and styles separated in dedicated folders with descriptive names. Modularize by responsibility, extract hardcoded values to constants or configuration, and eliminate duplication.

## Core workflow
1. Choose the most semantic HTML element for each interaction (e.g., `button` for actions).
2. Add `aria-` attributes or roles when semantics or behavior need clarification.
3. Split component logic and styles into dedicated files (e.g., `Component.jsx` and `Component.module.scss`).
4. Place each component in its own folder with related files.
5. Name components and CSS classes descriptively based on purpose.
6. Extract hardcoded values with functional meaning (colors, breakpoints, URLs, thresholds, messages) to constants or configuration files.
7. Organize code in cohesive folders by responsibility (`utils/`, `constants/`, `services/`, `adapters/`, `components/`, `hooks/`).
8. Eliminate duplicated logic; if the same pattern appears in two or more places, extract it to a shared module.

## Guidelines
- **Semantics**: Use `button`, `a`, `input`, `label`, and `form` appropriately; avoid `div` with click handlers for actions.
- **Accessibility**: Add `aria-label`, `aria-describedby`, `role`, and keyboard handling when behavior is custom or non-standard.
- **Separation**: Keep UI logic and styling in separate files; avoid inline styles for reusable components.
- **Structure**: One component per folder with a clear entry file and a co-located style module.
- **Naming**: Use descriptive, intent-revealing names for components and classes (e.g., `LoginForm`, `UserAvatar`, `ProductCard`).
- **Hardcoded values**: Extract magic numbers, literal strings, URLs, and configuration values to named constants or config files when they carry functional meaning.
- **Modularization**: Keep each module focused on a single responsibility. If a module grows beyond its original concern, split it.
- **Duplication**: Do not repeat logic across components; extract shared behavior to `utils/` or `hooks/`.
- **Cohesion and coupling**: Favor high cohesion (each module does one thing well) and low coupling (modules depend on abstractions, not implementation details). Apply SOLID principles when they add real value to the design.

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

### Hardcoded value extraction
```
// constants/thresholds.js
export const MAX_VISIBLE_ITEMS = 5;
export const DEFAULT_PAGE_SIZE = 20;

// Component.jsx
import { MAX_VISIBLE_ITEMS } from '@/constants/thresholds';
```

### Modularization by responsibility
```
src/
  components/    # UI components
  hooks/         # Custom React hooks
  services/      # API and business logic
  adapters/      # External system integrations
  utils/         # Pure utility functions
  constants/     # Shared constants and configuration
```

## Quick checklist
- Semantic HTML used for actions.
- Accessibility roles/aria added where behavior is not obvious.
- Logic and styles separated into dedicated files.
- Each component has its own folder.
- Names are descriptive and purpose-driven.
- No hardcoded values with functional meaning remain inline.
- Each module has a single, clear responsibility.
- No logic is duplicated across modules.
- Cohesion is high and coupling is low.
