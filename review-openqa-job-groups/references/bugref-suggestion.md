# Step 5 — suggest bugrefs for unreviewed failures (evidence-based only)

Never suggest a bugref purely because a "sibling" job (same test suite, different
arch/version) happens to already have one — verify first:

1. Pull `get_job_details` for the unreviewed job and find the actual failed module(s) and
   the failure text/backtrace (look at `details[]` entries where
   `resborder != "resborder_ok"`, e.g. `text_data` on a `Failed` step). For large/truncated
   responses, use `scripts/parse_job_details.py`.
2. If a candidate ticket exists (e.g. a sibling job in the same build/scenario carries a
   bugref), compare the failure signature — same failing module name, same error string —
   before reusing it. Different modules/errors mean it's a different bug even if the jobs
   look related.
3. If the candidate is a Redmine `poo#`/`jsc#` ticket, fetch it (`get_redmine_issue`) and
   check its description/scope (cloud provider, product version, scenario) and status. A
   **closed** ticket, or one scoped to a different provider/version than the failing job, is
   not a clean match — say so explicitly rather than asserting confidence.
4. If nothing matches, say plainly that no existing ticket covers it and a new one is likely
   needed — don't force a weak match just to fill a table cell.
