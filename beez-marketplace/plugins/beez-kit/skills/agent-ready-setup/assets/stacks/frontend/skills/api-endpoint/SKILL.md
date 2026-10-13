---
name: api-endpoint
description: Create an SSR API endpoint — either a server hook (getServerSideProps) or a REST endpoint in the /api folder using express.Router(). Use when adding a new endpoint, server hook, or API route.
metadata:
  tags: "context-optimized-v1.20.1"
---

# API Endpoint Creation — SSR

> **Prerequisite**: run `/logger` first to generate `utils/logger.ts` — the logging helpers used in the examples below depend on it.
>
> Keep subrouters focused on routing, validation, and orchestration. Put reusable helpers in `utils/` and reusable/domain constants in `constants/`; do not add them inside `api/<resource>/`, `api/services/`, or `services/`. See `../../rules/frontend-style.md`, section `Module placement`.
>
> For the distinction between middleend request validation and backend/upstream response payloads, follow `../../rules/security.md`, section `Input Validation`.
>
> For error-origin and public status mapping, follow `../../rules/security.md`, section `Error Handling`: preserve upstream HTTP statuses, map BFF-owned request/domain failures to 4xx, and use 5xx only for BFF-owned internal or no-status integration failures.
>
> For payloads sent upstream, follow `../../rules/upstream-contracts.md`: map validated input explicitly and let the service build the upstream request.

The project's SSR framework exposes two ways to handle server-side logic:

| Type | Location | Use when |
|---|---|---|
| **Server hook** | `app/pages/<route>/index.hooks.server.ts` (or the framework's equivalent) | Fetching data to render a page (SSR) |
| **REST endpoint** | `api/<resource>/index.ts` → mounted via `express.Router()` | Client-side calls, middle-end JSON APIs |

> **Never call `/api` routes from `getServerSideProps`** — call services directly (no HTTP roundtrip needed).

---

## Option A — Server Hook (`getServerSideProps`)

Consult the SSR framework documentation for the current server hooks API before implementing.

### File placement

Follow the framework's naming convention exactly; when the hooks file is paired with the page file by name, a wrong name means the hooks silently don't run.

```
app/pages/<route>/
├── index.tsx                    ← page component
└── index.hooks.server.ts        ← server-side data + API logic
```

The hooks file runs on the server before the page component renders. If the framework supports Express middlewares that run before `getServerSideProps` (for example, an exported `beforeGetServerSideProps` array), use them for authorization, redirects, request validation, or populating `res.locals`; call services directly from them, never `/api` routes.

```ts
export const beforeGetServerSideProps = [authorizeByPermission(VIEW_PERMISSION), resolvePageProps];
```

### Validate inputs

Use the project's input validation library (for example, zod) — `safeParse()` returns the parsed value or the validation errors without throwing.

```ts
import { z } from 'zod';

const paramsSchema = z.object({
  id: z.string().uuid(),
});

export async function getServerSideProps(req) {
  const parsedParams = paramsSchema.safeParse(req.params);
  if (!parsedParams.success) {
    return { props: { error: true } };
  }
  // ...
}
```

Validate every client-controlled input (body, query params, path params, headers) with an allowlist schema, as required by `../../rules/security.md`, section `Input Validation`.

### Implement the handler

```ts
import { logError } from '../../../utils/logger';
import { getProduct } from '../../../src/services/product';

export async function getServerSideProps(req) {
  const parsedParams = paramsSchema.safeParse(req.params);
  if (!parsedParams.success) {
    return { props: { error: true } };
  }

  const { id: productId } = parsedParams.data;

  try {
    const product = await getProduct(productId);
    return { props: { product } };
  } catch (error) {
    logError(`[PRODUCT-GET-SERVER-SIDE-PROPS] - error: ${error instanceof Error ? error.message : String(error)}`, { productId });
    return { props: { error: true } };
  }
}
```

Rules:
- Never inline business logic or outbound HTTP calls — delegate to a service (skill `/service`), which uses the project's HTTP client.
- Log with `logError`/`logWarning` from `utils/logger` (skill `/logger`) — never `console.log`.
- Never forward `scope` as a query parameter; see `../../rules/api-configuration.md`.

---

## Option B — REST Endpoint (`/api` folder)

The server mounts the `apiRouter` at `/api`. Use the project's validation middleware factory as route middleware so validation and the `400` error response live in one place. Search for an existing factory first and reuse it with its error contract; if none exists, create `utils/validation/index.(js|ts)` with the `createValidationMiddleware` implementation from `../../rules/api-validation-middleware.md` before writing any module that imports it.

Keep REST route schemas and middleware in `api/middlewares/validation/<resource>.(js|ts)`, then import their named exports from `api/middlewares/validation/index.js` or `index.ts`. See `../../rules/api-validation-middleware.md`.

### File placement

```
api/
├── index.ts                            ← mounts all resource routers
├── middlewares/
│   └── validation/
│       ├── index.ts                    ← re-exports route validation middleware
│       └── product.ts                  ← product request schemas and middleware
└── product/
    └── index.ts                        ← product router
```

### 1. Create the resource router

> Para implementar `getProduct`, `createProduct` y cualquier servicio que el handler consuma, seguí el skill `/service`.

```ts
// api/product/index.ts
import { Router } from 'express';
import {
  createProductValidationMiddleware,
  getProductValidationMiddleware,
} from '../middlewares/validation';
import { logError } from '../../utils/logger';
import { mapKnownErrorToHttpResponse } from '../../src/errors/map-known-error-to-http-response';
import { getProduct, createProduct } from '../../src/services/product';

const router = Router();

router.get('/product/:id', getProductValidationMiddleware, async (req, res) => {
  try {
    const product = await getProduct(req.params.id);
    res.json(product);
  } catch (error) {
    logError(`[PRODUCT-GET] - error: ${error instanceof Error ? error.message : String(error)}`, { productId: req.params.id });
    const publicError = mapKnownErrorToHttpResponse(error);
    return res.status(publicError.statusCode).json({ error: publicError.message });
  }
});

router.post('/product', createProductValidationMiddleware, async (req, res) => {
  const { name, price } = req.body;

  try {
    const product = await createProduct({ name, price });
    res.status(201).json(product);
  } catch (error) {
    logError(`[PRODUCT-CREATE] - error: ${error instanceof Error ? error.message : String(error)}`);
    const publicError = mapKnownErrorToHttpResponse(error);
    return res.status(publicError.statusCode).json({ error: publicError.message });
  }
});

export default router;
```

`mapKnownErrorToHttpResponse` is the project's typed error mapper and must follow the error-origin policy linked at the top of this skill. If the project uses a different module path, update the import before copying the example; do not leave the mapper as an implicit dependency.

The handler maps the validated body explicitly instead of forwarding `req.body`, so client-only fields never reach the service or the upstream request.

### 2. Mount in `api/index.ts`

```ts
import { Router } from 'express';
import productRouter from './product';

const apiRouter = Router();

apiRouter.use(productRouter);

export default apiRouter;
```

Rules:
- Define the validation middleware in `api/middlewares/validation/<resource>.(js|ts)` and mount its named export as the first route middleware — never access `req.body/params/query` without prior validation.
- Never import `createValidationMiddleware` (or any validation helper) from a path that does not exist: reuse the project's factory or create it first.
- For path/query params (always strings), coerce non-string types in the schema (for example, `z.coerce.number()`); for booleans, parse the allowed string values explicitly instead of relying on truthiness.
- Never inline business logic — delegate to a service.
- Never disable CSRF protection without a formal security review.
- Everything else (allowlists, PII in logs, error details, status mapping) follows `../../rules/security.md`.

---

## Verify

```bash
tsc --noEmit
npm run lint
```
