---
name: input-validation
description: Validates req.query, req.body, and req.params in Nordic/Node.js routes using @meli/input-validation. Use when adding route-level validation, fixing UNVALIDATED INPUT ACCESS warnings from input-validation-enforcer, or replacing any AJV/schemaValidationMiddleware usage.
---

# @meli/input-validation

## Rules

- **NEVER use AJV directly.** Never use `schemaValidationMiddleware` (it wraps AJV internally). Use `@meli/input-validation` directly.
- **Two-call pattern required** to both validate and suppress UNVALIDATED INPUT ACCESS warnings:
  1. `schema.validate(req.query)` — local check, returns `true` or falsy
  2. `schema.validate(req.query, { global: true })` — marks all properties as globally validated (call only if step 1 passed)
- **`coerce.boolean()` is too permissive** — accepts `'1'`, `'yes'`, any truthy string. For strict `'true'`/`'false'` query params use `inputValidation.string().regex(/^(true|false)?$/).optional()`.
- **`coerce.number()`** coerces query string numbers (always strings on `req.query`) to numbers before validation.
- **`string().secure()`** adds MELI security checks on string fields (injection, etc.). Prefer over bare `.string()` for user-supplied strings.
- **`.optional()`** makes a field optional (absent = valid). Without it, the field is required.

## Pattern

```js
const inputValidation = require('@meli/input-validation');

const pageQuerySchema = inputValidation.object({
  page:   inputValidation.coerce.number().int().min(0).max(500).optional(),
  size:   inputValidation.coerce.number().int().min(1).max(500).optional(),
  active: inputValidation.string().regex(/^(true|false)?$/).optional(),
  search: inputValidation.string().secure().max(255).optional(),
});

// In middleware:
const isLocallyValid = pageQuerySchema.validate(req.query);
if (isLocallyValid !== true) {
  return res.status(400).json({ code: 400, message: 'Bad request' });
}
pageQuerySchema.validate(req.query, { global: true });
return next();
```

## See also

- [input-validation-guide.md](references/input-validation-guide.md) — full SDK reference and coercion details.
