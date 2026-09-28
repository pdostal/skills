# Review Mode — Analyse diff and post comments as reviewer

## Fetch the diff

```bash
gh pr diff "$PR_NUMBER"
```

Parse carefully:
- `diff --git a/<path> b/<path>` — file section start
- `@@ -OLD_START,OLD_COUNT +NEW_START,NEW_COUNT @@` — hunk header
- `+` lines — additions (RIGHT side); `-` lines — deletions (LEFT side); ` ` — context

Track the **new-file line number**:
- Context line: increment
- `+` line: this is new_line, increment
- `-` line: do NOT increment

## What to look for

- **Bugs** — off-by-one, null dereferences, unchecked errors, wrong conditions
- **Security** — injection risks, hardcoded secrets, missing auth checks
- **Logic** — wrong algorithm, wrong variable, missing edge cases
- **Resource management** — unclosed handles, memory leaks
- **Concurrency** — race conditions, deadlocks
- **API misuse** — wrong HTTP method, deprecated functions
- **Test coverage** — new code paths with no tests

Do NOT flag pure style nits or things not visible in the diff.

## Plan Mode — print issue list

```
PR #<number>: <title>
<url>
Base: <base_ref>  Head: <head_ref>

Found <N> issue(s):

1. [SEVERITY] file/path.ext:<start_line>-<end_line>  <short title>

   <context lines>
   <start_line>:  +  <affected line>

   Problem: <concise explanation>
   Suggestion: <concrete fix>
```

Severity: `[CRITICAL]`, `[HIGH]`, `[MEDIUM]`, `[LOW]`

## Build Mode — post inline comments

```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments \
  --method POST \
  -f commit_id="$HEAD_SHA" \
  -f path="<file>" \
  -f side="RIGHT" \
  -F line=<end_line> \
  -f body="<body>"
```

For line ranges add `-f start_side="RIGHT" -F start_line=<N>` (only when start < end).

For deleted lines use `side=LEFT` and the old-file line number.

Use GitHub suggestion blocks for one-to-one line fixes:
````
<brief explanation>

```suggestion
<corrected line(s)>
```
````

**Fallback anchor strategy** (when exact line unavailable):
1. Nearest `+` or context line in the same hunk
2. First line of the file's first hunk
3. Top-level comment: `gh pr comment $PR_NUMBER -b "..."`

## Overall review summary

- **CRITICAL/HIGH** → ask user: request-changes or comment?
- **MEDIUM/LOW only** → submit as `--comment` automatically
- **No issues** → ask user before approving

```bash
gh pr review "$PR_NUMBER" --comment -b "## PR Review Summary\n\n..."
gh pr review "$PR_NUMBER" --request-changes -b "..."
gh pr review "$PR_NUMBER" --approve -b "..."
```
