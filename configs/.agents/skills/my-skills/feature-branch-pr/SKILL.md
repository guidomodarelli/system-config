---
name: feature-branch-pr
description: "Ship uncommitted work end-to-end: create a feature/* branch (only if currently on a default branch), commit, push, open a PR, and report a summary table. Use when the user asks to commit & push current changes and open a PR, 'subir los cambios y crear PR', 'branch + commit + push + PR', or to close out work-in-progress into a pull request."
allowed-tools: Bash(git:*) Bash(gh:*)
---

# Feature Branch + Commit + Push + PR

Take the current uncommitted changes and ship them as a pull request in one closeout flow, then return a summary table.

## Alcance estricto

Ejecutar únicamente cierre solicitado: inspeccionar estado, crear/reutilizar branch, stage, commit, push, crear PR y verificar resultado.

- No iniciar code review, security audit, dependency audit, performance review ni análisis adicional salvo pedido explícito.
- No ejecutar tests, builds, linters o scanners adicionales. Hooks Git obligatorios pueden ejecutarse como parte de commit; no lanzar validaciones aparte.
- No invocar skills, agentes o workflows ajenos al flujo, excepto `pr-description-template`. Si una regla de mayor prioridad obliga una invocación, limitarla a determinar aplicabilidad; no expandir alcance.
- No modificar código, dependencias o configuración para corregir problemas descubiertos durante cierre.
- Si hook, commit, push o creación PR falla por contenido del repositorio, detener y reportar blocker; no aplicar fixes automáticos.
- No crear ni actualizar Jira, review comments, approvals, merge, labels ni estado del PR.
- Writes permitidos: branch local, index Git, commit, push y creación/title/body del PR solicitado.
- Si una acción no es requisito directo para cierre pedido, omitirla.

Use when:
- the user asks to commit & push the current changes and open a PR
- "subir cambios y crear PR", "branch + commit + push + PR", closeout of WIP
- the working tree has changes that should become a pull request

## Contract

- Run only when the user explicitly asks to commit/push/PR. This skill performs outward-facing, hard-to-reverse actions (push + PR).
- **Branch rule (mandatory):** create a new `feature/<slug>` branch **only if** the current branch is a default branch (`develop`, `main`, or `master`). If the current branch is already anything else, **reuse it** — never branch off a branch.
- Never commit on `develop`/`main`/`master`. If on a default branch, you must create the feature branch first.
- Keep every technical name (branch, commit subject, PR title/body) in **English**. The summary table shown to the user is in **Spanish**.
- Do not force-push, do not skip hooks (`--no-verify`), do not bypass signing.
- End commit messages with the required co-author trailer.
- If `gh` is unavailable or unauthenticated, stop before the PR step and report the push result plus the exact blocker.

## Steps

### 1. Inspect state

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

- If `git status --porcelain` is empty → nothing to ship. Report that and stop.
- Capture the current branch name for the branch decision.

### 2. Check if a PR already exists for this branch

If the current branch is NOT a default branch, check whether a PR is already open:

```bash
gh pr view --json url --jq .url 2>/dev/null
```

- **PR exists** → this is a successive commit scenario. **Do NOT commit or push automatically.** Report the current dirty state (files changed, insertions/deletions) and the existing PR URL, then **stop**. The user owns the commit/push lifecycle after the initial PR creation.
- **No PR exists** → continue with the full flow below.

### 3. Decide the branch

Default branches: `develop`, `main`, `master`.

- **Current branch IS a default branch** → create a new one. Derive a short, descriptive English slug from the change:

  ```bash
  git switch -c "feature/<slug>"
  ```

  `branchAction = "created"`.

- **Current branch is NOT a default branch** → reuse it. Do **not** create or rename anything.

  `branchAction = "reused"`.

Slug rules: lowercase, hyphen-separated, English, no spaces, no ticket-noise. Example: `feature/link-preapproval-checkout`.

### 4. Commit

Stage everything and commit with a clear Conventional-Commit-style English subject plus a short body describing the change.

```bash
git add -A
git commit -m "$(cat <<'EOF'
<type>: <concise english subject>

<short english body: what changed and why>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

On Windows PowerShell, use a single-quoted here-string (`@' ... '@`) for the message instead of the bash heredoc.

If a pre-commit hook fails, fix the underlying issue and retry — do not bypass it.

### 5. Push

Push and set upstream on first push of the branch:

```bash
git push -u origin HEAD
```

Capture the push result and the remote tracking ref.

### 6. Open the PR

Check tooling first:

```bash
gh auth status
```

If `gh` is missing or unauthenticated, skip this step and record the blocker. Otherwise:

**Build the title and body in full-composition mode with the [pr-description-template](../pr-description-template/SKILL.md) skill** — fill every applicable section from the diff, remove optional sections that add no context, then write the body to a temp file and pass it with `--body-file`:

```bash
gh pr create --title "<english subject>" --body-file <tmp-body.md> --base <default-branch> --head <feature-branch>
```

- Base = the repo's default branch (`develop` if it exists, else `main`/`master`). Confirm with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
- Title in English; body follows the `pr-description-template` (Spanish prose, English code/identifiers).
- Mark exactly one primary change type, include reproducible manual steps, and keep only applicable HTTP contract changes.
- Mention automated coverage inside **Descripción** only when it adds reviewer context.
- Do not add a **Referencia** metadata block, Jira workflow rules, or invoke `kraken-jira-ticket` automatically.
- A later Jira association uses traceability-only mode and must not regenerate title or body.
- End the PR body with:

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

- Capture the returned PR URL.

### 7. Report the summary table (Spanish)

Always close with a Markdown table summarizing the run:

| Paso | Resultado |
| --- | --- |
| Rama | `feature/<slug>` (creada \| reutilizada) |
| Base | `<default-branch>` |
| Commit | `<short-hash>` — `<subject>` |
| Push | OK → `origin/<feature-branch>` |
| PR | `<pr-url>` (o motivo si no se creó) |

If any step was skipped or failed, show its real status in the table (e.g. `PR | No creado — gh no autenticado`) instead of reporting success.

## Edge cases

- **Clean tree:** nothing to commit → report and stop; do not create an empty branch or PR.
- **Detached HEAD:** treat as non-default → create `feature/<slug>` so the work is not orphaned, then proceed.
- **PR already open for the branch (successive commits):** do NOT commit or push. Report the dirty-tree summary and the existing PR URL, then stop. The user decides when and how to commit/push subsequent changes.
- **Push rejected (non-fast-forward):** do not force-push. Report the rejection and ask the user how to proceed.
- **No `origin` remote:** stop after the commit, report the missing remote.
