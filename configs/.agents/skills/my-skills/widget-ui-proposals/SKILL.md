---
name: widget-ui-proposals
description: "Show UI/UX proposals, variants and previews as interactive Claude visual widgets (mcp__visualize__show_widget) instead of — or before — writing code, and let the user pick-and-apply options to build the final solution. Use when the user wants to try several variants/options/alternatives for an interface, compare design or UX approaches, see how a change would look before applying it, or iterate by choosing improvements. Triggers (es/en): 'probar variantes', 'varias propuestas', 'varias opciones', 'mostrame opciones', 'opciones de UI/UX', 'alternativas de diseño', 'cómo quedaría', 'mostrame cómo queda', 'preview del cambio', 'mejorar la interfaz', 'rediseñá esto', 'qué mejorarías', 'mostrame un widget', 'try several variants', 'show me options/proposals', 'compare UI options', 'how would it look'."
---

# Widget-driven UI/UX proposals & previews

Use Claude visual widgets to **show** interface work before/while coding it, so the user
decides from something they can see — not a wall of prose. Two recurring shapes:

1. **Proposals / variants** — a grid of option cards the user can apply one-by-one.
2. **Preview** — a mockup of how a requested change would look (final result).

Always render the visual with the `mcp__visualize__show_widget` tool. Explanatory text,
recommendations and trade-offs go in the chat response, **never inside the widget**.

## When to use

- The user asks for **several** variants/proposals/options/alternatives for UI or UX.
- The user asks to improve / redesign an interface and the solution space is open.
- The user asks "cómo quedaría / mostrame cómo queda / preview" of a change before applying it.
- You're about to make a non-trivial visual change and a preview would de-risk it.

Do NOT use it for: backend-only logic, a trivial one-line style tweak the user already
specified exactly, or when the user explicitly asked you to just write the code.

## Workflow

### 1. Before the first widget
Call `mcp__visualize__read_me` **once, silently** (pick modules `mockup` / `interactive` /
`data_viz` as fit). Do not narrate this call — just build the widget afterward.

### 2a. Proposals / variants mode
When the user wants to explore options, render **one widget** with a responsive grid of
option cards. Each card:

- A short title + 1–2 line description of the approach and its trade-off (in **Spanish** —
  the user works in Spanish).
- An apt Tabler outline icon.
- An **"Aplicar ↗"** button that calls `sendPrompt('Implementá: <concrete instruction>')`
  so a click sends the message that triggers implementation. The instruction must be
  self-contained (it will be read cold).
- Mark 1–2 cards "Recomendada" with a subtle badge + `border: 2px solid var(--color-border-info)`.

Options must be **distinct and composable** — the user may apply several. After the widget,
in the chat give your ranked recommendation and how they combine.

### 2b. Preview mode
When the user asks for a specific change (or you're proposing one), render a widget that
**mockups the final result** with realistic sample data, matching the real component's
structure (layout, labels, states). Use it to confirm direction before editing code.

### 3. Apply-and-iterate loop
- The user clicks an "Aplicar" button or names the option(s) they want.
- Implement that change in the real code following project conventions (architecture,
  SCSS/components, tests, gates).
- When useful, show an **updated preview widget** of the new state and offer the next batch
  of options. Repeat until the user is satisfied.
- The user can keep adding options across turns — treat the widgets as the running menu and
  the code as the accumulating final solution.

### 4. After implementing
Run the project's quality gates for the changed files (lint, typecheck, relevant tests) and
report status. Keep widget copy and chat questions/recommendations in **Spanish**.

## Widget design rules (from the visualize design system)

- Flat and native: no gradients, drop shadows, blur or neon. Use the host CSS variables
  (`--color-*`, `--border-radius-*`, `--font-*`) so it adapts to light/dark.
- Sentence case, two font weights (400/500), no font-size below 11px, Tabler **outline**
  icons only (`<i class="ti ti-...">`).
- The widget contains **only** the visual. Titles, explanations and trade-offs go in your
  chat response.
- `sendPrompt(text)` for any action that should continue the conversation (apply an option,
  drill into one). Append `↗` to such buttons.
- For interactive option widgets, make filters/toggles work in JS so the user can feel the
  interaction; round every displayed number.
- Scale effort to the ask: a few options for "show me some ideas"; a larger, clearly-ranked
  set for "what would you improve / be thorough".

## Anti-patterns

- Don't dump the proposals as a long prose list when the user asked to "see" options — show
  the widget.
- Don't put paragraphs of explanation inside the widget.
- Don't invent that you can't preview something visual — a mockup widget is almost always
  possible with sample data.
- Don't apply changes the user didn't pick; the widget proposes, the user disposes.
