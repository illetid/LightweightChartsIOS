---
agent: agent
description: Generate an upgrade implementation plan using the Lightweight-charts updater agent.
tools: [agent, read, search, execute, edit]
---

Generate an upgrade plan for LightweightChartsIOS for `${input:targetVersion}` by invoking the `Lightweight-charts updater` agent.

Requirements:
- Use the agent name exactly: `Lightweight-charts updater`.
- Ask it to produce `IMPLEMENTATION_PLAN_<version>.md` at repository root.
- Ensure the plan includes:
  - Overview
  - Binding coverage audit
  - Changed APIs/models
  - Example app additions
  - Step-by-step phases
  - Potential gotchas

When done, summarize:
- Plan file path
- Whether JS asset rebuild is required
- Top 5 implementation tasks
