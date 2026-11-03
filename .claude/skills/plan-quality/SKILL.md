---
name: plan-quality
description: Review one canonical Claude, Superpowers or Spec Kit plan with risk-proportionate checks; never duplicate required independent high-risk gates.
---

# Planning Quality Gate

Review the **one canonical** plan (Claude, Superpowers or Spec Kit). For ANY/HIGH, honor independent FULL GOVERNANCE gates without pretending this skill is an independent reviewer. See `docs/workflow/task-routing.md`. Do not modify production code.

## Checks

For each applicable item, return **PASS**, **WARNING**, **BLOCK**, or **N/A**, plus short evidence.

1. **Facts versus assumptions:** verify referenced paths, symbols and commands; explicitly label uncertainty.
2. **Scope:** clear objective, deliverables, relevant exclusions, and no unapproved expansion.
3. **Architecture:** respects existing modules and conventions; new dependencies are justified.
4. **Order:** steps and prerequisites are actionable and appropriately sized.
5. **Acceptance criteria:** every material requirement has an observable outcome and verification method.
6. **Safety:** applicable edge cases, security, data integrity, compatibility and rollback risk considered.

## Decision

- **PASS:** no critical BLOCK items; any WARNING is recorded.
- **BLOCKED:** a critical failure prevents safe or correct implementation.
- Do not block for superficial documentation or irrelevant items.
- A checklist is an LLM review aid, not a deterministic proof of correctness.

## Behavior by route

- **SMALL/LOW/low traceability:** inline sanity check only; no formal plan-quality artifact.
- **MEDIUM/LOW/low traceability:** review one concise Claude plan, optionally clarified using Superpowers.
- **LARGE/LOW/low traceability:** review one canonical Superpowers design/plan or Claude plan; do not generate a competing plan.
- **HIGH traceability:** assess the existing canonical Spec Kit artifacts; no Superpowers planning duplicate.
- **ANY/HIGH risk:** required independent requirements/security checks and human approvals are mandatory under project FULL GOVERNANCE. This skill is only for an uncovered planning issue, never an additional ceremonial gate or a substitute for independent review.
- Do not invoke Superpowers subagent-driven implementation/`executing-plans` or `/speckit-implement`/`/speckit.implement` as implementation engines; Codex owns implementation.
- Revise a blocked plan only for a concrete blocker; at most two focused passes before escalating material decisions.
- Do not add another agent/model or package merely to satisfy an unnecessary gate.

## Output

- Gate decision: PASS / BLOCKED.
- Checklist: status and evidence for each item.
- Critical blockers and warnings.
- Exact corrections, if needed.
- Handoff derived from `docs/workflow/handoff-template.md` if PASS.
