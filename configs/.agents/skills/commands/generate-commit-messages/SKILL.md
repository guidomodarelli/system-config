---
name: generate-commit-messages
description: Collect the information required to draft and apply a high-quality commit message.
---

# Generate Commit Messages

Collect the information required to draft and apply a high-quality commit message.

## Scope

- Focus only on understanding the current uncommitted changes.
- Analyze and commit only staged changes when staged changes exist.
- If there are no staged changes, analyze all current uncommitted changes and stage them with «git add -A» before commit.
- Do not propose new code changes.
- Do not execute destructive commands.
- Run «git commit» directly using the generated message after the selected scope is properly staged.

## Gather

- What changed: key files and the most relevant modifications.
- Why it changed: inferred intent or problem being solved.
- Impact: behavior, UX, DX, performance, or operational effects.
- Risks: edge cases, regressions, or follow-up considerations.

## Apply Step

- Run «git commit» without asking for confirmation.

## Style Constraints

- Keep everything concrete and repository-specific.
- If referring to identifiers, use «identifier».
- Replace backticks with «...».
