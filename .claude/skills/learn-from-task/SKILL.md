---
name: learn-from-task
description: After meaningful rework, failure or Medium/Large task completion, analyze evidence and propose small, testable workflow improvements without automatically changing global instructions.
---

# Selective Learning Loop

Use **Observe → Analyze → Propose → Validate → Adopt** only when the task contains a meaningful learning signal. Do not run after trivial Small tasks.

## Evidence to inspect

Original request, plan/handoff, implementation diff, acceptance criteria, executed tests and exit codes, user corrections and rework.

## Root-cause categories

Requirements ambiguity; planning/handoff defect; implementation defect; verification gap; tool/environment failure; external dependency; unknown/insufficient evidence. Multiple causes are allowed. Do not assign personal blame.

## Record a proposed lesson

Store only when there is a repeated pattern or critical blind spot. Use the relevant domain file under `.claude/lessons/` and add one index line to `.claude/lessons/INDEX.md` *if the user approves persisting the entry*. For an unapproved proposal, output in chat only.

Required fields: date, task/reference, observation, evidence, suspected cause, proposed rule, validation method, status (PROPOSED / VALIDATED / REJECTED).

## Promotion rule

- One-off mistakes are not permanent global rules.
- Validation should use relevant previous tasks, tests or objectively observable results where possible.
- Do not change `CLAUDE.md`, `AGENTS.md`, shared skills or template rules without approval.
- Read only relevant lessons; avoid loading the full history.
- No unbounded self-reflection or parallel probe loops.

## Output

Concise lessons (or "No reusable lesson"), supporting evidence, proposed next action, expected benefit, and approval required.
