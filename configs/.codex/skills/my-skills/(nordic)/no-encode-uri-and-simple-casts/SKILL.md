---
name: no-encode-uri-and-simple-casts
description: Prefer simple Number/String casting for type conversion and avoid encodeURIComponent when middleware already validates input. Use when handling query/params in MELI/Nordic code so conversions stay explicit and redundant encoding is avoided.
---

# Simple Casting, No encodeURIComponent

## Quick start
When inputs are already validated by middleware, use explicit `Number()` or `String()` casts for type conversion and avoid `encodeURIComponent` for query/param values.

## Core workflow
1. Confirm the route or handler uses a schema validation middleware.
2. Use `Number()` or `String()` for conversions at the point of use.
3. Skip `encodeURIComponent` when the input is already validated and expected to be safe.
4. Keep only encoding needed for non-validated or external inputs.

## Guidelines
- **Casts**: Use `Number(value)` or `String(value)` for explicit conversions.
- **No redundant encoding**: Do not apply `encodeURIComponent` to inputs already validated by middleware.
- **Boundaries**: If data comes from external or unvalidated sources, encoding is still allowed.
- **Clarity**: Prefer local, explicit conversion over implicit coercion.

## Patterns

### Cast string to number
```
const offset = Number(req.query.offset);
```

### Cast number to string
```
const siteId = String(req.query.siteId);
```

### No encodeURIComponent for validated inputs
```
const query = String(req.query.q);
service.search({ q: query });
```

## Quick checklist
- Inputs come from validated middleware.
- Conversions use `Number()` or `String()`.
- `encodeURIComponent` is not used for validated inputs.
