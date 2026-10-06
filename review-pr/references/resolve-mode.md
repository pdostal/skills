# Resolve Mode — Handle active threads

For each **active** thread (see main SKILL.md Step 3 classification):

## A. Code suggestions (suggestion block in body)

Implement the suggestion directly in the source file. Then:

1. Run the project linter on the modified file (see git-commit skill).
2. Commit using the git-commit skill conventions. Use `GIT_TRACE=1` if commit output is suppressed to diagnose failures.
   - **Running as the `pr-ops` subagent**: you cannot commit or push (hard-denied). Stop
     here and return to the primary with the commit message to use and the changed files;
     ask it to commit+push and resume you (same `task_id`) to continue at step 3.
3. If commit or push fails due to GPG/SSH signing (YubiKey), **ask the user once** to run the command in their terminal. Do not retry in a loop.
4. Reply to the thread (see Replying below).
5. Resolve the thread (GitHub: GraphQL `resolveReviewThread` mutation) using the thread id captured in Step 3 — see the forge reference.

Only resolve threads where the suggestion was fully implemented. Do **not** resolve type B (general comment) threads — those are for the reviewer to close.

## B. General comments (not a suggestion block)

Read the comment carefully. Implement what's needed, or if it's a discussion point, reply explaining the decision. Keep the reply to **1 sentence** (2–3 only if genuinely needed).

## Replying to a thread

Post the reply with the forge reference's reply command. On GitHub use `in_reply_to` with the original `HEAD_SHA` (not a new commit SHA).

Reply style: **brief and direct** — 1 sentence max, 2–3 only if genuinely required.

Examples of good replies:
- `"Done, added \`-L\`."`
- `"Removed the hint comment — the recommendation is already in variables.md."`
- `"Implemented — now detects http(s):// URLs and fetches with curl; falls back to base64 otherwise."`

## Commit strategy for resolved suggestions

- Group trivial fixes (single-line changes, comment removals) into one commit per logical topic.
- Implement non-trivial suggestions (new features, behaviour changes) as **separate commits**.
- Follow the git-commit skill for message format, linting, and signing.
