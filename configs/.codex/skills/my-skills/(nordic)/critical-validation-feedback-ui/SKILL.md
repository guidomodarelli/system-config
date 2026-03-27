---
name: critical-validation-feedback-ui
description: Ensure critical UI interactions have pre-action validation and clear, visible feedback (errors or helper text). Use when adding or updating forms, searches, navigations, edits, or async actions in MELI/Nordic frontends to avoid silent failures.
---

# Critical Validation and Feedback

## Quick start
Before executing any critical action, validate inputs and state, then show a clear error or helper message next to the triggering control or field. Make feedback visible and actionable.

## Core workflow
1. Identify critical interactions (submit, search, navigation, edit, delete, async load).
2. Define required inputs, allowed states, and blocking conditions.
3. Validate immediately before the action; avoid firing requests when validation fails.
4. Display error or helper feedback inline and near the field or control.
5. Ensure loading and empty states are explicit and not silent.
6. Reset feedback when the user corrects the issue.

## Guidelines
- **Visibility**: Place feedback adjacent to the field or action; avoid only console logs or toasts for form errors.
- **Specificity**: Explain what failed and how to fix it; avoid vague messages.
- **Critical actions**: Always block the action when validation fails (disable button or prevent handler).
- **Asynchronous flows**: Show loading indicators and handle empty/error states with clear text.
- **Navigation/search**: Validate input (required, format) before routing or querying.
- **Edits**: Validate required fields, minimum lengths, and allowed ranges; show helper text while typing when possible.

## Patterns

### Pre-action validation
```
if (!isValid) {
  setError('Ingresa un termino de busqueda valido');
  return;
}
```

### Inline feedback near action
```
<Button ... />
{error && <Text ...>{error}</Text>}
```

### Loading feedback
```
{isLoading && <Spinner />}
```

## Quick checklist
- Critical actions validate inputs and state before executing.
- Validation failures block the action.
- Error/help text is visible and placed next to the field/action.
- Loading, empty, and error states are explicit.
- Feedback is cleared when the issue is fixed.
