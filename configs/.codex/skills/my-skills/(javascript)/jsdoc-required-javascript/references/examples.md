## Examples

### File header

```js
/**
 * Provides catalog pricing helpers for the product detail page.
 *
 * @module pricingHelpers
 */
```

### Async function

```js
/**
 * Fetches role details for a given role identifier.
 *
 * @param {string} roleId - Role identifier to fetch (non-empty).
 * @param {object} options - Request options.
 * @param {AbortSignal} [options.signal] - Abort signal used to cancel the request.
 * @returns {Promise<object>} Role details payload.
 * @throws {Error} When the request fails, including the roleId in the error message.
 */
export async function fetchRoleDetails(roleId, { signal } = {}) {
  // ...
}
```

### Function with no meaningful return value

```js
/**
 * Logs an analytics event for a user action.
 *
 * @param {string} eventName - Analytics event name.
 * @param {object} payload - Event metadata.
 * @returns {void} No return value.
 * @throws {Error} When the event payload is invalid.
 */
function trackEvent(eventName, payload) {
  // ...
}
```

### Class

```js
/**
 * Builds and validates checkout totals from line items.
 *
 * @extends BaseTotals
 */
export class CheckoutTotalsBuilder extends BaseTotals {
  /**
   * Initializes the totals builder with line items.
   *
   * @param {Array<object>} items - Line items to aggregate.
   */
  constructor(items) {
    super();
    // ...
  }
}
```

### Constant or variable

```js
/**
 * Default retry delays in milliseconds for pricing API calls.
 *
 * @type {number[]}
 */
export const DEFAULT_RETRY_DELAYS_MS = [100, 250, 500];
```

### Notes

- If a parameter is optional, document it with brackets: `@param {Type} [name] - ...`.
- If a parameter has a default value, mention it in the description.
- For callbacks, document the callback signature (e.g. `{(value: string) => void}`) and describe when it is called.
- If `@throws` does not apply, do not add it.
- Use `@type` for constants/variables when the type or shape is not obvious from the initializer.
- Use `@module <name>` for files that export; use `@file` for scripts without exports.
