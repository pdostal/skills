---
name: schedule-openqa-vrs
description: >
  Use when the user asks to schedule, clone, or trigger verification runs
  (VRs) for an openQA test-distribution PR/MR or branch — e.g. "schedule a
  bunch of VRs", "clone jobs to verify this PR", "run VRs for poo#123",
  "openqa-clone-custom-git-refspec", "verify this fix on openQA", or
  "clone some jobs for this branch". Covers researching which production
  jobs to clone, presenting them for approval, safely cloning them without
  polluting dashboards, and reporting results back as a table and an
  openqa-mon command. Do NOT trigger for plain job restarts/retries with a
  fixed job-ID template — see the openqa-clone-or-restart skill for that.
---

# Schedule openQA verification runs (VRs)

Verification runs let a test-distribution change (a PR/MR, or a pushed
branch) be exercised against real production job settings/assets before
merging, without touching the actual production job history. This skill
covers the full loop: find good jobs to clone, clone them safely, and report
back — fully autonomously, no approval/confirmation gates (see the note in
Step 2; intentional exception to the general "confirm before posting" rule).

**Prefer delegating to the `openqa-ops` subagent** (`task` tool) to run this end to end and
keep the skill's detail out of the main thread.

Read
[Safely clone a job on a production instance](https://openqa-bites.github.io/posts/2023/2023-02-23-safely_clone_a_job_on_a_production_instance/)
if the tool below is ever unavailable and a manual `openqa-clone-job` is the
only option — it explains why `_GROUP=0` plus custom `BUILD`/`TEST` are
mandatory (skip it entirely when using `openqa-clone-custom-git-refspec`,
which already implements the recipe).

## Step 0 — identify inputs

You need:
1. A GitHub PR URL, or a `.../tree/<branch>` URL for a fork branch.
2. An openQA host to search (`openqa.suse.de` for SUSE-internal/SLE work,
   `openqa.opensuse.org` for openSUSE work — infer from the repo/ticket, ask
   if ambiguous).
3. Optionally a Redmine (`poo#NNN`) or Bugzilla ticket referenced by the PR —
   fetch it, it often links the exact failing job that motivated the fix.

## Step 1 — find candidate jobs (research, no mutation yet)

Never guess job IDs. Work outward from evidence:

1. **Read the diff.** Find which changed test/library files (`tests/**/*.pm`, `lib/**/*.pm`)
   are loaded by which `main_*.pm`/YAML schedules via `loadtest(".../<module_name>"`, and
   under what flag condition (e.g. `PUBLIC_CLOUD_MIGRATE_SLEM`). That tells you which TEST
   scenarios actually exercise the change — don't clone a scenario that never runs it.
2. **Check the linked ticket/failure first.** If the ticket/PR links a specific failing job,
   fetch it (`get_job`/`get_job_details`) — almost always the single most valuable clone
   target. Trust its actual `TEST`/`PUBLIC_CLOUD_PROVIDER`/arch/version settings over any
   TEST name guessed from file/module names (a module like `instance_overview.pm` is usually
   one part of a larger scenario, not its own TEST suite).
3. **Full-text search the openQA instance** (`search` MCP tool) for a module/test-suite name
   when grepping the repo alone doesn't resolve which job groups schedule it.
4. **List recent jobs** per candidate TEST name (`list_jobs test=<name> limit=<n>
   summary=true`) across relevant providers/arches/versions. Prefer **passed** baseline jobs
   for regression coverage; reserve **failed** jobs for reproducing an exact reported bug.
5. Don't over-collect — a handful of jobs each exercising a distinct code path beats a large
   undifferentiated batch. If the user says "not so much", cut down rather than padding.

## Step 2 — record the plan (no approval gate)

**Intentional exception**: unlike most skills in this collection, this workflow does not
wait for user approval before cloning or for confirmation before posting (Step 4/5). This
was a deliberate choice to let it run fully autonomously (e.g. via a subagent) — cloning
uses `_GROUP=0` so it never pollutes dashboards or production history, which is what made
this safe to waive.

Before cloning, log the plan as a table (for the final report, not for approval):

| # | Job | Scenario | Provider/Arch | Why |
|---|---|---|---|---|
| 1 | [id](https://host/tests/id) | `TEST_NAME` (version) | PROVIDER / ARCH | one line: what this job proves and why it was picked |

Run the exact `openqa-clone-custom-git-refspec` command with `-n` (dry-run) first as a
sanity check — it makes real GET requests to resolve `vars.json`/PR metadata but never
calls the openQA API to create a job. If the dry-run output looks wrong (unexpected job
count, wrong scenario), stop and report rather than proceeding to the real clone.

## Step 3 — clone

```sh
openqa-clone-custom-git-refspec \
  <github_pr_or_branch_url> \
  <comma-separated-job-urls-on-one-host> \
  [EXTRA_VAR=value ...]
```

- One invocation per source host; comma-separate multiple job URLs from the same host.
- `EXTRA_VAR=value` pairs pass through as setting overrides on every cloned job. Common one:
  `EXCLUDE_MODULES=mod1,mod2` to skip modules irrelevant to the change (e.g.
  `transfer_repos`/`download_repos`) — call this out explicitly to the user rather than
  assuming it, since it changes what actually gets tested.
- The tool already implements the full "safe clone" recipe: `_GROUP=0` (won't show on any
  dashboard), `BUILD=<repo>#<pr-or-branch>`, `TEST` suffixed `@<repo>#<branch>` (won't
  pollute the original scenario's history), `CASEDIR`/`PRODUCTDIR` at the fork+branch. No
  manual `_GROUP_ID=0`/`{TEST,BUILD}+=` juggling needed.

After cloning, spot-check at least one clone with `get_job` and confirm
`group_id: null`, `BUILD`/`CASEDIR` point at the fork+branch, and any
`EXCLUDE_MODULES`/extra vars landed — before telling the user it's done.

## Step 4 — report back

Give the user, in this order:

1. A markdown table of the **clones** (not originals) — columns: Clone (linked), Scenario,
   Provider/Arch. Drop columns the user doesn't want.
2. An `openqa-mon` command grouped by host: `openqa-mon -fsc15 https://<host> -j <id1> <id2>
   ...` — don't invent flags the user hasn't specified; mirror any form they've given before.
3. If asked for a GitHub-comment-ready version, reuse the table with full
   `https://.../tests/<id>` links (or `openqa.suse.de/tNNN` shorthand) and post it directly
   — no confirmation gate for this skill (see Step 2).

## Step 5 — link the VRs back to the source PR/MR

When the VRs were cloned for a GitHub/GitLab PR/MR with a `* Verification runs:`
placeholder in its description, wire it up — see `references/link-to-pr.md`. Post the body
edit and comment directly, no confirmation gate (see Step 2).

## Notes

- Steps 0–2 are pure research (including the `-n` dry-run); Step 3 onward mutates/posts
  without pausing for approval, per the intentional exception noted in Step 2.
- If the reported bug's job uses an unexpected TEST name, trust the job's actual settings
  over diff-based assumptions — verify which `main_*.pm` branch loads the module under those
  exact settings.
- If the fix also touches a shared/generic code path, ask whether the user wants coverage
  for the "other" path too rather than assuming the original bug report's scope is enough.
