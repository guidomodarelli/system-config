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

The fixture tool intercepts Node's `http.request`/`https.request` at the transport level. On the first run it lets the request reach the real API and saves the response as a JSON fixture. Subsequent runs replay the fixture — no network needed, no mocking required.

This means service tests exercise the real service code (URL building, response parsing, error handling) against realistic API responses.

### Setup — directly in the test file

Load fixtures inside the test file. No global config or server-side wiring needed:

```js
// services/__tests__/user.spec.js
import path from 'node:path';
import nock from 'nock';
import { getUser } from '../user';

nock.back.fixtures = path.join(__dirname, 'fixtures');
nock.back.setMode(process.env.CI ? 'lockdown' : 'record');

test('returns user data', async () => {
  const { nockDone } = await nock.back('get-user.json');

  const user = await getUser('1');
  nockDone();

  expect(user.id).toBe(1);
  expect(user.name).toBeDefined();
});
```

Fixture files are auto-created in the fixtures directory on the first run. Commit them to the repo so CI runs without network access.

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
