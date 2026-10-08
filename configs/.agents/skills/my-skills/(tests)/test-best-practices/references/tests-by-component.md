## Objective

Write tests with `jest` using the `@/tests/utils` wrapper, which re-exports common functions from
`@testing-library/react` and `@testing-library/jest-dom`. Importing from the wrapper avoids repeating
configuration and mocks across files.

`render` and `renderHook` already mock `i18n`. If you need to validate per-site texts, pass `pxConfig`
with the corresponding `siteId` when calling `render` or `renderHook`. For example:

```ts
import { render } from '@/tests/utils';
import type { Global } from '@/tests/unit/global';
import { commons } from '@/lib/constants';

declare const global: Global;

render(<MyComponent />, {
  pxConfig: {
    ...global.getPxCcapEnvironment(commons.Channel.NATIVE),
    siteId: commons.Site.MLB,
  },
});
```
