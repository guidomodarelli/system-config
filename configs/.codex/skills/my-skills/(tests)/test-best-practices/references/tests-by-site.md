# Tests by site with `describe.each`

## Objective

Avoid duplication in tests that depend on per-site translations (`MLA`, `MLB`, `MLM`, etc.).

## Steps

- Extract the values that change between sites (`siteId`, expected texts).
- Define an array of cases and use `describe.each` to iterate over them.
- Create `pxConfig` in `beforeEach` for each case.
- Pass `pxConfig` to `render` or `renderHook`.

## Example

**Before**

```ts
describe('example', () => {
  test('some test', () => {
    render(<MyComponent />, {
      pxConfig: {
        ...global.getPxCcapEnvironment(commons.Channel.NATIVE),
        siteId: commons.Site.MLB,
      },
    });

    expect(screen.getByText('literal value')).toBeInTheDocument();
  });
});
```

**After**

```ts
describe.each([
  {
    siteId: commons.Site.MLB,
    literalValue: 'literal value',
  },
])('example for $siteId', ({ siteId, literalValue }) => {
  let pxConfig;

  beforeEach(() => {
    pxConfig = {
      ...global.getPxCcapEnvironment(commons.Channel.NATIVE),
      siteId,
    };
  });

  test('some test', () => {
    render(<MyComponent />, { pxConfig });

    expect(screen.getByText(literalValue)).toBeInTheDocument();
  });
});
```

## Notes

- Use the extracted values without concatenation or transformations.
- Keep shared literals inside the test.
- Apply `pxConfig` in `renderHook` as well when applicable.
