## Rule: Prevent useEffect race conditions with AbortController

When you detect (or introduce) an async `useEffect` that can run multiple times (for example, because dependencies can change quickly), do **not** use a boolean canceled flag (like `let canceled = false`) as the primary mitigation.

Use **AbortController** to cancel in-flight requests and combine it with an effect-local guard to prevent state updates after cleanup.

### Requirements

- Create `const controller = new AbortController()` inside the `useEffect`.
- Pass `signal: controller.signal` to the HTTP client (Fetch/Axios/Nordic RestClient).
- Return a cleanup function that **always** calls `controller.abort()`.
- Ignore cancellation errors explicitly (for example, `error.code === 'ERR_CANCELED'` or `error.name === 'CanceledError'`).
- Keep error messages **specific** (include what operation failed and key identifiers such as `roleId`).

### Notes

- Aborting is the **primary** mechanism; the `isActive` guard is a safety net for late microtasks or non-abortable work.
- If the current client wrapper does not accept `signal`, extend it to accept `{ signal }` and forward it to the underlying request.
