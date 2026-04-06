---
name: enforce-naming-conventions
description: Enforces clear, coherent, concise, complete, and self-explanatory naming for variables, functions, methods, classes, enums, types, interfaces, constants, files, and folders, including arrow function parameters. Avoids single-letter identifiers (with limited loop and math exceptions), abbreviations, and terse names. Use when naming conventions, refactors, or code reviews are in scope.
---

# Enforce Naming Conventions

## Quick start

- Every name must be **clear**, **coherent** across the codebase, **concise** (as short as possible without losing meaning), **complete** (unambiguous without requiring comments), and **self-explanatory**.
- Apply these qualities to variables, functions, methods, classes, enums, types, interfaces, constants, files, and folders.
- Use descriptive names in arrow function parameters; never use single-letter names like `(x) => x.id` outside math contexts.
- Avoid single-letter variable names except conventional loop counters (`i`, `j`, `k`) and mathematical variables (`x`, `y`, `z`) in math contexts.
- Use `error` or a descriptive variant (for example `caughtError`, `dbError`) in `catch (...)` blocks; never use `e`.
- Avoid abbreviations or terse names; prefer the full word unless the abbreviation is universally understood in the domain (for example `id`, `url`, `api`).
- Keep names consistent: if the codebase calls it `user`, do not introduce `usr`, `u`, or `cliente` elsewhere for the same concept.
- Use common folder names where applicable (`utils/`, `services/`, `components/`, `store/`, `constants/`, `adapters/`). If no common folder fits, use lowercase kebab-case (for example `data-fetchers/`).

## Examples

### Variables and constants
- Prefer `let count = 0;` over `let c = 0;`.
- Prefer `const MAX_RETRY_ATTEMPTS = 3;` over `const MAX = 3;`.

### Functions and methods
- Prefer `getUserProfile()` over `gup()`; prefer `userService.fetchRoles()` over `userService.fr()`.
- Prefer `function calculateHypotenuse(x, y) { ... }` in math contexts; avoid `function doSomething(a, b) { ... }` otherwise.

### Arrow function parameters
- Prefer `users.map((user) => user.id)` over `users.map((u) => u.id)`.
- Prefer `items.filter((item) => item.isActive)` over `items.filter((x) => x.isActive)`.
- Prefer `roles.reduce((accumulated, role) => ({ ...accumulated, [role.id]: role }), {})` over `roles.reduce((acc, r) => ({ ...acc, [r.id]: r }), {})`.

### Enums, types, and interfaces
- Prefer `UserRole`, `PaymentStatus`, `ProductCategory` over `Role`, `Status`, `Cat`.
- Prefer `interface CheckoutTotals` over `interface CT`.

### Catch blocks
- Use `catch (error) { ... }`; avoid `catch (e) { ... }`.

### Files, folders, and classes
- Prefer `userService`, `UserProfileCard`, `auth-store.js`; avoid `usrSvc`, `card.js`, `s.js`.
- Prefer `data-fetchers/`, `user-profile-settings/`; avoid `DataFetchers/`, `UserProfileSettings/`, `Profilesettings/`.

### Loop counters (acceptable exceptions)
- Prefer `for (let i = 0; i < n; i++) { ... }` for simple loop counters.
