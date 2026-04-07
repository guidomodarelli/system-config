---
name: schema-validation-middleware-centralization
description: Centralize request parameter and query validation in a schema validation middleware (e.g., schemaValidationMiddleware). Use when adding or updating API routes/handlers so validations are not duplicated inside each function.
---

# Schema Validation Middleware Centralization

## Quick start
Validate request params and queries once in a schema validation middleware (e.g., `schemaValidationMiddleware`) and trust validated inputs inside handlers. Avoid duplicating validations in every function.

## Core workflow
1. Check if the route already uses a validation middleware.
2. If missing, add a schema validation middleware with the expected params/query schema.
3. Remove redundant per-handler validation for params/queries already covered by the schema.
4. Keep only business-rule checks that cannot be expressed by the schema.
5. Use the validated values in the handler without re-validating them.

## Guidelines
- **Centralize**: One middleware validates request params/query/body per route.
- **No duplication**: Do not re-validate inputs already validated by middleware.
- **Naming**: Use `schemaValidationMiddleware` or a clear synonym with the same role.
- **Scope**: Middleware covers structural validation; handlers cover business logic.
- **Consistency**: Apply the same validation approach across routes in the module.

## Patterns

### Route with validation middleware
```
router.get(
  '/items',
  schemaValidationMiddleware(itemsQuerySchema),
  async (req, res) => { ... }
);
```

### Handler using validated input
```
const { siteId, q } = req.query;
// Use values directly; schema middleware already validated them.
```

## Quick checklist
- Route includes schema validation middleware.
- No duplicated param/query validation inside handlers.
- Only business rules are validated in handlers.
- Naming and usage are consistent across the module.
