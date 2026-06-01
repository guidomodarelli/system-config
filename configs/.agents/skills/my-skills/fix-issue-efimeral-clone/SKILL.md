---
name: fix-issue-efimeral-clone
description: Fix a GitHub or repository issue from a brand-new ephemeral depth-1 clone of the current branch, then push the resulting commit or commits to the original branch and delete the clone. Use when the user asks to correct, implement, or address an issue in an isolated disposable clone, especially requests like "fix this issue in an ephemeral clone, commit, and push", "corrigi esta issue en un clone efimero", or "clone depth 1, fix, push to the original branch, and clean up".
---

# Fix Issue Efimeral Clone

## Contract

- Keep the user's current checkout untouched during investigation and implementation.
- Always create a new and fresh temporary clone for the task; never reuse an existing clone or stale directory.
- Clone with `--depth 1` from the current branch's remote tracking branch.
- Ensure the clone starts from the latest remote state of the original branch.
- Copy `.env` and `.env.*` files from the original checkout into the fresh clone before testing, so validation can use the same local environment.
- Link the original checkout's `node_modules` into the fresh clone only when it is safe for the platform and package manager. On Windows or when the repo uses `pnpm`, install dependencies inside the clone instead of linking.
- Do all implementation, validation, commit, and push work inside the fresh temporary clone.
- Before pushing, fetch the latest remote state of the original branch and rebase or fast-forward safely.
- If updating before push creates conflicts, resolve them through the active rebase inside the same temporary clone, then revalidate before pushing.
- Push the original branch only after tests pass on the latest remote state.
- Remove the temporary clone after a successful push.
- Never force-push, delete user branches, or discard user changes unless explicitly requested.
- If the issue, repo, current branch, remote tracking branch, or acceptance criteria are unclear and cannot be inferred from local or GitHub context, ask before editing.

## Workflow

1. Identify the repository root, original branch, and issue source.
   - Run `git rev-parse --show-toplevel`.
   - Read the issue body and comments from the GitHub app or `gh` when a URL, issue number, or current repo context is available.
   - Read the active branch from the original checkout with `git branch --show-current`.
   - Confirm the current checkout status with `git status --short`; treat dirty files as user work to preserve.
   - Resolve the current branch's upstream with `git rev-parse --abbrev-ref --symbolic-full-name @{u}`.
   - If the checkout is detached or the current branch has no upstream, ask before editing.

2. Create a brand-new depth-1 clone from the latest remote branch.
   - Fetch the remote in the original checkout with `git fetch origin`.
   - Use the remote URL from the original checkout.
   - Create a unique new temporary path outside the current working tree, for example under the OS temp directory.
   - If the intended path already exists, choose a different fresh path. Do not clean or reuse the existing path.
   - Clone the current branch from its remote with `--depth 1`.

```bash
original_repo=$(pwd)
current_branch=$(git branch --show-current)
upstream_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
remote_name=${upstream_branch%%/*}
remote_branch=${upstream_branch#*/}
remote_url=$(git remote get-url "$remote_name")
clone_path="../repo-issue-123-$(date +%Y%m%d%H%M%S)"
git fetch "$remote_name" "$remote_branch"
git clone --depth 1 --branch "$remote_branch" "$remote_url" "$clone_path"
cd "$clone_path"
```

3. Copy local environment files into the clone.
   - Copy `.env` and every `.env.*` file from the original checkout root into the fresh clone root before installing, running, or testing.
   - Preserve filenames exactly.
   - Do not copy env files from anywhere outside the original checkout root.
   - Do not stage or commit env files; they are local-only test inputs.
   - If an env file already exists in the fresh clone for an unexpected reason, do not overwrite it silently. Stop and inspect why the supposedly fresh clone already has one.

```bash
find "$original_repo" -maxdepth 1 -type f \( -name ".env" -o -name ".env.*" \) -exec cp -p {} "$clone_path"/ \;
```

4. Prepare dependencies inside the clone.
   - On Windows, do not create a symlink or junction for `node_modules`; install dependencies inside the clone before validation.
   - If the repo uses `pnpm`, do not link `node_modules` on any platform because validation commands can break or hang on linked dependency trees.
   - On non-Windows repos that do not use `pnpm`, if the original checkout root has a `node_modules` directory and the fresh clone does not, a symbolic link at `<clone>/node_modules` may be used to avoid duplicate installs.
   - Do not copy `node_modules`.
   - Do not overwrite an existing `node_modules` in the fresh clone; inspect first if it unexpectedly exists.
   - If linking is skipped or fails, run the repo's normal install command inside the clone and report that dependencies were installed locally.

```bash
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) should_link_node_modules=false ;;
  *) should_link_node_modules=true ;;
esac

if [ -f pnpm-lock.yaml ]; then
  should_link_node_modules=false
fi

if [ "$should_link_node_modules" = true ] && [ -d "$original_repo/node_modules" ] && [ ! -e "$clone_path/node_modules" ]; then
  ln -s "$original_repo/node_modules" "$clone_path/node_modules"
fi
```

```powershell
# Windows: do not junction node_modules. Run the repo's install command inside the clone instead.
if (Test-Path -LiteralPath 'pnpm-lock.yaml') {
  pnpm install --frozen-lockfile
} elseif (Test-Path -LiteralPath 'package-lock.json') {
  npm ci
} elseif (Test-Path -LiteralPath 'yarn.lock') {
  yarn install --frozen-lockfile
}
```

5. Implement only inside the clone.
   - Re-read relevant project instructions from inside the clone.
   - Inspect existing modules before changing code.
   - Keep edits scoped to the issue and preserve unrelated local changes in the original checkout.
   - Follow any project-specific testing, language, review, and style rules discovered in the clone.

6. Validate with real commands.
   - Run the smallest relevant test or quality gate that proves the fix.
   - If the issue is a build, lint, runtime, or CI failure, reproduce or run the real failing command when feasible.
   - If validation cannot run, explain the exact command that was skipped and the concrete blocker.

7. Commit inside the clone.
   - Review the diff with `git diff --check`, `git diff`, and `git status --short`.
   - Confirm `.env` and `.env.*` files are not staged.
   - Confirm `node_modules` is not staged.
   - Stage only files belonging to the fix.
   - Write a concise commit message that references the issue when useful.

```bash
git add <files>
git commit -m "Fix issue #123 short topic"
```

8. Refresh from remote immediately before pushing.
   - Fetch the latest remote branch inside the clone.
   - Rebase the local fix commit or commits on top of the latest remote branch.
   - Compare the remote branch commit before and after `git fetch`.
   - If the remote branch did not change, do not rerun validation; the already validated code is still based on the same remote state.
   - If the remote branch changed, inspect the remote-only diff before deciding whether to revalidate.
   - If the remote-only changes are clearly unrelated to the fix files, runtime path, dependency graph, or validation surface, do not rerun validation.
   - If the remote-only changes touch the same files, nearby modules, shared configuration, dependencies, generated contracts, test setup, or anything that could affect the fix, rerun the relevant validation before pushing.
   - If relatedness is unclear, prefer rerunning the relevant validation before pushing.
   - If the rebase reports conflicts, resolve them in the same temporary clone with the normal rebase flow, then rerun the relevant validation before pushing.

```bash
remote_before_fetch=$(git rev-parse "origin/$remote_branch")
git fetch origin "$remote_branch"
remote_after_fetch=$(git rev-parse "origin/$remote_branch")
if [ "$remote_before_fetch" != "$remote_after_fetch" ]; then
  git diff --name-only "$remote_before_fetch" "$remote_after_fetch"
fi
git rebase "origin/$remote_branch"
remote_changes_are_related=false # Set to true when the remote diff affects the fix or is unclear.
if [ "$remote_before_fetch" != "$remote_after_fetch" ] && [ "$remote_changes_are_related" = true ]; then
  <rerun relevant validation command>
fi
```

9. Push the original branch.
   - Push the clone's current branch to the original branch on the remote.
   - Do not force-push.
   - Do not push any temporary branch.

```bash
git push origin HEAD:"$remote_branch"
```

10. Close out.
   - Report the clone path, original branch, commit hash or hashes, push target, and validation commands.
   - Remove the temporary clone after the push succeeds.
   - Delete only the clone path created for this run.
   - If removal fails, report the exact remaining path and failure reason.

```bash
cd "$original_repo"
rm -rf "$clone_path"
```

```powershell
Set-Location -LiteralPath $originalRepo
Remove-Item -LiteralPath $clonePath -Recurse -Force
```

## Conflict Rebase Rule

- Treat conflicts during the final remote refresh as normal rebase work inside the temporary clone.
- Inspect conflicts with `git status` and the conflicted files.
- Resolve conflicts intentionally, preserving the issue fix and the latest remote changes.
- Stage resolved files with `git add <files>`.
- Continue with `git rebase --continue`.
- Repeat until the rebase completes or a conflict cannot be resolved safely.
- Rerun the relevant validation after any conflict resolution before pushing.
- Use `git rebase --abort` only if the conflict cannot be resolved safely or the user asks to stop.
- If the rebase is aborted, keep the temporary clone for inspection and report the clone path, branch, and conflict details.

## Failure Handling

- If the original checkout is dirty, do not copy or reset those changes; leave them alone and clone from the current branch's remote state.
- If the temporary clone becomes dirty due to an abandoned approach, preserve any useful patch only if it is conflict-free and intentional, then delete that clone and create another fresh clone. Do not reuse the abandoned path.
- If tests fail because of unrelated existing failures, capture the failure evidence, keep the fix commit limited to the issue, and explain the residual risk.
- If push fails due to auth, permissions, branch protection, or network errors, keep the temporary clone until the user can continue, and report the exact branch, commit, clone path, and cleanup status.
