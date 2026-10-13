# API Validation Middleware Layout

For REST routes under api/, follow security.md#input-validation for validation behavior and schema scope. Use this rule for module placement and imports.

- Put route-specific schemas from the project's input validation library (for example, zod) and their validation middleware declarations under api/middlewares/validation/, with one module per resource or related route group.
- Export named middleware with names that identify the resource and request part, such as usersQueryValidationMiddleware or feedbackValidationMiddleware.
- Re-export those middleware from api/middlewares/validation/index.js in JavaScript projects or index.ts in TypeScript projects.
- Import middleware from the validation directory barrel, for example ./middlewares/validation; do not import each resource module directly from route files.
- Keep the barrel limited to named re-exports. Do not define schemas, add route logic, or call services in index.js / index.ts.
- Keep route modules responsible for mounting validation, authorization, and handlers. Mount validation before authorization and before any middleware or handler that reads the validated request fields.
- Match each schema to the exact req.query, req.body, or req.params properties consumed by its route. Do not add validation for unrelated routes or backend/upstream response payloads.
- Before writing a resource validation module, search the project for an existing validation middleware factory (for example, `createValidationMiddleware`, `validateRequest`, or an equivalent wrapper around the input validation library) and reuse it with its existing error contract. Never import a helper path that does not exist yet.
- If the project has no such factory, create `utils/validation/index.js` (or `index.ts`) with the implementation below first, then write the resource modules that import it.

Example layout:

~~~text
api/
  index.js
  teams.js
  middlewares/
    validation/
      index.js
      teams.js
~~~

Validation middleware factory (`utils/validation/index.js`, only when the project has none):

~~~js
export const INVALID_REQUEST_ERROR_CODE = 'INVALID_REQUEST';
export const INVALID_REQUEST_STATUS_CODE = 400;
export const INVALID_REQUEST_ERROR_MESSAGE = 'Request validation failed';

const REQUEST_PARTS = ['params', 'query', 'body'];

/**
 * Builds an Express middleware that validates request parts with zod schemas.
 * On success it replaces each validated part with the parsed data; on failure it
 * responds 400 with issue paths and codes only, never echoing input values.
 * @param {{ params?: import('zod').ZodTypeAny, query?: import('zod').ZodTypeAny, body?: import('zod').ZodTypeAny }} schemasByRequestPart
 * @returns {import('express').RequestHandler}
 */
export const createValidationMiddleware = (schemasByRequestPart) => (req, res, next) => {
  const issues = [];
  const parsedDataByRequestPart = {};

  REQUEST_PARTS.forEach((requestPart) => {
    const schema = schemasByRequestPart[requestPart];
    if (!schema) return;

    const parseResult = schema.safeParse(req[requestPart]);
    if (parseResult.success) {
      parsedDataByRequestPart[requestPart] = parseResult.data;
      return;
    }

    parseResult.error.issues.forEach((issue) => {
      issues.push({ path: [requestPart, ...issue.path].join('.'), code: issue.code });
    });
  });

  if (issues.length > 0) {
    return res.status(INVALID_REQUEST_STATUS_CODE).json({
      error: { code: INVALID_REQUEST_ERROR_CODE, message: INVALID_REQUEST_ERROR_MESSAGE, issues },
    });
  }

  Object.entries(parsedDataByRequestPart).forEach(([requestPart, parsedData]) => {
    // Express 5 exposes req.query as a getter, so redefine it instead of assigning.
    Object.defineProperty(req, requestPart, { value: parsedData, writable: true, configurable: true, enumerable: true });
  });

  return next();
};
~~~

Error contract: `400` with `{ error: { code: 'INVALID_REQUEST', message: 'Request validation failed', issues: [{ path, code }] } }`. `path` is the request part plus the zod issue path (for example, `query.teamKey`) and `code` is the zod issue code. Do not include zod `message`, `received`, or the raw input, because some library messages echo submitted values.

Resource validation module:

~~~js
import { z } from 'zod';
import { createValidationMiddleware } from '../../../utils/validation';

export const teamsQueryValidationMiddleware = createValidationMiddleware({
  query: z.object({
    teamKey: z.string().trim().min(1).max(64),
  }),
});
~~~

Barrel:

~~~js
export { teamsQueryValidationMiddleware } from './teams';
~~~

Route import:

~~~js
import { teamsQueryValidationMiddleware } from './middlewares/validation';
~~~
