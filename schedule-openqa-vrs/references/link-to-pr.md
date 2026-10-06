# Step 5 — link the VRs back to the source PR/MR

When the VRs were cloned for a GitHub/GitLab/Gitea/Forgejo PR/MR that has a
`* Verification runs:` (or similarly named) placeholder line in its
description — common in this org's PR template — wire it up:

1. Draft a PR/MR body edit that replaces the empty/placeholder verification
   runs line with `* Verification runs: In comment below` (keep the rest of
   the body untouched — fetch the current body first, edit only that line).
2. Draft the actual comment: the same clones table from Step 4 plus the
   `openqa-mon` command. Add a `Status` column (`running`/`passed`/`failed`/
   etc., from `get_job_status`) when jobs haven't finished yet — do **not**
   wait/poll for completion before drafting or posting. A placeholder comment
   with live links and the `openqa-mon` command is useful immediately;
   results can be posted as a follow-up comment/edit once jobs finish.
3. No confirmation gate for this skill (see Step 2 note) — update the body
   first, then post the comment, so the description's "in comment below"
   claim is never left dangling even momentarily:
   ```sh
   gh pr edit <PR> --repo <owner>/<repo> --body-file <edited-body.md>
   gh pr comment <PR> --repo <owner>/<repo> --body-file <vr-comment.md>
   ```
   Other forges (see `create-or-update-pr/references/forge-ops.md`):
   `glab mr update <IID> -R <ns>/<repo> --description-file <f>` + `glab mr note create <IID> -R <ns>/<repo> -m "$(cat <f>)"`;
   `tea pulls edit <N> -r <owner>/<repo> --description-file <f>` + `tea comment <N> -r <owner>/<repo> "$(cat <f>)"`;
   `fj pr comment <N> -r <owner>/<repo> --body-file <f>` (Forgejo body edit: REST API).
   If running as the `openqa-ops` subagent (no forge CLI access), hand both
   drafts to the primary agent to post immediately instead.
