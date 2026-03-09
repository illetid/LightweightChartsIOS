---
agent: agent
description: Implement a generated LightweightChartsIOS upgrade plan using the default Copilot agent.
tools: [read, search, edit, execute, todo]
---

Implement the upgrade plan for `${input:targetVersion}` using the default Copilot agent.

Inputs:
- Plan file path: `${input:planFile}`
  - If empty, use `IMPLEMENTATION_PLAN_<version>.md`.

Implementation rules:
- **Start by reading the plan file in full** before making any changes.
- Execute the plan phase-by-phase.
- Keep a running implementation tracker in `RECHECK_REPORT_<version>.md` — note any deviations from the plan with rationale. (The review agent will cross-reference this.)
- After protocol changes, update direct test mocks in `Example/Tests/Tests.swift`.
- After adding/removing files under `Sources/LightweightCharts/`, run:
  - `cd Example && pod install`
- Run build and tests at the end.

Output:
- List changed files grouped by phase.
- Note any deviations from the plan with rationale.
- Include build/test summary using authoritative XCTest lines.
