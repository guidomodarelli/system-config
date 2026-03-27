## Assertions

Use `@testing-library/jest-dom` for UI assertions.

### Rules

- Prefer `toStrictEqual` over `toEqual` or `toBe` when comparing objects.
- Avoid `toHaveProperty`; validate the full object shape with `toStrictEqual`.
- Avoid redundant assertions when you already compared the full object.
- Avoid partial comparisons (`toContain`, `toMatch`) if the expected value is known and stable.

### Example

```ts
// Bad
expect(object).toHaveProperty('property');
expect(object.property).toContain('partial text');

// Good
expect(object).toStrictEqual({
  property: 'exact expected value',
});
```
