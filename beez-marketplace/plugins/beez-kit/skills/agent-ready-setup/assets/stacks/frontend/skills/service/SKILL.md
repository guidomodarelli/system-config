---
name: service
description: Create a service layer for external API calls in an SSR app. Use when adding a new service, API client, or data-fetching layer.
metadata:
  tags: "context-optimized-v1.20.1"
---

# Service Creation — Frontend (SSR)

Guide for creating a service — the layer that encapsulates all external API calls and business logic. Server hooks and components delegate to services; they never call APIs directly.

---

## Step 1 — Decide where the service lives

```
src/services/<domain>/
├── index.ts                     ← public API of the service
└── __tests__/
    └── <domain>.spec.ts
```

Group by domain (`user`, `shipping`, `payment`) — not by technical type (`api`, `fetch`).

---

## Step 2 — Detect or install the service dependencies

The service imports an HTTP client and a config module, and its test imports an HTTP mocking library, so those packages must be declared before the files are created; otherwise `tsc --noEmit` fails with a missing module. The HTTP client and the config module are imported from production code, so they count as available only when they are declared in `dependencies`: a deploy that runs `npm ci --omit=dev` (or the equivalent of the project's package manager) does not install `devDependencies`. Only the HTTP mocking library may come from either section.

```bash
# Print the first HTTP client and config module declared in dependencies (or "<library> dev-only" when it is only in devDependencies) and the first HTTP mocking library declared in either section, or NONE for each
node -e "const p = require('./package.json'); const runtimeDeps = p.dependencies ?? {}; const devDeps = p.devDependencies ?? {}; const findRuntime = (known) => { const runtimeLibrary = known.find((library) => runtimeDeps[library]); if (runtimeLibrary) return runtimeLibrary; const devOnlyLibrary = known.find((library) => devDeps[library]); return devOnlyLibrary ? devOnlyLibrary + ' dev-only' : 'NONE'; }; const findAny = (known) => known.find((library) => runtimeDeps[library] || devDeps[library]) ?? 'NONE'; console.log('http-client=' + findRuntime(['axios', 'ky', 'got', 'undici', 'node-fetch'])); console.log('config-module=' + findRuntime(['config', 'convict', 'dotenv'])); console.log('http-mock=' + findAny(['nock', 'msw']));"
```

Resolve each line independently:

- `http-client`: if it prints a library, use it in Steps 3 and 4 and adapt the import and the instance creation to that library (for example, `ky.create({ prefixUrl, timeout })` or `got.extend({ prefixUrl, timeout })`). If it prints `NONE` but the project already wraps native `fetch` in its own client module (look under `src/`, `utils/` and `services/` for a shared function that calls `fetch`), import that wrapper instead; if that wrapper imports `fetch` or `request` from `undici`, treat the client as `undici`. Only when neither exists, install `axios`.
- `config-module`: if it prints `config` or `convict`, read the base URL through that module. If it prints `dotenv`, or `NONE` but the project has its own config module (for example, `src/config/index.ts`), import that module instead of `config`. Only when neither exists, install `config` and `@types/config`, and add the `services.<domain>.baseUrl` key to the existing files under `config/` (create `config/default.js` only if the directory has no environment files).
- `<library> dev-only` (either runtime line): the project already chose that library but declares it only in `devDependencies`. Use it as if it were printed alone, and move it to `dependencies` with the "Move to runtime" command of the table below before creating the service. Run the detector again and continue only when it prints the library without `dev-only`.
- `http-mock`: when the HTTP client is `undici`, ignore this line and do not install `nock`: Nock 14 does not intercept requests made with `undici.request` or `undici.fetch` (https://github.com/nock/nock/issues/2183; Nock 15 does, but it ships as ESM only), so with Nock 14 `lockdown` would neither replay the fixture nor block the network. Write the Step 5 scenarios with undici's `MockAgent` instead (see Step 5, "HTTP client `undici`"). For any other client, if it prints `msw`, write the Step 5 scenarios with the project's `msw` server and handlers instead of `nock.back`, keeping the same lockdown and sanitization guarantees. If it prints `NONE`, install `nock` as a dev dependency.

`axios` and `nock` ship their own type definitions; `config` needs `@types/config`. Install only the missing packages with the package manager that owns the project's lockfile, keeping `nock` and `@types/config` as dev dependencies:

| Lockfile | Runtime install | Dev install | Move to runtime (`dev-only`) |
|---|---|---|---|
| `pnpm-lock.yaml` | `pnpm add axios config` | `pnpm add -D nock @types/config` | `pnpm add --save-prod <library>` |
| `yarn.lock` | `yarn add axios config` | `yarn add -D nock @types/config` | `yarn remove <library> && yarn add <library>` |
| `bun.lockb` or `bun.lock` | `bun add axios config` | `bun add -d nock @types/config` | `bun remove <library> && bun add <library>` |
| `package-lock.json` or no lockfile | `npm install axios config` | `npm install -D nock @types/config` | `npm install --save-prod <library>` |

Drop from each command the packages that are already declared or that you are replacing with an existing library, and drop `nock` when the HTTP client is `undici`. If more than one lockfile exists, ask the user which package manager the project uses before installing. If an install fails, report the command and its error and stop: do not create the service or its test without their dependencies.

---

## Step 3 — Set up the HTTP client

Always use the project's HTTP client (for example, one `axios` instance per service) for external HTTP calls. Never call `fetch` or `http.request` directly; a native `fetch` call is only allowed inside the project's own client wrapper detected in Step 2.

```ts
import axios from 'axios';
import config from 'config';
import { RESOURCE_REQUEST_TIMEOUT_MS } from '../../constants/resource';

const client = axios.create({
  baseURL: config.get<string>('services.resource.baseUrl'),
  timeout: RESOURCE_REQUEST_TIMEOUT_MS,
});
```

Rules:
- Read base URLs and scopes from the environment files under `config/` through the project's config module, as required by `../../rules/api-configuration.md`. Only credentials come from the project's secrets manager.
- Never pass user-controlled input directly as the base URL or path — validate against a static allowlist.
- With `undici`, call `request` (or `fetch`) from `undici` through the global dispatcher and set the timeout per request (`headersTimeout`/`bodyTimeout` in `request`, `signal: AbortSignal.timeout(...)` in `fetch`); do not create a dedicated `Pool`, `Client` or `Agent` in the service, because the Step 5 `MockAgent` only replaces the global dispatcher.

---

## Step 4 — Implement the service functions

```ts
// Continue in the same index.ts file and reuse the client declared in Step 3.

export async function getResource(id: string): Promise<Resource> {
  // id must be validated by the caller before reaching here
  const response = await client.get<Resource>(`/resources/${id}`);
  return response.data;
}

interface CreateResourceUpstreamRequest {
  resource_name: string;
  unit_price: number;
}

// Owns the upstream field names so client input shapes never leak upstream.
function buildCreateResourceUpstreamRequest(input: CreateResourceInput): CreateResourceUpstreamRequest {
  return {
    resource_name: input.name,
    unit_price: input.price,
  };
}

export async function createResource(input: CreateResourceInput): Promise<Resource> {
  const response = await client.post<Resource>('/resources', buildCreateResourceUpstreamRequest(input));
  return response.data;
}
```

Rules:
- Services do not validate inputs — that is the responsibility of the server hook or handler.
- Build every upstream request body with a named builder per operation (`build<Operation>UpstreamRequest`); never send the handler input as-is. See `../../rules/upstream-contracts.md`.
- Services let errors propagate — no try/catch here unless translating error types.
- Never expose internal error details — catch at the handler level.
- Never log inside a service — logging happens in the handler via `logError`/`logWarning` from `utils/logger.ts` (see skill `/logger`).
- Keep reusable helpers and domain/configuration constants out of service modules; place them in `utils/` and `constants/` respectively. See `../../rules/frontend-style.md`, section `Module placement`.
- Parallelize independent calls with `Promise.all()`.

---

## Step 5 — Write the test

```ts
import path from 'node:path';
import nock from 'nock';
import { getResource } from '../index';

const RECORD_FIXTURES_ENV_VAR = 'NOCK_BACK_RECORD';
const REDACTED_VALUE = '[REDACTED]';
const SENSITIVE_FIELD_NAMES = ['email', 'phone', 'document', 'token'];
const URL_ENCODED_PAYLOAD_PATTERN = /^[^=&\s]+=[^&\s]*(?:&[^=&\s]+=[^&\s]*)*$/;

const isRecordingFixtures = process.env[RECORD_FIXTURES_ENV_VAR] === 'true' && !process.env.CI;

nock.back.fixtures = path.join(__dirname, 'fixtures');
nock.back.setMode(isRecordingFixtures ? 'record' : 'lockdown');

const redactSensitiveFields = <Value,>(value: Value): Value => {
  if (Array.isArray(value)) return value.map(redactSensitiveFields) as Value;
  if (typeof value !== 'object' || value === null) return value;
  return Object.fromEntries(
    Object.entries(value).map(([fieldName, fieldValue]) => [
      fieldName,
      SENSITIVE_FIELD_NAMES.includes(fieldName) ? REDACTED_VALUE : redactSensitiveFields(fieldValue),
    ]),
  ) as Value;
};

const redactSensitiveSearchParams = (encodedParams: string): string => {
  const searchParams = new URLSearchParams(encodedParams);
  [...new Set(searchParams.keys())]
    .filter((paramName) => SENSITIVE_FIELD_NAMES.includes(paramName))
    .forEach((paramName) => searchParams.set(paramName, REDACTED_VALUE));
  return searchParams.toString();
};

const redactSensitiveQueryParams = (recordedPath: string): string => {
  const queryStartIndex = recordedPath.indexOf('?');
  if (queryStartIndex === -1) return recordedPath;
  const redactedQuery = redactSensitiveSearchParams(recordedPath.slice(queryStartIndex + 1));
  return `${recordedPath.slice(0, queryStartIndex)}?${redactedQuery}`;
};

const parseJsonContainer = (recordedText: string): object | undefined => {
  try {
    const parsedValue: unknown = JSON.parse(recordedText);
    return typeof parsedValue === 'object' && parsedValue !== null ? parsedValue : undefined;
  } catch {
    return undefined;
  }
};

// Nock keeps as a string every body it cannot parse as JSON (form-urlencoded, plain text, XML...).
const sanitizeRecordedPayload = (recordedPayload: unknown, payloadLabel: string): unknown => {
  if (typeof recordedPayload !== 'string' || recordedPayload === '') return redactSensitiveFields(recordedPayload);
  const parsedJson = parseJsonContainer(recordedPayload);
  if (parsedJson !== undefined) return JSON.stringify(redactSensitiveFields(parsedJson));
  if (URL_ENCODED_PAYLOAD_PATTERN.test(recordedPayload)) return redactSensitiveSearchParams(recordedPayload);
  throw new Error(
    `sanitizeRecordedDefinitions: refusing to persist the ${payloadLabel} because it is a text payload that is neither JSON nor form-urlencoded and cannot be sanitized; write this fixture by hand from test data or add a sanitizer for its content type.`,
  );
};

const sanitizeRecordedDefinitions = (definitions: nock.Definition[]): nock.Definition[] =>
  definitions.map(({ rawHeaders, reqheaders, ...definition }) => {
    const redactedPath = redactSensitiveQueryParams(definition.path);
    const definitionLabel = `${definition.method ?? 'GET'} ${definition.scope}${redactedPath}`;
    return {
      ...definition,
      path: redactedPath,
      body: sanitizeRecordedPayload(definition.body, `request body of ${definitionLabel}`),
      response: sanitizeRecordedPayload(definition.response, `response of ${definitionLabel}`),
    } as nock.Definition;
  });

describe('getResource', () => {
  it('returns the resource when the API responds successfully', async () => {
    const { nockDone } = await nock.back('get-resource.json', {
      afterRecord: sanitizeRecordedDefinitions,
    });

    const result = await getResource('1');
    nockDone();

    expect(result.id).toBe('1');
    expect(result.name).toBeDefined();
  });
});
```

Usá fixtures del interceptor HTTP del proyecto (por ejemplo, `nock.back`) para escenarios de error, en lugar de mockear el cliente HTTP. Para `createResource`, cubrí el mapeo de `buildCreateResourceUpstreamRequest` verificando el request enviado con el mecanismo de intercepción HTTP del proyecto que permita inspeccionarlo (ver `../../rules/upstream-contracts.md`, sección `Tests`). El modo por defecto (y siempre en CI) es `lockdown`: el test solo reproduce fixtures existentes y cualquier request sin fixture falla sin llegar a la red. Grabar un fixture es una acción explícita: corré el test con `NOCK_BACK_RECORD=true`, fuera de CI y contra un entorno o cuenta con datos de prueba, nunca contra datos reales de usuarios. `afterRecord` descarta `rawHeaders` y `reqheaders` (cookies, `authorization`, `set-cookie`, correlation ids) y redacta identificadores y PII del body, de la respuesta y de los query params de `path` (Nock graba ahí la ruta con su query string) antes de persistir. Nock guarda como string todo body o respuesta que no puede parsear como JSON: `sanitizeRecordedPayload` redacta esos strings cuando son JSON o `application/x-www-form-urlencoded` y, ante cualquier otro texto no vacío (texto plano, XML, payload binario), lanza un error que aborta la grabación indicando método, origin y path redactado; en ese caso armá el fixture a mano con datos de prueba o agregá un sanitizer para ese content type. Ajustá `SENSITIVE_FIELD_NAMES` al contrato del upstream. Los segmentos de ruta (por ejemplo, `/users/{id}`) no se redactan: si llevan identificadores, grabá solo contra datos de prueba. Revisá el JSON generado antes de commitearlo y commitealo solo si no contiene secretos, tokens, cookies ni datos personales, para que CI ejecute el test sin red.

### HTTP client `undici`

Cuando el cliente HTTP es `undici` (directo o a través del wrapper de `fetch` del proyecto), no uses `nock` ni `msw`: reemplazá el dispatcher global por un `MockAgent` de `undici`, bloqueá la red con `disableNetConnect()` y reproducí fixtures JSON propios guardados en `__tests__/fixtures/`. Cada fixture lista las interacciones con `origin`, `method`, `path`, `status` y `response`, y se arma a mano o desde respuestas de un entorno o cuenta con datos de prueba, aplicando la misma redacción de headers, PII y query params descrita arriba antes de commitearlo.

```ts
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { MockAgent, getGlobalDispatcher, setGlobalDispatcher, type Dispatcher } from 'undici';
import { getResource } from '../index';

interface FixtureInteraction {
  origin: string;
  method: string;
  path: string;
  status: number;
  response: unknown;
}

const FIXTURES_DIRECTORY = path.join(__dirname, 'fixtures');
const JSON_RESPONSE_HEADERS = { 'content-type': 'application/json' };

let originalDispatcher: Dispatcher;
let mockAgent: MockAgent;

const replayFixture = (fixtureFileName: string): void => {
  const interactions: FixtureInteraction[] = JSON.parse(
    readFileSync(path.join(FIXTURES_DIRECTORY, fixtureFileName), 'utf8'),
  );
  interactions.forEach(({ origin, method, path: requestPath, status, response }) => {
    mockAgent
      .get(origin)
      .intercept({ method, path: requestPath })
      .reply(status, response, { headers: JSON_RESPONSE_HEADERS });
  });
};

beforeEach(() => {
  originalDispatcher = getGlobalDispatcher();
  mockAgent = new MockAgent();
  mockAgent.disableNetConnect();
  setGlobalDispatcher(mockAgent);
});

afterEach(async () => {
  try {
    mockAgent.assertNoPendingInterceptors();
  } finally {
    setGlobalDispatcher(originalDispatcher);
    await mockAgent.close();
  }
});

describe('getResource', () => {
  it('returns the resource when the API responds successfully', async () => {
    replayFixture('get-resource.json');

    const result = await getResource('1');

    expect(result.id).toBe('1');
    expect(result.name).toBeDefined();
  });
});
```

Cualquier request sin interceptor falla con `MockNotMatchedError` sin llegar a la red, y `assertNoPendingInterceptors()` falla si el service no consumió todas las interacciones del fixture; el `finally` restaura el dispatcher global y cierra el `MockAgent` aunque esa aserción falle, para no contaminar los tests siguientes, y el error de la aserción se sigue propagando. Para verificar el body enviado por `createResource`, pasá una función como `body` de `intercept` que compare el JSON recibido con el resultado esperado de `buildCreateResourceUpstreamRequest`.

---

## Step 6 — Verify

```bash
tsc --noEmit
npm run lint
npm test
```
