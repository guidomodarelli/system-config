# Nordic Logger Examples (rampup-guido-modarelli)

## API route error logging

Source: `api/products.ts`

```ts
import { LoggerFactory } from 'nordic/logger';

const logger = LoggerFactory('products');

logger.error('products:getProducts failed', {
  endpoint: req.originalUrl,
  method: req.method,
  status,
  siteId,
  limit,
  offset,
});
```

## Middleware error logging

Source: `api/middlewares/validateProductsQuery.ts`

```ts
import { LoggerFactory } from 'nordic/logger';

const logger = LoggerFactory('products');

logger.error('validateProductsQuery: failed to parse query params', {
  endpoint: req.originalUrl,
  method: req.method,
});
```
