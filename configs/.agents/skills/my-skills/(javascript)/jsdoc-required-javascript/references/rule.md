## Rule: Always add JSDoc/TSDoc to functions/methods and key constructs

When creating or modifying **any** JavaScript or TypeScript function or method (including exported helpers), you must add or update the documentation block immediately above it. Also add documentation for classes, module-level constants/variables, and file/module headers when they are created or changed.

- For `.js` files, use **JSDoc** (`/** ... */`).
- For `.ts` and `.tsx` files, use **TSDoc** (`/** ... */` with TSDoc tags).

### Requirements

- **Scope**: Applies to all `.js`, `.ts`, and `.tsx` files.
- **Placement**: The JSDoc block must be immediately above the item it documents. File/module JSDoc goes at the top of the file, before imports (after `'use strict'` if present).
- **Language**: All JSDoc text must be **English**.
- **Must document**:
  - Function declarations (`function name() {}`)
  - Function expressions (`const x = function () {}`)
  - Arrow functions (`const x = () => {}`)
  - Object methods (`const o = { method() {} }`)
  - Class methods (including `static` and `async`)
  - Exported functions and module-level helpers
  - Class declarations (document purpose and context)
  - Module/file headers for every new or modified file; include exports, side effects, or non-obvious domain intent
  - Exported constants/variables, module-level constants/variables, configuration objects, complex data shapes, regexes, and values with non-obvious meaning/units/constraints
- **Minimum content**:
  - **Functions/methods**:
    - One-line summary that starts with a verb (e.g. "Fetches…", "Builds…", "Validates…").
    - `@param` for **every** parameter, with a clear description. Add a type when it is clear/important.
    - `@returns` with a description. Add a type when it is clear/important.
    - `@throws` for meaningful error conditions; include the identifiers that make the error actionable.
  - **Classes**:
    - One-line summary that starts with a verb and explains the role.
    - `@extends` when it subclasses another type.
    - Document constructor params on the constructor JSDoc (constructor is treated as a method).
  - **Constants/variables**:
    - One-line summary that explains the intent or meaning.
    - `@type` when the type or shape is not obvious from the initializer.
    - Note units, constraints, or special formats in the description.
  - **File/module headers**:
    - One-line summary of what the file provides.
    - `@module <name>` for exported modules; use `@file` for scripts without exports.
- **Keep in sync**: If the signature or behavior changes, update the JSDoc in the same change.
 - **Add extra JSDoc when helpful**: Prefer adding JSDoc to complex objects, configuration literals, and non-obvious domain logic to reduce reader guesswork.

### Preferred template (JSDoc)

```js
/**
 * <Verb> <what the function does> <optional context>.
 *
 * @param {*} paramName - What this parameter represents, expected format/constraints.
 * @returns {*} What the function returns and what it represents.
 * @throws {Error} When <condition>, including the relevant identifiers in the error message.
 */
```

### Preferred template (TSDoc)

```ts
/**
 * <Verb> <what the function does> <optional context>.
 *
 * @param paramName - What this parameter represents, expected format/constraints.
 * @returns What the function returns and what it represents.
 * @throws When <condition>, including the relevant identifiers in the error message.
 */
```

### TSDoc-specific notes

- Do not include type annotations in `@param` or `@returns` tags; TypeScript types are the source of truth.
- Use `@typeParam` for generic type parameter descriptions (for example `@typeParam T - The entity type returned by the query.`).
- Use `@remarks` for extended explanations that go beyond the summary line.
- Use `@example` with fenced code blocks when a usage example clarifies intent.
- Use `@defaultValue` to document default values of optional parameters or properties.
- Use `@override` and `@virtual` when relevant in class hierarchies.
- Use `@internal` for implementation details not intended for external consumers.
