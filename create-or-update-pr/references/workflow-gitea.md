# Gitea workflow

Uses `tea`. Commands in `./forge-ops.md`. Commit format and push remote follow the **git-commit** skill.

1. Commit and push: `git push <push-remote> <branch>` (skip as `pr-ops` subagent; primary already did).
2. Existing open PR for the branch (`tea pulls ls`)? Show it and ask: push onto it (regenerate `## Commits`, `tea pulls edit <n> --description-file`), open a new one, or abort.
3. Ensure the `AI-Assisted` label exists (`tea labels create --name AI-Assisted --color a8d8ea --description "Created with AI assistance"`).
4. `tea pulls create --head <branch> -t "<title>" --description-file <body.md> -L AI-Assisted` (body per `./pr-body-template.md`; fork head: `--head <user>:<branch>`).
5. Post Redmine comments for `poo#NNN` as in `./workflow-github.md` step 5.
6. Return the PR URL. There is no `--watch`: check CI via the web UI or `tea api repos/{owner}/{repo}/commits/<sha>/status`, and report.

No bot-checklist hiding (GitHub-only).
