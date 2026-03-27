---
name: prefer-lodash-defaults
description: Prefer lodash/defaults when lodash is already installed and you need to set default values for function or method option objects (JS/TS). Use for changes involving options/config defaults, fallback values, or object merging where defaults should only apply when properties are undefined.
---

# Prefer Lodash Defaults

## Overview

Prefer lodash's `defaults` helper for applying default values to option/config objects when lodash is already a dependency. Avoid ad-hoc object merging for defaults and keep behavior consistent across functions and methods.

## Guidelines

- Confirm lodash is already installed (existing import or `package.json` dependency). Do not add lodash only for this.
- Use `lodash/defaults` for option objects so defaults only apply when a property is `undefined`.
- Avoid mutating inputs by passing an empty object as the destination.
- Use shallow defaults only; if deep defaults are required, explicitly use `lodash/defaultsDeep` and note the behavior.

## Usage Pattern

Prefer:

```js
import defaults from 'lodash/defaults';

const defaultOptions = {
  page: 1,
  pageSize: 20,
  sort: 'asc',
};

const resolvedOptions = defaults({}, userOptions, defaultOptions);
```

Avoid:

```js
const resolvedOptions = { ...defaultOptions, ...userOptions };
```

## Notes

- `defaults` mutates the first argument; always use `defaults({}, userOptions, defaultOptions)` to keep inputs immutable.
- Keep default objects close to where they are applied to make intent clear and reduce drift.
