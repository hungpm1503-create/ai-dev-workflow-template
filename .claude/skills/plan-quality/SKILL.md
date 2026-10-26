---
name: plan-quality
description: Proportionately review the single canonical Medium/Low or Spec Lite plan and fill only uncovered quality gaps in a required High-risk route.
---

# Planning Quality Gate

Review the **single canonical** plan/spec for MEDIUM/LOW or LARGE/LOW; for ANY/HIGH, honor the project's independent high-risk review gates and avoid re-running equivalent checks. See `docs/workflow/task-routing.md`. Do not modify production code.

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

- **SMALL/LOW:** brief inline sanity check only; no formal `plan-quality` execution or extra artifact.
- **MEDIUM/LOW:** review **one** concise Claude-owned plan, which may be part of the handoff. Do not create a second plan or a full Spec Kit chain.
- **LARGE/LOW (Spec Lite):** review **one canonical requirements/design artifact**, whether a short project document or an existing Spec Kit artifact. Use only missing and genuinely useful Spec Kit stages, not every stage by default.
- **ANY/HIGH:** comply with the project's formal requirements review, approvals and consistency checks; this skill can check a **specific uncovered issue**, not act as an additional mandatory ceremony.
- Do not invoke `superpowers:brainstorming`, `superpowers:writing-plans`, `/speckit-implement`, or `/speckit.implement` in this workflow.
- Revise a blocked plan at most **two times**, then escalate unresolved decisions with clear options.
- Do not call another model/reviewer or install packages unless there is an explicit need and approval.

## Output

- Gate decision: PASS / BLOCKED.
- Checklist: status and evidence for each item.
- Critical blockers and warnings.
- Exact corrections, if needed.
- Handoff derived from `docs/workflow/handoff-template.md` if PASS.
