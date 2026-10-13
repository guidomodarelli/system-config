# User-Facing Feedback Rules — SSR + React

These rules apply when a critical or async action modifies, loads, or requests data: submit, search, navigation, edit, retry, or mutation. For user-facing copy wording, see `User-facing copy` in `frontend-style.md`.

## Validation and states

- Validate inputs and the allowed state before running the action; block an invalid action instead of letting it fail silently.
- Render loading, success, empty, and error explicitly and accessibly, close to the control that started the operation.
- Keep validation state, operation state, and the error tracking context separate; do not reuse one generic message for different states.
- Clear `errorMessage`, `validationMessage`, the error tracking context, timers, listeners, and `AbortController`s when the resource, facility, access, or filter changes, when a modal closes or reopens, and when a new attempt or retry starts.
- Never show an error from a previous resource while a new resource is loading or ready, and never let a previous result update a new selection.

## Error tracking feedback

- Use the project's error tracking feedback component (for example, a snackbar wired to the error monitoring tool) only when a real error tracking context exists and the failure is actionable or unexpected and needs tracking in the error monitoring tool. Never fabricate a context from the component; without one, show a safe visual fallback.
- Use the design system's regular message or snackbar components for loading, information, expected warnings, local validation, empty lists, and valid business states. A degraded but valid response (for example a `202` with pending requirements) keeps its status and stays a business state, not a technical error.
- Enable retry only when it is safe or idempotent, or resumes known progress; a retry must never create a duplicate mutation.
- Keep the public message short, localized, and separate from the technical detail.
- The detail may include operation, stage, category, code, dependency, status, counts, and allowed request, correlation, or trace IDs. Never include the raw condition, upstream payload, full request or response, headers, cookies, tokens, secrets, or full PII in the detail, logs, DTOs, or test assertions.

## Accessibility

- Associate feedback with the affected control or region.
- Use suitable roles and live regions without announcing the same error twice.
- Keep focus, close, and retry usable from the keyboard.

## Tests

- Cover happy path, error, loading, empty, retry, cancellation, and partial states when the flow has them.
- For the error tracking feedback component, cover: valid error tracking context, unexpected error without retry, fallback without context, stale-state cleanup, and no snackbar in expected states.
- Test logs only when they are part of an explicit contract; prefer asserting the public projection and the sanitized detail.
