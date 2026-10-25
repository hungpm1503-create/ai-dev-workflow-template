# Workflow Evaluation — Project-local

Only log meaningful tasks or periodic samples. Do not invent metrics. Use `N/A` when unavailable.

| Date | Task | Size | Plan gate | First-pass ACs | Rework cycles | Tests | User interventions | Duration | Token/cost | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | [reference] | S/M/L | PASS/BLOCKED/N/A | X/Y or N/A | 0 | PASS/FAIL/UNVERIFIED | 0 | N/A | N/A | [evidence] |

## Evaluation discipline

- Compare comparable tasks; do not attribute all improvement to instruction changes.
- Always distinguish `UNVERIFIED` from `PASS`.
- Ask whether fewer rework cycles and clearer ACs offset review latency/token usage.
- Periodically consolidate lessons rather than appending global rules automatically.

## Evidence-backed lessons

For a meaningful correction, link to a reviewed `.claude/lessons/EXPERIENCE_TEMPLATE.md`-based record with its applicability cue, reproducible failure evidence, specific instruction/skill/script diff, and comparable after-test evidence. Use the recorded Git commit and CI run rather than copying raw agent logs. Keep the actual decision state (PROPOSED / VALIDATED / ADOPTED / REJECTED) separate from an implementation's exit status.
