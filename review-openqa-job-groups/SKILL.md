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

**Prefer delegating to the `openqa-ops` subagent** (`task` tool) to run the research/audit
in an isolated context. It must still return drafted bugref comments to you for explicit
user confirmation before anything gets posted (see Step 6) — that rule is unchanged.

Before the live steps below, check `references/fast-path-report.md` — a static
`openqa-ai-report` snapshot can often replace most of the manual per-job comment-checking.

## Step 1 — resolve group IDs

Take the job group IDs/names the user gives you. If only names are given,
resolve them via `list_job_groups` on the correct openQA instance (OSD:
`openqa.suse.de`, O3: `openqa.opensuse.org` — ask if ambiguous).

## Step 2 — find the TRUE highest build per group

Call `get_job_group_build_results(group_id, limit_builds=6)` — **don't rely on the
default/small limit**. Groups with `version_count > 1` (multiple SLE/product versions
sharing one group, e.g. SP4-SP7/16.0 under "Maintenance Images") interleave builds in the
response, so a small limit can hide older versions. If any row has `version_count > 1`,
raise `limit_builds` until every version's newest-build row is visible and at least one
version has "rolled over" to a lower build (proof the frontier is fully captured).

Take the single highest build number (numeric compare) across ALL rows. Keep only rows at
that build, regardless of product version; discard every lower-build row outright, even for
a still-actively-tested version — only the highest build in the whole group is in scope.

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

**Critical pitfall.** Batching `get_job_comments` across many job IDs in parallel has
produced misaligned results in practice: past ~4-5 items, the Nth response block didn't
reliably match the Nth job ID, causing wrong bugref numbers.

Rule: call `get_job_comments` **one job at a time** (or batches of 2-3, cross-checked
against the comment's own `id`/`created` timestamp — never trust positional order) whenever
there's more than a handful of failed jobs. Slower, but the only reliable way to avoid
attributing job A's comment to job B.

For each failed job, classify:
- **Reviewed** — has a comment (direct, or an automatic
  `label:linked:...` backlink) containing a `bsc#`, `boo#`, `poo#`, `jsc#`,
  GitHub PR URL, or GitLab MR URL.
- **Not reviewed** — no comment, or only comments with an empty `bugrefs`
  array and no recognizable ticket ID string anywhere in the text.

## Step 5 — suggest bugrefs for unreviewed failures

See `references/bugref-suggestion.md` — evidence-based only, never guess from a sibling job.

## Step 6 — report

Present one table per group reviewed, with these exact columns:

| openQA ID | Link | Short error summary | Suggested bugref | Bugref link |
|---|---|---|---|---|
| 23716040 | `https://openqa.suse.de/tests/23716040` | `azure_aitl: ConflictingConcurrentWriteNotAllowed on verify_hot_add_disk_serial_standard_ssd` | none found — needs new ticket | — |

- **openQA ID / Link** — plain job ID plus the full `https://<host>/tests/<id>` URL.
- **Short error summary** — one line from the actual failure text found in Step 5 (failed
  module + key error string), not generic "test failed."
- **Suggested bugref** — the verified `bsc#`/`boo#`/`poo#`/`jsc#`/PR/MR id, or "none found —
  needs new ticket" when nothing matches.
- **Bugref link** — direct clickable URL to that ticket/PR/MR, blank/`—` when none found.

Only rows classified "not reviewed" in Step 4 — don't pad the table with reviewed jobs.

**Never post a comment, tag, or ticket update to openQA/Redmine/Bugzilla/etc.
without explicit user confirmation first.** Draft the exact comment text,
show it, and wait for a clear go-ahead before calling any mutating tool
(`add_job_comment`, `create_redmine_issue`, etc.).

## Notes

- `get_job_details` responses can be large and get truncated by the tool output limit;
  parse the saved file with `scripts/parse_job_details.py <saved-file-path>` instead.
- The `reviewed` flag in `get_job_group_build_results` is openQA's own heuristic ("does
  every failed job have some comment"), not proof of policy compliance — always verify at
  job/comment level per Steps 3-5.
- A group can span multiple distros/products/versions at once; treat each `version`+`build`
  row as its own unit when finding "highest", but the highest-build-wins rule still applies
  across the whole group, not per version.

## Reference files

- `references/fast-path-report.md` — using `openqa-ai-report` snapshots to accelerate triage, and its coverage/freshness caveats.
- `references/bugref-suggestion.md` — Step 5 evidence-based bugref matching in full.
- `scripts/parse_job_details.py <saved-file-path>` — parses a truncated `get_job_details` dump.
