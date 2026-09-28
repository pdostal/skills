# Optional fast path — check `openqa-ai-report` first

Before doing the full live grind (Steps 1-6 in the main SKILL.md), check whether a static
`openqa-groups --json-output` snapshot already exists for the relevant groups/instance via
the `openqa-ai-report` MCP — it can replace most of the manual per-job comment-checking:

1. `list_reports()` — see what report snapshots exist and when each was `generated`.
2. `get_report(source)` — pulls the summary: `job_groups` covered, `job_count`, the
   `known_bugs` catalog, and any `error_jobs`.
3. `list_jobs(source, has_bugref=False, status=["failed","incomplete"])` (the
   `openqa-ai-report` version, distinct from the live `openqa` one used elsewhere in this
   skill) — jumps straight to unreviewed failures instead of walking every job group's
   build results and checking comments one by one.
4. `group_failures_by_signature(source)` — clusters jobs sharing an identical (module,
   analysis text) signature, which is exactly the "same root cause across many jobs" check
   Step 5 asks for, done server-side instead of by hand.

## Critical caveat: verify coverage before trusting a report

A report's `job_groups` list can be a **subset** of the groups actually in scope — in
practice, a report named after a squad/product area covered barely a third of that area's
real job groups (missing most image-build variants), while still reporting plausible-looking
`job_count` totals for what it did cover. **A low or zero `job_count` for a group is not
proof that group is clean — it may mean the report doesn't track that group at all.**

Before treating any group as "reviewed via report":
- Confirm the group's ID actually appears in `get_report()`'s `job_groups` list.
- For any in-scope group *not* clearly listed there, fall back to the live workflow
  (Steps 1-6) for that group — never assume it's clean just because the report is silent
  on it.

## Freshness caveat

Reports are static snapshots (`generated` timestamp), not live data — openQA build results
can change within minutes (retries, new builds, merged fixes landing). Use the report purely
as a triage/acceleration aid; prefer the live tools for anything time-sensitive, for
confirming a specific finding before reporting it, or when the report is more than a few
hours old.

If a group is genuinely not covered by any report, or no report exists at all for the
instance, proceed directly with the live Steps 1-6.
