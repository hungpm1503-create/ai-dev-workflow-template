# Workflow Evaluation — Project-local

Only log meaningful tasks or periodic samples. Do not invent metrics. Use `N/A` when unavailable.

| Date | Task | Size | Risk | Traceability | Planning path | Governance | Plan gate | First-pass ACs | Rework | Tests | Approvals | Time | Token/cost | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | [reference] | S/M/L | LOW/HIGH | LOW/HIGH | NONE/CLAUDE/SUPERPOWERS/SPEC KIT | STANDARD/FULL | PASS/BLOCKED/N/A | X/Y or N/A | 0 | PASS/FAIL/UNVERIFIED | N/A | N/A | N/A | [evidence] |

## Evaluation discipline

- Classify complexity, governance risk and traceability separately; record the single planning source and applicable project-specific approval controls using `docs/workflow/task-routing.md`.
- Compare comparable tasks; do not attribute all improvement to instruction changes.
- Always distinguish `UNVERIFIED` from `PASS`.
- Ask whether fewer rework cycles and clearer ACs offset review latency/token usage.
- Periodically consolidate lessons rather than appending global rules automatically.

## Evidence-backed lessons

For a meaningful correction, link to a reviewed `.claude/lessons/EXPERIENCE_TEMPLATE.md`-based record with its applicability cue, reproducible failure evidence, specific instruction/skill/script diff, and comparable after-test evidence. Use the recorded Git commit and CI run rather than copying raw agent logs. Keep the actual decision state (PROPOSED / VALIDATED / ADOPTED / REJECTED) separate from an implementation's exit status.
