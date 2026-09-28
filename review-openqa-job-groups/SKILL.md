---
name: review-openqa-job-groups
description: >
  Use when the user asks to review openQA job groups against a "latest
  build" reviewer policy — e.g. "review OSD Public Cloud", "check if job
  groups are reviewed", "audit the latest build for failures", "reviewer
  role", or gives job group IDs/names plus a rule like "green or softfail
  is fine, failed needs a bug/PR/MR/progress-ticket comment". Covers
  finding the true latest build per group (including groups with multiple
  product versions on independent build counters), fetching only-latest
  job results, verifying comments job-by-job without batching pitfalls,
  and suggesting bugrefs backed by evidence.
---

# Review openQA job groups (latest-build policy)

## Reviewer policy (typical)

- Passed / softfailed jobs in the latest build = reviewed, no action needed.
- Failed jobs must carry a comment linking a bugzilla reference (`bsc#`,
  `boo#`), a GitHub PR, a GitLab MR, or a valid progress ticket (`poo#`,
  `jsc#`) describing the issue.
- Automatic system comments of the form `label:linked:poo#NNNNN mentions
  this job` (empty `bugrefs` array but a ticket ID present in the text) DO
  count as satisfying this — treat them as reviewed, no need for a
  redundant duplicate comment.
- Only the highest build number is in scope. Ignore everything from a lower
  build entirely — including whole product-version rows within the same
  group that just haven't caught up yet.

Confirm the exact wording of the policy with the user if it isn't given
explicitly; the above is the common case, not a hardcoded rule.

## Optional fast path — check `openqa-ai-report` first

Before doing the full live grind below (Steps 1-6), check whether a static
`openqa-groups --json-output` snapshot already exists for the relevant
groups/instance via the `openqa-ai-report` MCP — it can replace most of the
manual per-job comment-checking:

1. `list_reports()` — see what report snapshots exist and when each was
   `generated`.
2. `get_report(source)` — pulls the summary: `job_groups` covered,
   `job_count`, the `known_bugs` catalog, and any `error_jobs`.
3. `list_jobs(source, has_bugref=False, status=["failed","incomplete"])`
   (the `openqa-ai-report` version, distinct from the live `openqa` one used
   elsewhere in this skill) — jumps straight to unreviewed failures instead
   of walking every job group's build results and checking comments one by
   one.
4. `group_failures_by_signature(source)` — clusters jobs sharing an
   identical (module, analysis text) signature, which is exactly the
   "same root cause across many jobs" check Step 5 asks for, done
   server-side instead of by hand.

### Critical caveat: verify coverage before trusting a report

A report's `job_groups` list can be a **subset** of the groups actually in
scope — in practice, a report named after a squad/product area covered
barely a third of that area's real job groups (missing most image-build
variants), while still reporting plausible-looking `job_count` totals for
what it did cover. **A low or zero `job_count` for a group is not proof that
group is clean — it may mean the report doesn't track that group at all.**

Before treating any group as "reviewed via report":
- Confirm the group's ID actually appears in `get_report()`'s `job_groups`
  list.
- For any in-scope group *not* clearly listed there, fall back to the live
  workflow (Steps 1-6) for that group — never assume it's clean just because
  the report is silent on it.

### Freshness caveat

Reports are static snapshots (`generated` timestamp), not live data — openQA
build results can change within minutes (retries, new builds, merged fixes
landing). Use the report purely as a triage/acceleration aid; prefer the
live tools for anything time-sensitive, for confirming a specific finding
before reporting it, or when the report is more than a few hours old.

If a group is genuinely not covered by any report, or no report exists at
all for the instance, proceed directly with the live Steps 1-6 below.

## Step 1 — resolve group IDs

Take the job group IDs/names the user gives you. If only names are given,
resolve them via `list_job_groups` on the correct openQA instance (OSD:
`openqa.suse.de`, O3: `openqa.opensuse.org` — ask if ambiguous).

## Step 2 — find the TRUE highest build per group

Call `get_job_group_build_results(group_id, limit_builds=6)` — **do not
rely on the default/small limit**. Groups with `version_count > 1` (multiple
SLE/product versions sharing one job group, e.g. SP4/SP5/SP6/SP7/16.0 all
under one "Maintenance Images" group) interleave their builds in the
response; a small `limit_builds` can silently hide older-numbered versions
and give an incomplete picture. If any returned row has `version_count > 1`,
keep raising `limit_builds` until you can see every version's row at what
you believe is the newest build, and until you've seen at least one version
"roll over" to a lower build number (proof you've captured the full
frontier, not just a truncated window).

Determine the single highest build number (numeric compare) across ALL rows
in the group. Keep only rows whose `build` equals that highest number,
regardless of which product version they belong to. Discard every row with
a lower build number outright, even if it belongs to a different, still
actively-tested product version — per policy, only the highest build number
in the whole group is in scope.

## Step 3 — get the actual failed jobs, not the aggregate counts

The aggregate `failed` / `softfailed` / `comments` counts returned by
`get_job_group_build_results` can be stale or simply not match reality
job-for-job. Always fetch the concrete job list instead of trusting the
aggregate:

```
list_jobs(groupid=<id>, build=<highest_build>, result="failed", latest=1)
```

`latest=1` is mandatory — without it, superseded/restarted jobs from earlier
clone chains under the same build number are also returned, inflating the
failure count with jobs that are no longer "the" result for that scenario.

## Step 4 — check every failed job's comments — ONE AT A TIME

**This is the critical pitfall of this workflow.** Firing `get_job_comments`
for many job IDs in a single parallel tool-call batch has produced
misaligned results in practice: past roughly 4-5 items in one batch, the
Nth response block did not reliably correspond to the Nth job ID once
matched back up manually, causing wrong bugref numbers to be reported.

Rule: call `get_job_comments` for **one job at a time** (or batches no
larger than 2-3, cross-checked against a unique field in the response — the
comment's own `id` and `created` timestamp — never trust positional/array
order alone) whenever there is more than a handful of failed jobs to check.
It is slower but the only reliable way to avoid attributing job A's comment
to job B.

For each failed job, classify:
- **Reviewed** — has a comment (direct, or an automatic
  `label:linked:...` backlink) containing a `bsc#`, `boo#`, `poo#`, `jsc#`,
  GitHub PR URL, or GitLab MR URL.
- **Not reviewed** — no comment, or only comments with an empty `bugrefs`
  array and no recognizable ticket ID string anywhere in the text.

## Step 5 — suggest bugrefs for unreviewed failures (evidence-based only)

Never suggest a bugref purely because a "sibling" job (same test suite,
different arch/version) happens to already have one — verify first:

1. Pull `get_job_details` for the unreviewed job and find the actual failed
   module(s) and the failure text/backtrace (look at `details[]` entries
   where `resborder != "resborder_ok"`, e.g. `text_data` on a `Failed` step).
2. If a candidate ticket exists (e.g. a sibling job in the same build/scenario
   carries a bugref), compare the failure signature — same failing module
   name, same error string — before reusing it. Different modules/errors
   mean it's a different bug even if the jobs look related.
3. If the candidate is a Redmine `poo#`/`jsc#` ticket, fetch it
   (`get_redmine_issue`) and check its description/scope (cloud provider,
   product version, scenario) and status. A **closed** ticket, or one scoped
   to a different provider/version than the failing job, is not a clean
   match — say so explicitly rather than asserting confidence.
4. If nothing matches, say plainly that no existing ticket covers it and a
   new one is likely needed — don't force a weak match just to fill a table
   cell.

## Step 6 — report

Present one table per group reviewed, with these exact columns:

| openQA ID | Link | Short error summary | Suggested bugref | Bugref link |
|---|---|---|---|---|
| 23716040 | `https://openqa.suse.de/tests/23716040` | `azure_aitl: ConflictingConcurrentWriteNotAllowed on verify_hot_add_disk_serial_standard_ssd` | none found — needs new ticket | — |

- **openQA ID / Link** — plain job ID plus the full `https://<host>/tests/<id>` URL.
- **Short error summary** — one line pulled from the actual failure text
  found in Step 5 (failed module name + the key error string), not a
  generic "test failed."
- **Suggested bugref** — the verified `bsc#`/`boo#`/`poo#`/`jsc#`/PR/MR id,
  or an explicit "none found — needs new ticket" when nothing matches.
- **Bugref link** — direct clickable URL to that ticket/PR/MR
  (`https://bugzilla.suse.com/show_bug.cgi?id=...`,
  `https://progress.opensuse.org/issues/...`, or the GitHub/GitLab PR/MR
  URL). Leave blank/`—` when no bugref was found.

Only include rows for jobs classified "not reviewed" in Step 4 — don't pad
the table with already-reviewed jobs.

**Never post a comment, tag, or ticket update to openQA/Redmine/Bugzilla/etc.
without explicit user confirmation first.** Draft the exact comment text,
show it, and wait for a clear go-ahead before calling any mutating tool
(`add_job_comment`, `create_redmine_issue`, etc.).

## Notes

- `get_job_details` responses can be very large (100s of KB to several MB)
  and often get truncated by the tool output limit. When that happens, the
  tool call result includes a path to a saved file — parse that file with a
  small Python/jq snippet instead of trying to read the raw dump:
  ```python
  import json
  d = json.load(open("<saved-file-path>"))
  j = d.get("job", d)
  for m in j.get("testresults", j.get("modules", [])):
      if m.get("result") == "failed":
          print("FAILED MODULE:", m.get("name"))
          for det in m.get("details", []):
              if det.get("resborder") != "resborder_ok":
                  print(" ", det.get("title"), "|", (det.get("text_data") or "")[:400])
  ```
- The `reviewed` flag inside `get_job_group_build_results` is a heuristic
  openQA computes itself (roughly: "does every failed job have some
  comment"), not proof of actual policy compliance. Always verify at the
  job/comment level per Steps 3-5 — don't shortcut on the aggregate flag.
- A group can span multiple distros/products (`distris` field) and multiple
  versions (`version_count`) simultaneously; treat every distinct
  `version`+`build` row as its own unit when deciding what's "highest",
  but the final "only highest build number wins" rule applies across the
  whole group, not per version.
- If `openqa-ai-report` is available, check it first per the fast-path
  section above — but never trust its silence on a group as proof of
  cleanliness without confirming that group is actually in its coverage.
