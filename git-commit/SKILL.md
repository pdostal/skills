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
  - Starts with an **uppercase** letter after the `type(scope):` prefix.
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

### Example

```
fix(PC_DMS): Deregister SP7 modules before migrating to SLE 16.0

Optional SLE 15-SP7 modules without 16.0 equivalents on the cloud SMT
caused zypper migration to fail with exit 104 and HTTP 422.

Co-Authored-By: Claude Sonnet 4.6
```

More examples in `references/examples.md`.

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

If a YubiKey/SSH signing error appears (`agent refused operation`): tell the user to touch
the key and **immediately retry** the same command — do not ask them to run it themselves
on the first failure. Full recovery steps in `references/yubikey-signing.md`.

---

## Rewording existing commits

See `references/reword-commits.md` for the interactive-rebase recipe.

## Reference files

- `references/examples.md` — additional commit message examples.
- `references/reword-commits.md` — rewording past commits without changing their content.
- `references/yubikey-signing.md` — full YubiKey/SSH signing failure recovery steps.
