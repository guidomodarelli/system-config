# Mocking Strategy — Frontend Tests vs Service Tests

Tests are split into two contexts with different mocking strategies. Apply the rules for the context you are in.

---

## Context 1: Frontend / Component Tests

Tests for React components, pages, and UI logic.

**Strategy: mock internal services; use the default test providers of the project; never mock the component libraries or platform packages listed in `testing.md`.**

### Mock the services the component depends on

Components call services to fetch data. Those services must be mocked so the test controls what the component receives:

```js
// app/ui-components/user-card/__tests__/user-card.spec.jsx
import { render, screen } from '@testing-library/react';
import { TestProviders } from '../../../../tests/utils/test-providers';

import { UserCard } from '../index';
import * as userService from '../../../../src/services/user';

jest.spyOn(userService, 'getUser').mockResolvedValue({ id: 1, name: 'Ada' });

test('shows user name', async () => {
  render(
    <TestProviders>
      <UserCard userId="1" />
    </TestProviders>,
  );

  expect(await screen.findByText('Ada')).toBeInTheDocument();
});
```

---

## Context 2: Service Tests

Tests for service functions that call external APIs through the project's HTTP client.

**Strategy: no mocks — let the service make real HTTP calls intercepted by an HTTP record/replay fixture tool (for example, `nock` with `nock.back`).**

### How it works

The fixture tool intercepts Node's `http.request`/`https.request` at the transport level. By default (and always in CI) it runs in `lockdown` mode: it only replays committed JSON fixtures and any request without a fixture fails without reaching the network — no network needed, no mocking required. Recording a fixture is an explicit opt-in action against test data, never a side effect of a first local run.

This means service tests exercise the real service code (URL building, response parsing, error handling) against realistic API responses.

### Setup — directly in the test file

Load fixtures inside the test file. No global config or server-side wiring needed:

```js
// services/__tests__/user.spec.js
import path from 'node:path';
import nock from 'nock';
import { getUser } from '../user';

const RECORD_FIXTURES_ENV_VAR = 'NOCK_BACK_RECORD';
const REDACTED_VALUE = '[REDACTED]';
const SENSITIVE_FIELD_NAMES = ['email', 'phone', 'document', 'token'];
const URL_ENCODED_PAYLOAD_PATTERN = /^[^=&\s]+=[^&\s]*(?:&[^=&\s]+=[^&\s]*)*$/;

const isRecordingFixtures = process.env[RECORD_FIXTURES_ENV_VAR] === 'true' && !process.env.CI;

nock.back.fixtures = path.join(__dirname, 'fixtures');
nock.back.setMode(isRecordingFixtures ? 'record' : 'lockdown');

const redactSensitiveFields = (value) => {
  if (Array.isArray(value)) return value.map(redactSensitiveFields);
  if (typeof value !== 'object' || value === null) return value;
  return Object.fromEntries(
    Object.entries(value).map(([fieldName, fieldValue]) => [
      fieldName,
      SENSITIVE_FIELD_NAMES.includes(fieldName) ? REDACTED_VALUE : redactSensitiveFields(fieldValue),
    ]),
  );
};

const redactSensitiveSearchParams = (encodedParams) => {
  const searchParams = new URLSearchParams(encodedParams);
  [...new Set(searchParams.keys())]
    .filter((paramName) => SENSITIVE_FIELD_NAMES.includes(paramName))
    .forEach((paramName) => searchParams.set(paramName, REDACTED_VALUE));
  return searchParams.toString();
};

const redactSensitiveQueryParams = (recordedPath) => {
  const queryStartIndex = recordedPath.indexOf('?');
  if (queryStartIndex === -1) return recordedPath;
  const redactedQuery = redactSensitiveSearchParams(recordedPath.slice(queryStartIndex + 1));
  return `${recordedPath.slice(0, queryStartIndex)}?${redactedQuery}`;
};

const parseJsonContainer = (recordedText) => {
  try {
    const parsedValue = JSON.parse(recordedText);
    return typeof parsedValue === 'object' && parsedValue !== null ? parsedValue : undefined;
  } catch {
    return undefined;
  }
};

// Nock keeps as a string every body it cannot parse as JSON (form-urlencoded, plain text, XML...).
const sanitizeRecordedPayload = (recordedPayload, payloadLabel) => {
  if (typeof recordedPayload !== 'string' || recordedPayload === '') return redactSensitiveFields(recordedPayload);
  const parsedJson = parseJsonContainer(recordedPayload);
  if (parsedJson !== undefined) return JSON.stringify(redactSensitiveFields(parsedJson));
  if (URL_ENCODED_PAYLOAD_PATTERN.test(recordedPayload)) return redactSensitiveSearchParams(recordedPayload);
  throw new Error(
    `sanitizeRecordedDefinitions: refusing to persist the ${payloadLabel} because it is a text payload that is neither JSON nor form-urlencoded and cannot be sanitized; write this fixture by hand from test data or add a sanitizer for its content type.`,
  );
};

const sanitizeRecordedDefinitions = (definitions) =>
  definitions.map(({ rawHeaders, reqheaders, ...definition }) => {
    const redactedPath = redactSensitiveQueryParams(definition.path);
    const definitionLabel = `${definition.method ?? 'GET'} ${definition.scope}${redactedPath}`;
    return {
      ...definition,
      path: redactedPath,
      body: sanitizeRecordedPayload(definition.body, `request body of ${definitionLabel}`),
      response: sanitizeRecordedPayload(definition.response, `response of ${definitionLabel}`),
    };
  });

test('returns user data', async () => {
  const { nockDone } = await nock.back('get-user.json', {
    afterRecord: sanitizeRecordedDefinitions,
  });

  const user = await getUser('1');
  nockDone();

  expect(user.id).toBe(1);
  expect(user.name).toBeDefined();
});
```

To record or refresh a fixture, run the test explicitly with `NOCK_BACK_RECORD=true`, outside CI and against an environment or account that only holds test data — never real user data. `afterRecord` drops `rawHeaders` and `reqheaders` (cookies, `authorization`, `set-cookie`, correlation ids) and redacts identifiers and PII from the request body, the response and the query params of `path` (Nock records the route there, query string included) before the fixture is persisted. Nock keeps as a string every body or response it cannot parse as JSON: `sanitizeRecordedPayload` redacts those strings when they are JSON or `application/x-www-form-urlencoded`, and for any other non-empty text (plain text, XML, binary payloads) it throws an error that aborts the recording and names the method, origin and redacted path; in that case write the fixture by hand from test data or add a sanitizer for that content type. Adjust `SENSITIVE_FIELD_NAMES` to the upstream contract. Path segments (for example `/users/{id}`) are not redacted: when they carry identifiers, record only against test data. Review the generated JSON before committing it, and commit it only when it contains no secrets, tokens, cookies or personal data, so CI runs without network access.

### When service mocks are acceptable

Only mock a service dependency when:

- The dependency is **another internal service** (not an HTTP call) with side effects that would break test isolation (e.g., a service that writes to a queue or triggers a notification).
- The test needs to assert behavior under a **specific error condition** that cannot be represented as a fixture file (for example, a transport failure without an HTTP response). HTTP error statuses such as 500 or 404 are always covered with a fixture file.

### Creating error scenario fixtures manually

Instead of mocking, create the fixture JSON for the error case:

```json
// services/__tests__/fixtures/get-user-not-found.json
[
  {
    "scope": "https://api.example.com:443",
    "method": "GET",
    "path": "/users/not-found",
    "status": 404,
    "response": { "message": "User not found", "error": "not_found" },
    "rawHeaders": ["content-type", "application/json"]
  }
]
```

---

## Quick Reference

| Test type | Mock services? | Mock framework contexts? | Mock HTTP? |
|-----------|----------------|----------------------|------------|
| Component / UI | Yes — `jest.spyOn` on services | No | Never directly |
| Service | No | No | Never — use HTTP record/replay fixtures |

---

## References

- `nock` — HTTP interceptor with record/replay fixtures (`nock.back`) for service tests, or the equivalent tool used by the project
