# Review Mode — Analyse diff and post comments as reviewer

## Fetch the diff

Use the forge reference's diff command.

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

Use the forge reference's inline-comment command with the original `HEAD_SHA`.
For line ranges use its range option (only when start < end); for deleted lines use the
old-file line number on the LEFT/old side.

Use the forge's suggestion block for one-to-one line fixes (GitHub:
````
<brief explanation>

```suggestion
<corrected line(s)>
```
````
GitLab: `suggestion:-0+0`; see its reference).

**Fallback anchor strategy** (when exact line unavailable):
1. Nearest `+` or context line in the same hunk
2. First line of the file's first hunk
3. Top-level comment (forge reference)

## Overall review summary

- **CRITICAL/HIGH** → ask user: request-changes or comment?
- **MEDIUM/LOW only** → submit as `--comment` automatically
- **No issues** → ask user before approving

Submit with the forge reference's review commands (GitHub: `--comment`/`--request-changes`/`--approve`; GitLab and Gitea differ — see their references).
