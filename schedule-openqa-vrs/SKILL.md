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
covers the full loop: find good jobs to clone, get explicit approval, clone
them safely, and report back.

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

1. **Read the diff.** Identify which test module files (`tests/**/*.pm`) and
   library files (`lib/**/*.pm`) changed, and grep the distro repo for
   `loadtest(".../<module_name>"` to find which `main_*.pm` / YAML schedule
   files load them, and under what condition (flags like
   `PUBLIC_CLOUD_MIGRATE_SLEM`, `is_container_test`, etc). This tells you
   which TEST scenarios actually exercise the changed code, and which ones
   don't (don't waste a clone on a scenario that never runs the changed
   module).
2. **Check the linked ticket/failure first.** If the Redmine/Bugzilla ticket
   or PR body links a specific failing openQA job, fetch it
   (`get_job`/`get_job_details`). This is almost always the single most
   valuable job to clone — it directly re-tests the reported bug. Note its
   exact `TEST` name, `PUBLIC_CLOUD_PROVIDER`/arch/version — the TEST name in
   the job settings is authoritative, not any TEST name you might guess from
   file/module names (a module like `instance_overview.pm` is not necessarily
   its own TEST suite; it's usually one module inside a larger scenario like
   `slem_migration` or `publiccloud_slem_containers`).
3. **Use full-text search on the openQA instance** (the `search` MCP tool) for
   a module or test-suite name to discover which job groups/templates
   actually schedule it, when grepping the repo alone doesn't resolve the
   TEST name.
4. **List recent jobs** for each candidate TEST name
   (`list_jobs test=<name> limit=<n> summary=true`), across the
   providers/architectures/product-versions relevant to the change. Prefer
   **passed** baseline jobs for regression coverage (a new failure after
   cloning then directly implicates the change) and reserve **failed**
   jobs specifically for reproducing an exact reported bug.
5. Don't over-collect. A handful of jobs that each exercise a distinct code
   path (different provider, arch, product version, or literally the
   reported-bug job) beats a large undifferentiated batch. If the user says
   "not so much" about part of the list, cut it down rather than padding.

## Step 2 — present for approval

Always show the user a table before cloning anything:

| # | Job | Scenario | Provider/Arch | Why |
|---|---|---|---|---|
| 1 | [id](https://host/tests/id) | `TEST_NAME` (version) | PROVIDER / ARCH | one line: what this job proves and why it was picked |

Include the exact `openqa-clone-custom-git-refspec` command you intend to
run. If useful, run it once with `-n` (dry-run) first — this makes real
GET requests to resolve `vars.json`/PR metadata but **never calls the
openQA API to create a job**, so it's safe to run without approval as a
sanity check. Never run without `-n` before the user has approved the list.

Wait for explicit approval. Adjust the list on feedback (drop/add/swap jobs)
before proceeding.

## Step 3 — clone

```sh
openqa-clone-custom-git-refspec \
  <github_pr_or_branch_url> \
  <comma-separated-job-urls-on-one-host> \
  [EXTRA_VAR=value ...]
```

- One invocation per source host; comma-separate multiple job URLs from the
  same host as the second argument.
- `EXTRA_VAR=value` pairs are passed straight through as openQA setting
  overrides on every cloned job. A common one: `EXCLUDE_MODULES=mod1,mod2`
  to skip modules irrelevant to the change under test (e.g. maintenance
  repo-transfer modules like `transfer_repos`/`download_repos` that have
  nothing to do with the fix being verified) — call this out explicitly to
  the user rather than assuming it, since it changes what actually gets
  tested.
- The tool already implements the full "safe clone" recipe: `_GROUP=0`
  (job won't show on any dashboard or count toward a group), `BUILD` set to
  `<repo>#<pr-or-branch>`, `TEST` suffixed with `@<repo>#<branch>` (won't
  pollute the original scenario's Next/Previous history), and
  `CASEDIR`/`PRODUCTDIR` pointed at the fork+branch. No manual
  `_GROUP_ID=0`/`{TEST,BUILD}+=` juggling needed.

After cloning, spot-check at least one clone with `get_job` and confirm
`group_id: null`, `BUILD`/`CASEDIR` point at the fork+branch, and any
`EXCLUDE_MODULES`/extra vars landed — before telling the user it's done.

## Step 4 — report back

Give the user, in this order:

1. A markdown table of the **clones** (not the originals) — columns: Clone
   (linked), Scenario, Provider/Arch. Drop any column the user doesn't want
   (e.g. they may not care about the "Original" job once clones exist).
2. An `openqa-mon` command grouped by host:
   ```
   openqa-mon -fsc15 https://<host> -j <id1> <id2> <id3> ...
   ```
   (`-j` takes space-separated job IDs against one `-c15`-style host flag;
   don't invent flags the user hasn't specified — mirror the exact form
   they've asked for previously in the conversation if given one).
3. If asked for a GitHub-comment-ready version, reuse the same table with
   full `https://.../tests/<id>` links (or `openqa.suse.de/tNNN` shorthand)
   so it renders correctly outside the chat. Never post it to the PR/ticket
   without explicit confirmation — draft it, show it, wait for a clear
   "post it" before calling `gh pr comment` / `glab mr note` / Redmine
   update.

## Notes

- Plan-mode friendly: steps 0–2 are pure research and can be done entirely
  read-only, including the `-n` dry-run. Only Step 3 mutates anything.
- If the reported bug's job uses a TEST name you didn't expect from reading
  the code (e.g. the bug was filed against `publiccloud_slem_containers` but
  the diff's own author assumed `slem_basic`), trust the job's actual
  settings over assumptions from the diff — go verify by checking which
  `main_*.pm` branch loads the failing module under those exact settings.
- If the same class of fix also touches a shared/generic code path (e.g. a
  library used by both transactional and plain-zypper systems), ask whether
  the user wants coverage for the "other" path too (different product line,
  different provider) rather than assuming the original bug report's scope
  is the only thing worth verifying.
