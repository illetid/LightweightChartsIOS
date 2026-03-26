---
agent: agent
description: Review an implemented upgrade against its plan and produce UPGRADE_REVIEW_<version>.md.
tools: [agent, read, search, execute, edit, todo]
---

Run a post-implementation review for `${input:targetVersion}`.

Requirements:
- Invoke the `Lightweight-charts upgrade-review` agent.
- Pass:
  - target version `${input:targetVersion}`
  - plan file `${input:planFile}` (or default `IMPLEMENTATION_PLAN_<version>.md`)
  - recheck report `RECHECK_REPORT_<version>.md` (if it exists)
- Produce a report file:
  - `UPGRADE_REVIEW_<version>.md`

After review, summarize:
- Overall result (`PASS`, `PASS WITH RISKS`, `FAIL`)
- High/medium findings count
- Whether build/tests passed
- Top recommended fixes (if any)
