---
name: plan-quality
description: Check Medium and Large task plans before delegation to Codex; find blockers, verify acceptance criteria, and avoid duplicate Spec Kit documents.
---

# Planning Quality Gate

Review a concrete Medium/Large task using relevant repository files and existing Spec Kit artifacts (when present). Do not modify production code.

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

## Behavior

- Small task: only a concise inline sanity check, no formal artifact.
- Medium task: one lightweight review and concise Codex handoff.
- Large task: check existing Spec Kit documents; link to them rather than copying them.
- Revise a blocked plan at most **two times**, then escalate unresolved decisions with clear options.
- Do not call another model/reviewer or install packages unless there is an explicit need and approval.

## Output

- Gate decision: PASS / BLOCKED.
- Checklist: status and evidence for each item.
- Critical blockers and warnings.
- Exact corrections, if needed.
- Handoff derived from `docs/workflow/handoff-template.md` if PASS.
