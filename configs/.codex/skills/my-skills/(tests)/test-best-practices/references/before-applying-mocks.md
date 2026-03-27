## Before mocking

- List external dependencies (API, hooks, context, storage, timers, feature flags).
- Mock only non-deterministic, slow, or side-effectful dependencies; prefer real implementations for
  pure components.
- If there is doubt about a mock, call out the risk and ask.

## Mock types

### Components

- **Props-only**: reuse the real component to validate props without changing its behavior.

```ts
jest.mock('nordic/image', () => ({
  Image: jest.fn((props) => {
    const { Image } = jest.requireActual<{ Image: typeof NordicImage }>(
      'nordic/image',
    );

    return <Image {...props} />;
  }),
}));
```

- **Behavior**: replace the component with a stub using `data-testid`.

```ts
jest.mock('nordic/image', () => ({
  Image: jest.fn((props) => <div {...props} data-testid="mock-image" />),
}));
```

### Functions

- **Implementation mock**:

```ts
jest.mock('@/utils/webkit/executeNative', () => ({
  executeNative: jest.fn().mockResolvedValue(...),
}));
```

- **Return mock**: use `mockReturnValue` when the value is sync and stable.

## Notes

- Clean shared mocks in `afterEach` if they pollute other tests.
