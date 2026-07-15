---
name: git-commit
description: Use when the user asks to commit changes, amend commits, reword commit messages, run a linter before committing, tidy and commit, or push changes. Triggers on phrases like "commit", "commit and push", "amend", "reword", "run perltidy", "tidy and commit", "commit with conventional format", "make a commit", "save my changes", "stage and commit", "write a commit message", "format and commit", "fix up the last commit", "squash commits", "run the linter", "push my work", "push to the branch". Do NOT trigger when the user explicitly asks to open or create a PR or MR — use the create-or-update-pr skill for that.
---

# Git Commit Skill

## Pre-commit checklist

Before committing, always:

1. **Lint the code.** Run the project's linter on any modified files. For Perl projects with `.perltidyrc`, run:
   ```bash
   perltidy --profile=.perltidyrc <file> -o /tmp/tidy.pm && diff <file> /tmp/tidy.pm || cp /tmp/tidy.pm <file>
   ```
   Stage any linter-induced changes before committing.

2. **Review the diff.** Run `git diff --cached --stat` to confirm only intended files are staged.

## Commit message format

All commit messages follow **Conventional Commits**:

```
type(scope): Short imperative subject starting with uppercase

Optional body — brief, explains what and why, not how.

Co-Authored-By: Claude Sonnet 4.6
```

### Rules

- **Types:** use short, basic types only: `feat`, `fix`, `ci`, `test`, `chore`, `docs`, `style`
  - Do **not** use `refactor` — use `feat` or `fix` instead.
- **Scope:** reuse existing scopes from the branch/repo history where it makes sense.
  Check with: `git log --format="%s" | grep -oP '\(\K[^)]+' | sort | uniq -c | sort -rn | head`
- **Subject line:**
  - Must be ≤ 72 characters. The only exception is `Revert: "..."`.
  - Starts with an **uppercase** letter after the `type(scope): ` prefix.
  - Imperative mood, no trailing period.
- **Body** (optional):
  - Separated from subject by a blank line.
  - Brief and simple — one short paragraph or a few lines max.
  - Explains *what* and *why*, not *how*.
- **Trailer:** always add as the last line of the body:
  ```
  Co-Authored-By: Claude Sonnet 4.6
  ```
  Adjust the model name to match the actual model in use.

### Examples

```
fix(PC_DMS): Deregister SP7 modules before migrating to SLE 16.0

Optional SLE 15-SP7 modules without 16.0 equivalents on the cloud SMT
caused zypper migration to fail with exit 104 and HTTP 422.

Co-Authored-By: Claude Sonnet 4.6
```

```
fix(PC_DMS): Use pc_zypper_call for repo add and remove calls

Co-Authored-By: Claude Sonnet 4.6
```

```
feat(publiccloud): Add retry logic for flaky SSH connections

Co-Authored-By: Claude Sonnet 4.6
```

## Choosing the push remote

Before pushing, always run `git remote -v` to inspect available remotes. Then:

- If a remote named `mine` exists → push to `mine`.
- Else if a remote named `pdostal` exists → push to `pdostal`.
- Otherwise → push to `origin`.

Never push to `origin` when a personal remote (`mine` or `pdostal`) is available.

## Workflow

1. Run linter on modified files; stage any formatting fixes.
2. Check staged diff: `git diff --cached --stat`
3. Determine the correct type and scope (check existing commit history for scope).
4. Write the commit message following the rules above.
5. Commit: `GIT_TRACE=1 git commit -m "type(scope): Subject" -m "Body..." -m "Co-Authored-By: ..."`
   Or use a heredoc / temp file for multi-line messages.
   If a YubiKey signing error appears, tell the user to touch the key and retry immediately.
6. Verify with `git log --oneline -3` that the commit landed correctly.
7. When pushing, follow the **Choosing the push remote** rules above.

## When commit or push fails

### YubiKey / SSH signing errors (`agent refused operation`)

Always run `git commit` with `GIT_TRACE=1` so signing failures are visible
immediately rather than silently swallowed:

```bash
GIT_TRACE=1 git commit -m "..."
```

If the output contains `agent refused operation` or `Couldn't sign message`:

1. Tell the user: **"Please touch your YubiKey."**
2. **Immediately retry** the exact same command — do not wait for the user to
   confirm it succeeded first. The YubiKey touch unblocks the SSH agent and
   the retry will succeed.
3. If the retry also fails, ask the user to run the command themselves in their
   terminal (where the agent interaction is working) and wait for confirmation.

Do **not** ask the user to run the command in their terminal on the first
failure — they are present and will touch the key.

`GIT_TRACE=1` is a useful one-off diagnostic prefix — do **not** recommend
setting it permanently in the environment or `.gitconfig`. It is very noisy
across all git operations.

### Other failures

If the failure reason is unclear, check `GIT_TRACE=1` output and report the
error to the user clearly before stopping.

---

## Rewording existing commits

To reword the last N commits without changing their content:

```bash
GIT_SEQUENCE_EDITOR="sed -i 's/^pick/reword/g'" git rebase -i HEAD~N
# Then for each commit stopped:
git commit --amend -m "new message"
git rebase --continue
```

If the editor is unavailable (e.g. `vi: No such file or directory`), the rebase will pause at each commit — use `git commit --amend -m "..."` then `git rebase --continue`.
