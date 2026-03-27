## Rule: Use the revisions route pattern in api/

When creating or updating routes under `api/` that fetch user revisions or similar list endpoints, follow this pattern.

### Requirements

- Use `router.get`, `router.post`, `router.put`, `router.patch`, `router.delete`, etc. as appropriate, along with the suitable authorization middleware for your context (for example, `authorizeByPermissionList` with `KRAKEN_ROLE_MANAGEMENT_APPLICATION_KEY`, or the required authorization method/middleware for your endpoint).
- Keep the handler signature `(req, res)` and use `res` directly; do not rename or shadow it.
- Call the specific service method for your route, e.g. `SomeService.method(req, userId, searchParams)`.
- Use a promise chain with `.then(...)` and `.catch(...)`.
- Do not use `async` or `await`.
- Depending on the case, use `res.send(...)`, `res.status(...).send(...)`, or both to send responses.
