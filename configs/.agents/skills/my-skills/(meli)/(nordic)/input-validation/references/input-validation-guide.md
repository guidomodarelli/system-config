# @meli/input-validation — SDK Reference

> **Rule:** NUNCA usar AJV. NUNCA usar `schemaValidationMiddleware`. Usar este SDK directamente.

## Installation

```json
"@meli/input-validation": "1.4.8"
```

## Basic usage

```js
const inputValidation = require('@meli/input-validation');
```

## Schema types

### object

```js
const schema = inputValidation.object({
  field: inputValidation.string(),
});
```

### string

```js
inputValidation.string()          // required string
inputValidation.string().optional()
inputValidation.string().max(255)
inputValidation.string().min(1)
inputValidation.string().regex(/^[a-z]+$/)
inputValidation.string().secure() // adds MELI injection/XSS checks — prefer for user input
```

### coerce.number (for req.query — always strings)

```js
inputValidation.coerce.number()             // coerces '42' → 42
inputValidation.coerce.number().int()       // must be integer after coercion
inputValidation.coerce.number().min(0)
inputValidation.coerce.number().max(500)
inputValidation.coerce.number().optional()
```

### coerce.boolean — GOTCHA

`inputValidation.coerce.boolean()` accepts ANY truthy string (`'1'`, `'yes'`, `'on'`, etc.) → `true`.

**For strict `'true'`/`'false'` query params, use:**

```js
inputValidation.string().regex(/^(true|false)?$/).optional()
// The `?` makes an empty string valid (absent param). Remove if the field is required.
```

## Two-call pattern (MANDATORY for UNVALIDATED INPUT ACCESS)

The `input-validation-enforcer` proxy wraps `req.query`, `req.body`, and `req.params`. Reading a property
that hasn't been globally validated triggers an UNVALIDATED INPUT ACCESS warning.

**Fix: call `.validate()` twice:**

```js
// 1. Local validation — check schema correctness
const isLocallyValid = schema.validate(req.query);
if (isLocallyValid !== true) {
  // reject the request
}

// 2. Global validation — mark all properties as validated (suppresses enforcer warnings)
schema.validate(req.query, { global: true });
```

Never call the global step without the local step passing first.

## Complete route example (usersGroup/index.js)

```js
const router = require('nordic/ragnar').router();
const inputValidation = require('@meli/input-validation');
const { renderErrorView } = require('@kraken/static');
const { authorizeByPermissionKey } = require('@root/middlewares/authorizationMiddlewares');
const { renderUsersGroups, fetchUserGroups } = require('./controller');

const pageQuerySchema = inputValidation.object({
  page:   inputValidation.coerce.number().int().min(0).max(500).optional(),
  size:   inputValidation.coerce.number().int().min(1).max(500).optional(),
  active: inputValidation.string().regex(/^(true|false)?$/).optional(),
  search: inputValidation.string().secure().max(255).optional(),
});

router.get(
  '/',
  authorizeByPermissionKey('VIEW_USERS_GROUPS_PERMISSION_KEY'),
  (req, res, next) => {
    const isLocallyValid = pageQuerySchema.validate(req.query);

    if (isLocallyValid !== true) {
      return req.xhr || req.headers?.accept?.includes('json')
        ? res.status(400).json({ code: 400, message: 'Bad request' })
        : renderErrorView(req, res, next);
    }

    pageQuerySchema.validate(req.query, { global: true });
    return next();
  },
  fetchUserGroups,
  renderUsersGroups,
);

module.exports = router;
```

## Testing this pattern

```js
// @meli/input-validation and @kraken/static must NOT be mocked — the test exercises
// the real SDK path (mocking them would hide validation bugs).
jest.mock('nordic/ragnar', () => ({ router: jest.fn(() => mockRouter) }));
jest.mock('@root/middlewares/authorizationMiddlewares', () => ({
  authorizeByPermissionKey: jest.fn(() => jest.fn()),
}));
jest.mock('@kraken/static', () => ({ renderErrorView: jest.fn() }));

// Extract the validation middleware (the one just before fetchUserGroups in the chain)
jest.isolateModules(() => { require('@root/app/pages/usersGroup'); });
const routeMiddlewares = mockRouter.get.mock.calls[0];
const fetchIndex = routeMiddlewares.indexOf(mockFetchUserGroups);
const schemaValidationWrapper = routeMiddlewares[fetchIndex - 1];
```

## schemaValidationMiddleware (DO NOT USE FOR NEW ROUTES)

`middlewares/schemaValidationMiddleware.js` is an **AJV-based** wrapper that happens to call
`markSchemaPropertiesAsValidated` from `@meli/input-validation` internally. It exists for legacy routes.
For any new route or refactor, use `@meli/input-validation` directly as shown above.
