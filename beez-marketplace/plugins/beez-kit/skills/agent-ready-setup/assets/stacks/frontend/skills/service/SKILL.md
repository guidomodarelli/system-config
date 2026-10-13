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

## Step 2 — Set up the HTTP client

Always use the project's HTTP client (for example, one `axios` instance per service) for external HTTP calls. Never call `fetch` or `http.request` directly.

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

---

## Step 3 — Implement the service functions

```ts
// Continue in the same index.ts file and reuse the client declared in Step 2.

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

## Step 4 — Write the test

```ts
import path from 'node:path';
import nock from 'nock';
import { getResource } from '../index';

const RECORD_FIXTURES_ENV_VAR = 'NOCK_BACK_RECORD';
const REDACTED_VALUE = '[REDACTED]';
const SENSITIVE_FIELD_NAMES = ['email', 'phone', 'document', 'token'];

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

const sanitizeRecordedDefinitions = (definitions: nock.Definition[]): nock.Definition[] =>
  definitions.map(({ rawHeaders, reqheaders, ...definition }) => ({
    ...definition,
    body: redactSensitiveFields(definition.body),
    response: redactSensitiveFields(definition.response),
  }));

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

Usá fixtures del interceptor HTTP del proyecto (por ejemplo, `nock.back`) para escenarios de error, en lugar de mockear el cliente HTTP. Para `createResource`, cubrí el mapeo de `buildCreateResourceUpstreamRequest` verificando el request enviado con el mecanismo de intercepción HTTP del proyecto que permita inspeccionarlo (ver `../../rules/upstream-contracts.md`, sección `Tests`). El modo por defecto (y siempre en CI) es `lockdown`: el test solo reproduce fixtures existentes y cualquier request sin fixture falla sin llegar a la red. Grabar un fixture es una acción explícita: corré el test con `NOCK_BACK_RECORD=true`, fuera de CI y contra un entorno o cuenta con datos de prueba, nunca contra datos reales de usuarios. `afterRecord` descarta `rawHeaders` y `reqheaders` (cookies, `authorization`, `set-cookie`, correlation ids) y redacta identificadores y PII del body y la respuesta antes de persistir; ajustá `SENSITIVE_FIELD_NAMES` al contrato del upstream. Revisá el JSON generado antes de commitearlo y commitealo solo si no contiene secretos, tokens, cookies ni datos personales, para que CI ejecute el test sin red.

---

## Step 5 — Verify

```bash
tsc --noEmit
npm run lint
npm test
```
