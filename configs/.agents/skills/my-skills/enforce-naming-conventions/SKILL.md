---
name: enforce-naming-conventions
description: Enforces descriptive naming and folder conventions when writing or reviewing code, including avoiding single-letter identifiers (with limited loop and math exceptions), requiring descriptive catch variable names, and using self-explanatory names for variables, functions, classes, files, and folders. Use when naming conventions or refactors are in scope.
---

# Enforce Naming Conventions

## Quick start

- Apply consistent, descriptive naming and folder conventions while editing or reviewing code.
- Avoid single-letter variable names except conventional loop counters (`i`, `j`, `k`) and mathematical variables (`x`, `y`, `z`) in math contexts.
- Use `error` or a descriptive variant (for example `caughtError`, `dbError`) in `catch (...)` blocks; never use `e`.
- Prefer self-explanatory names for variables, functions, classes, files, and folders; avoid abbreviations or terse names.
- Use common folder names where applicable (`utils/`, `services/`, `components/`, `store/`). If no common folder fits, use lowercase kebab-case (for example `data-fetchers/`).

## Examples

- Prefer `let count = 0;` over `let c = 0;`.
- Prefer `for (let i = 0; i < n; i++) { ... }` for loop counters.
- Prefer `function calculateHypotenuse(x, y) { ... }` in math contexts; avoid `function doSomething(a, b) { ... }` otherwise.
- Use `catch (error) { ... }`; avoid `catch (e) { ... }`.
- Prefer `userService`, `getUserProfile`, `UserProfileCard`, `auth-store.js`; avoid `usrSvc`, `gup()`, `card.js`, `s.js`.
- Prefer `data-fetchers/`, `user-profile-settings/`; avoid `DataFetchers/`, `UserProfileSettings/`, `Profilesettings/`.
