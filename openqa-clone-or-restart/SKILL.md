---
name: openqa-clone-or-restart
description: >
  Use when the user provides an openQA tests overview URL, a test suite name,
  and an openqa-clone-job or openqa-cli command template containing $JOB_ID,
  and wants a ready-to-run list of commands with all job IDs substituted in.
  Triggers on phrases like "clone jobs", "restart jobs", "openqa-clone-job",
  "openqa-cli", "re-run jobs", "requeue jobs", "re-trigger tests",
  "retry failing tests", "clone failing jobs", "openQA jobs",
  "openQA overview", or when a tests/overview URL is given alongside a suite name.
---

# openQA clone or restart jobs skill

**Prefer delegating to the `openqa-ops` subagent** (`task` tool) — this skill is pure
research/templating (no mutation), a good fit to keep out of the main thread.

## Inputs

The user provides:

1. An openQA tests overview URL, e.g.:
   `https://openqa.suse.de/tests/overview?distri=sle&version=15-SP7&build=20260614-1&groupid=427`
2. A test suite name, e.g. `publiccloud_migration`
3. A command template with `$JOB_ID` as the placeholder for the job ID, e.g.:
   ```
   openqa-clone-job --host myhost.example.org --from openqa.suse.de $JOB_ID --skip-deps FOO=bar
   ```

## Step 1 — derive the API call

Parse the overview URL to extract:
- `host` — the URL hostname, e.g. `openqa.suse.de`
- `distri`, `version`, `build`, `groupid` — the query string parameters

Construct and fetch the following URL using WebFetch (text or JSON format):

```
https://<host>/api/v1/jobs?distri=<distri>&version=<version>&build=<build>&groupid=<groupid>&test=<suite>&latest=1
```

If the response is truncated, use the Task tool with an explore agent to grep
the saved output file for `"id":` and `"FLAVOR":` / `"ARCH":` / `"result":`.

## Step 2 — parse the response

From each job object in `jobs[]` extract:
- `id` — the numeric job ID
- `settings.FLAVOR` — e.g. `EC2-BYOS-Updates`
- `settings.ARCH` — e.g. `x86_64`
- `result` — e.g. `failed`, `passed`, `softfailed`

## Step 3 — output

For every job, substitute `$JOB_ID` in the user's template with the actual
numeric job ID. Print the result as a compact list, one command per job, with
a single-line comment describing the job:

```
# <FLAVOR> / <ARCH> / <result>
<command with job ID substituted>
```

Group by version/distri if multiple overview URLs were given.

---

## Command variants

Two template shapes are supported: `openqa-clone-job` and `openqa-cli`. See
`references/command-variants.md` for exact syntax, flag handling, and examples of each.

---

## Notes

- Always fetch **all** jobs matching the suite (`latest=1`), regardless of result.
- If there are multiple overview URLs (different `version` or `distri`), process
  each separately and label the groups clearly in the output.
- Keep the output list short and copy-paste ready — no extra prose between commands.
