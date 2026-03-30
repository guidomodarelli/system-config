---
name: generate-commit-messages
description: Generate commit messages for code changes, diffs, or summaries when the user wants to create a commit, generate a commit message, or says create commit, without the type prefix, issue numbers, or backticks.
---

# Generate Commit Messages

## Format

Return exactly two paragraphs:

1. Paragraph 1: a short imperative title with no `type:` prefix.
2. Paragraph 2: a detailed description that explains reasoning, implementation details, and impact.

## Rules

- Use imperative mood: `add`, `fix`, `update`, `remove`, `refactor`, `document`.
- Omit the conventional commit type prefix entirely.
- Do not include issue numbers or ticket references.
- Wrap function and variable names in `«...»`.
- Replace backticks with `«...»`.
- Keep the title concise and specific.
- Make the description explicit about why the change exists and what it affects.
- Treat the output as the commit message to use for `git commit`.
- When the user asks to create the commit, use the message format above and keep the title ready to paste as the commit subject.

## Example

add environment comments for auth variables

Clarify the purpose of each entry in «.env.example» so developers know which values belong to database access, Better Auth, Google OAuth, and community contact configuration. This reduces setup errors and keeps the sample environment file aligned with the current runtime variables.
