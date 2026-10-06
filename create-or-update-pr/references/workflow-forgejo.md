# Forgejo workflow

Uses `fj`. Commands in `./forge-ops.md`. Commit format and push remote follow the **git-commit** skill.

1. Commit and push: `git push <push-remote> <branch>` (skip as `pr-ops` subagent; primary already did).
2. Existing open PR for the branch (`fj pr search`, match head)? Show it and ask: push onto it (regenerate `## Commits`), open a new one, or abort. `fj pr edit <n> body` opens an editor, so update through the REST API (`curl -X PATCH .../api/v1/repos/{o}/{r}/pulls/<n>` with a token) when running unattended.
3. Ensure the `AI-Assisted` label exists (`fj repo labels create AI-Assisted a8d8ea -d "Created with AI assistance"`).
4. `fj pr create --head <branch> --body-file <body.md> "<title>"`, then `fj pr edit <n> labels -a AI-Assisted`.
5. Post Redmine comments for `poo#NNN` as in `./workflow-github.md` step 5.
6. Return the PR URL, then `fj pr status <n> --wait` for CI.

No bot-checklist hiding (GitHub-only).
