---
name: test-conventions
description: Aplica convenciones de naming y estructura de tests, expectativas de coverage, ubicación de mocks, bloques de reporte (Commentary/Validation/Error), contratos de feedback de error reporting, limpieza de stale errors y ejecución obligatoria de tests antes de completar cualquier cambio. Usar siempre al crear, actualizar o revisar tests automatizados, incluidos tests Jest/RTL de retries, loading, empty states, respuestas parciales, contexto de error reporting o flows async de modals.
metadata:
  tags: "context-optimized-v1.20.1"
---

## Quick start

- Confirm the project's test framework and local patterns; default to Jest if unspecified.
- Place tests adjacent to implementation with `.spec` filenames, "should do X when Y" titles, and AAA/GWT structure.
- Cover happy paths, error cases, and significant edge conditions; mock external dependencies via `__mocks__`.
- Do not test source files by reading exact text, styles, SQL strings, SQL fragments, or ORM/query-builder call parameters; assert observable behavior or public contracts instead.
- Provide runnable test code, then include the required Commentary and Validation blocks (and Error when needed).

## Mandatory execution rules

- Before marking any change as done, run the relevant tests and verify they pass.
- When adding, modifying, or removing functionality, add or update the corresponding tests in the same change.
- If tests cannot be executed in the current environment, explicitly state what could not be validated and why.

## Error-reporting feedback contracts

When a flow reports failures to a support diagnostic sink (error tracker) or uses an error-reporting feedback component, test the complete observable contract rather than only the visible copy:

- An actionable or unexpected failure with a real error context renders the error-reporting component and preserves the safe public message.
- Loading, expected domain states, empty results, validation feedback, and successful outcomes do not render the error-reporting component.
- Missing error context uses a safe fallback message and never fabricates context.
- Changing the selected resource, closing/reopening a modal, starting a new attempt, or retrying clears stale `errorMessage` and `errorContext` before the next request.
- A degraded `202` response with `EXTERNAL_REQUIREMENT_PENDING` and no explainable requirements preserves the public status and carries safe error context when the product contract requires support tracking.
- Error-reporting detail assertions must verify allowlisted diagnostic fields and absence of raw conditions, upstream payloads, request/response objects, headers, cookies, tokens, secrets, and full PII.
- Retry assertions must verify that the callback is safe and does not create duplicate mutations.

Prefer route/service contract tests for response `error_context` and component tests for rendering, cleanup, retry, and fallback behavior. Do not assert implementation-only logger calls unless logging is the explicit contract; assert the sanitized public/diagnostic projection instead.

## Resources

- See [rule.md](references/rule.md) for full conventions and output requirements.
