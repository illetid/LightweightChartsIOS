---
agent: agent
description: End-to-end flow helper for plan -> implement -> review for LightweightChartsIOS upgrades.
tools: [read, search]
---

Guide the user through the standard upgrade workflow for `${input:targetVersion}`.

> **Note**: This is a manual runbook. Each step must be invoked separately by the user — prompts do not auto-chain.

Use this flow:

1. `/upgrade-plan` with target version.
   - **Produces**: `IMPLEMENTATION_PLAN_<version>.md`
   - **Done when**: Plan file exists and contains binding coverage audit + phased checklist.

2. `/upgrade-implement` with same version and generated plan file.
   - **Produces**: Implementation changes + `RECHECK_REPORT_<version>.md`
   - **Done when**: Build and tests pass; all plan phases addressed.

3. `/upgrade-review` with same version and plan file.
   - **Produces**: `UPGRADE_REVIEW_<version>.md`
   - **Done when**: Review report written with overall PASS/FAIL verdict.

For each step, output:
- Command to run next
- Expected output file
- Completion criteria

If a required file is missing, explicitly state what to generate first.

### Artifact Cleanup

After the upgrade is merged, these files should be removed from the repo:
- `IMPLEMENTATION_PLAN_<version>.md`
- `RECHECK_REPORT_<version>.md`
- `UPGRADE_REVIEW_<version>.md`
