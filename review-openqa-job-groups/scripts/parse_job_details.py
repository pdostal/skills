#!/usr/bin/env python3
# Parse a saved get_job_details JSON dump (too large/truncated for direct tool output)
# and print failed modules with their failure text. Usage: parse_job_details.py <saved-file-path>
import json, sys

d = json.load(open(sys.argv[1]))
j = d.get("job", d)
for m in j.get("testresults", j.get("modules", [])):
    if m.get("result") == "failed":
        print("FAILED MODULE:", m.get("name"))
        for det in m.get("details", []):
            if det.get("resborder") != "resborder_ok":
                print(" ", det.get("title"), "|", (det.get("text_data") or "")[:400])
