# PR / MR body template

```
$WHAT_WAS_DONE_SHORT_PARAGRAPH.

* Related ticket: [poo#123](https://progress.opensuse.org/issues/123)
* Related failure: [openqa.suse.de/t123](https://openqa.suse.de/tests/123)
* Related merge requests: !123, !456, ...
* Verification runs:

## Commits

- abc1234 feat: add user login
- def5678 fix: handle null session
- ghi9012 style: run linter

The `style` commit (ghi9012) is an automated linting pass and can be ignored. The `fix` commit (def5678) changes auth logic and warrants a separate look.
```

Rules:
- Each paragraph states **what was done** only — no background, no explanation of the bug, no "why it was broken". Use short, direct sentences.
- **Small PR or single commit**: one short paragraph is enough.
- **Large PR with multiple logical changes**: use two or three short paragraphs, one per logical change — each still stating only what was done.
- The PR/MR title must be plain English — do not apply the `type(scope):` conventional commit prefix to it.
- Use `*` bullets (not `-`) for all metadata lines.
- Use singular forms: `* Related ticket:`, `* Related failure:`, `* Verification runs:`.
- `* Verification runs:` is **always present**, even when empty — leave it blank so the author can fill it in later.
- Omit `* Related ticket:` if no ticket is provided.
- Omit `* Related failure:` if there is no related failing run.
- Omit `* Related merge requests:` if there are no related MRs/PRs.
- Do not include placeholder lines for omitted sections (except `* Verification runs:` which is always kept).
- **openQA links**: use the format `[openqa.suse.de/tNNN](https://openqa.suse.de/tests/NNN)`.
- Omit the `## Commits` section entirely if there is only one commit.
- Populate the `## Commits` list using `git log <base>..<branch> --oneline`; use the short hash and full subject line for each entry.
- Write commit SHAs as bare short hashes **without backticks** — e.g. `abc1234`, not `` `abc1234` ``. On GitHub and GitLab, bare hashes auto-link to the commit; backticks render as code and suppress the link.
- After the list, add a single prose sentence (or two at most) noting: any `style`-type commits that reviewers can ignore (automated formatting/linting), and any distinct `feat`, `fix`, or `refactor` commits that warrant a separate look.
- Omit the summary sentence if all commits are of the same logical type and none need special attention.
- For cross-repo references use platform shorthand instead of full URLs:
  - **GitHub**: `owner/repo#N` for issues/PRs (e.g. `SUSE-Enceladus/gcemetadata#8`) — renders as a clickable link automatically.
  - **GitLab**: `namespace/repo#N` for issues, `namespace/repo!N` for MRs — same auto-linking behaviour.
  - Same-repo references: just `#N` (issue/PR) or `!N` (MR) as before.
