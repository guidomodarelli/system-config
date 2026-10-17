## Objective

Write tests with the project's runner (Jest or Vitest) and import render helpers from the project's
test-utils wrapper when one exists (for example `@/tests/utils` or `test/utils`). A wrapper usually
re-exports `@testing-library/react` and `@testing-library/jest-dom` and preconfigures the providers the
app needs (i18n, store, router, theme, feature flags). Importing from it avoids repeating configuration
across files.

If the project has no wrapper and several test files repeat the same providers, propose one instead of
copying setup into each file.

When a test depends on locale, market, or tenant configuration, pass that context through the wrapper's
options rather than mocking the i18n library. For example:

```ts
import { render, screen } from '@/tests/utils';

render(<MyComponent />, {
  locale: 'pt-BR',
  market: 'BR',
});

expect(screen.getByRole('heading', { name: 'Ofertas do dia' })).toBeInTheDocument();
```

Adapt the option names to the wrapper's real API; read it before writing the test.
