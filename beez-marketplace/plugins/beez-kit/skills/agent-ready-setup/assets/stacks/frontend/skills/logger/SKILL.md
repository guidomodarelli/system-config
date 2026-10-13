---
name: logger
description: Create a shared logger utility in /utils that wraps the logger library already declared in package.json (installing pino with the project's package manager when none is declared), names it after the project from package.json and exposes logError and logWarning helpers. Use when setting up logging for SSR API handlers or standardizing logger usage across API handlers.
metadata:
  tags: "context-optimized-v1.20.1"
---

# Logger Setup — SSR `/api`

Creates `utils/logger.ts` — a single shared logger instance named after the project, with typed helpers for error and warning logs. Keep this shared utility outside API subrouters.

---

## Step 1 — Check prerequisites

```bash
# Verify package.json exists and has a name field
node -e "const p = require('./package.json'); if (!p.name) throw new Error('Missing name in package.json');"
```

If the command fails, ask the user to add a `name` field to `package.json` before continuing.

---

## Step 2 — Check if logger already exists

```bash
test -f utils/logger.ts && echo "EXISTS" || echo "MISSING"
```

If the file exists, report it and stop:
> "`utils/logger.ts` already exists — skipped."

---

## Step 3 — Detect or install the logger library

`utils/logger.ts` imports a logger package, so that package must be declared before the file is created; otherwise `tsc --noEmit` fails with a missing module. The logger runs in production code, so it counts as available only when it is declared in `dependencies`: a deploy that runs `npm ci --omit=dev` (or the equivalent of the project's package manager) does not install `devDependencies`.

```bash
# Print the first logger library declared in dependencies, "<library> dev-only" when it is only in devDependencies, or NONE
node -e "const p = require('./package.json'); const runtimeDeps = p.dependencies ?? {}; const devDeps = p.devDependencies ?? {}; const known = ['pino', 'winston', 'bunyan', 'log4js', 'loglevel']; const runtimeLibrary = known.find((library) => runtimeDeps[library]); const devOnlyLibrary = known.find((library) => devDeps[library]); console.log(runtimeLibrary ?? (devOnlyLibrary ? devOnlyLibrary + ' dev-only' : 'NONE'));"
```

- If it prints a library name alone, use that library in Step 4 and do not install anything else.
- If it prints `<library> dev-only`, use that library in Step 4, but first move it to `dependencies` with the "Move to runtime" command of the table below. Run the detector again and continue only when it prints the library without `dev-only`.
- If it prints `NONE`, install `pino` as a runtime dependency with the package manager that owns the project's lockfile:

| Lockfile | Install command | Move to runtime (`dev-only`) |
|---|---|---|
| `pnpm-lock.yaml` | `pnpm add pino` | `pnpm add --save-prod <library>` |
| `yarn.lock` | `yarn add pino` | `yarn remove <library> && yarn add <library>` |
| `bun.lockb` or `bun.lock` | `bun add pino` | `bun remove <library> && bun add <library>` |
| `package-lock.json` or no lockfile | `npm install pino` | `npm install --save-prod <library>` |

If more than one lockfile exists, ask the user which package manager the project uses before installing. If the install fails, report the command and its error and stop: do not create `utils/logger.ts` without its dependency.

---

## Step 4 — Create `utils/logger.ts`

```bash
mkdir -p utils
```

Create the file with this content when the library is `pino`:

```ts
import pino from 'pino';
import { name } from '../package.json';

type Tags = Record<string, string | number | boolean | undefined | null>;

const logger = pino({ name });

export const logError = (message: string, tags?: Tags): void => {
  logger.error(tags ?? {}, message);
};

export const logWarning = (message: string, tags?: Tags): void => {
  logger.warn(tags ?? {}, message);
};
```

When Step 3 detected another library, keep the same exported helpers (`logError`, `logWarning`) and the `name` from `package.json`, and replace only the import and the instance with that library's API (for example, `winston.createLogger({ defaultMeta: { service: name } })` or `bunyan.createLogger({ name })`), passing `tags` as the log metadata.

---

## Step 5 — Verify

```bash
tsc --noEmit
npm run lint
```

Fix any errors before reporting success.

---

## Step 6 — Report

Show the created file path and a usage example:

```ts
import { logError, logWarning } from '../../utils/logger';
import { mapKnownErrorToHttpResponse } from '../../src/errors/map-known-error-to-http-response';

try {
  const product = await getProduct(req.params.id);
  res.json(product);
} catch (error) {
  logError(`[PRODUCT-GET] - error: ${error instanceof Error ? error.message : String(error)}`, { productId: req.params.id });
  const publicError = mapKnownErrorToHttpResponse(error);
  res.status(publicError.statusCode).json({ error: publicError.message });
}
```

`mapKnownErrorToHttpResponse` is the project's typed error mapper described in skill `/api-endpoint`; its status mapping follows `../../rules/security.md`, section `Error Handling`.

Convention for the `message` string: `[FEATURE-DASH-SEPARATED] - error: description`.
