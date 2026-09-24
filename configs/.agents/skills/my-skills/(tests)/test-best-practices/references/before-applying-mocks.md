## Before mocking

- List external dependencies (API, hooks, context, storage, timers, feature flags).
- Mock only non-deterministic, slow, or side-effectful dependencies; prefer real implementations for
  pure components.
- If there is doubt about a mock, call out the risk and ask.

## Mock types

### Components

- **Platform components** (`nordic/*`, Andes, internal UI kits and SDKs): never mock them. Render them
  for real and assert observable output.

```ts
render(<ProductCard product={product} />);

expect(screen.getByRole('img', { name: product.title })).toHaveAttribute('src', product.thumbnail);
```

- **Project-own heavy components**: stub them only when they are slow or side-effectful, and keep the
  stub at the project boundary using `data-testid`.

```ts
jest.mock('@/components/ProductCarousel', () => ({
  ProductCarousel: jest.fn(() => <div data-testid="mock-product-carousel" />),
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
