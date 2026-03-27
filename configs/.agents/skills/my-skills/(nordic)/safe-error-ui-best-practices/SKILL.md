---
name: safe-error-ui-best-practices
description: Safe error handling and UI fallback practices for MELI/Nordic frontends. Use when adding or updating error states, input/prop validation, or tests so user-facing errors avoid sensitive data, fallbacks are action-oriented, inputs/props are validated before rendering, and automated tests cover error scenarios.
---

# Safe Error UI Best Practices

## Quick start
Hide sensitive details from user-facing errors, show simple action-oriented fallback UI, validate inputs and props before rendering, and test error scenarios to keep behavior consistent.

## Core workflow
1. Define user-facing error messages that avoid sensitive data.
2. Render fallback UI with short, action-oriented copy.
3. Validate inputs and props before rendering or using them.
4. Add automated tests that cover error scenarios and fallback UI.

## Guidelines
- **No sensitive info**: Do not expose stack traces, IDs, tokens, or internal details in user-visible errors.
- **Actionable fallback UI**: Provide simple messages that guide the next step (retry, reload, contact support).
- **Pre-render validation**: Validate inputs and props early to avoid rendering with invalid data.
- **Test coverage**: Include automated tests for error states to ensure consistent handling and messaging.

## Patterns

### Fallback UI with action-oriented message
```
if (hasError) {
  return <Fallback message="No pudimos cargar los datos. Intentá de nuevo." />;
}
```

### Validate props before render
```
if (!Array.isArray(items)) {
  return <Fallback message="Datos inválidos. Intentá de nuevo más tarde." />;
}
```

### Test error scenario
```
it("renders fallback when request fails", async () => {
  mockRequestFailure();
  render(<Container />);
  expect(await screen.findByText(/Intentá de nuevo/)).toBeInTheDocument();
});
```

## Quick checklist
- User-facing errors contain no sensitive information.
- Fallback UI copy is simple and action-oriented.
- Inputs and props are validated before render.
- Tests cover error scenarios and fallback behavior.
