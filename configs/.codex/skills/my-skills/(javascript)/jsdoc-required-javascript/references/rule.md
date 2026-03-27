## Rule: Always add JSDoc to functions/methods and key constructs in .js files

When creating or modifying **any** JavaScript function or method (including exported helpers), you must add or update the JSDoc block immediately above it. Also add JSDoc for classes, module-level constants/variables, and file/module headers when they are created or changed.

### Requirements

- **Scope**: Applies to all `.js` files.
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

### Preferred template

```js
/**
 * <Verb> <what the function does> <optional context>.
 *
 * @param {*} paramName - What this parameter represents, expected format/constraints.
 * @returns {*} What the function returns and what it represents.
 * @throws {Error} When <condition>, including the relevant identifiers in the error message.
 */
```
