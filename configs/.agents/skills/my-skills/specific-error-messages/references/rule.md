## Rule: Be highly specific with error messages

When you create or modify code that throws, rejects, logs, or displays errors, error messages must be highly specific and actionable.

Avoid generic messages like "Error", "Request failed", "Something went wrong", "Invalid data", or "Bad request" unless they are wrapped with precise context.

### Requirements

- **Include the operation**: State what failed and where (component/module/function), for example: `RoleDetails:fetchRole failed`.
- **Include key identifiers**: Include the minimum identifiers needed to debug quickly (for example: `roleId`, `domainId`, `subdomainId`, `userId`, `revisionId`, `applicationKey`) and relevant filter/query values.
- **Include dependency context (when applicable)**:
  - Service/client name (for example: `role-management`, `users`, `kvs`, `biso`).
  - HTTP method + path (or a stable endpoint name) and status code when available.
  - A request/correlation identifier if present (for example: `x-request-id`, trace id).
- **Avoid sensitive data**: Never include secrets, tokens, cookies, authorization headers, or full PII. Prefer stable IDs over personal fields.
- **Differentiate user-facing vs logs**:
  - User-facing messages must be short, clear, and safe; they may include an error code and request id for support.
  - Logs must include technical context and the original error object/stack.
- **Preserve the original error**: When wrapping/rethrowing, attach the original error as `cause` when supported.
- **No silent failures**: Do not swallow errors without a deliberate fallback and a log entry that includes context.

### Notes

- If the same error is used in multiple places, centralize message construction in a helper to keep formatting consistent.
- If you must include user input, sanitize and truncate it.
