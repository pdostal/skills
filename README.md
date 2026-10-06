# OpenCode Skills

## List of my skills

* `create-or-update-pr/` - Create or update a PR/MR on GitHub, GitLab, Gitea or Forgejo (`gh`/`glab`/`tea`/`fj`): AI label, body template, remote selection.
* `git-commit/` - Commit/amend/reword changes with Conventional Commits and YubiKey signing retry.
* `openqa-clone-or-restart/` - Turn an openQA tests overview URL + suite name into ready-to-run clone/restart commands.
* `review-openqa-job-groups/` - Audit openQA job groups' latest build against a reviewer policy and suggest bugrefs.
* `review-pr/` - Review a PR/MR (GitHub, GitLab, Gitea/Forgejo) and post suggestions, or resolve existing reviewer comments.
* `schedule-openqa-vrs/` - Research, approve, and clone openQA verification runs for a test-distro PR/MR.

`caveman*` skills are imported externally (gitignored) and not maintained here.

Each skill's `SKILL.md` is kept minimal; details, templates, and edge cases live in
`references/`, and reusable commands live in `scripts/`, loaded only when needed.

## Development

Enable the repo's git hooks once per clone:

```
git config core.hooksPath .githooks
```

`pre-commit` runs hygiene checks, markdownlint, shellcheck/shfmt, gitleaks, and
`gh skill publish --dry-run` (when a `SKILL.md` changed) against staged files.
`commit-msg` enforces the Conventional Commits format from `git-commit/SKILL.md`.
Toggle individual checks in `.githooks.config`. CI (`.github/workflows/ci.yml`)
runs the same checks on push and pull request.
