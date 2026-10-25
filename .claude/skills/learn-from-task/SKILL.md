---
name: learn-from-task
description: Selectively identify recurring development failures or critical blind spots, capture real execution evidence, validate small workflow improvements and propose human-approved experience records.
---

# Evidence-Based Experience Learning

This is a lightweight **Observe → Analyze → Propose → Validate → Adopt** process, not a Harness² recursive search or automatic self-modifying agent.

## Trigger

Use after meaningful Medium/Large tasks or significant rework, user correction, failed verification or a critical issue. Skip routine Small tasks and cases with no reusable lesson.

## Observe / evidence

1. Compare requirements, existing plan and handoff against observed implementation.
2. Inspect **real** results: Codex `status.txt`, `completion.md`, `changed-paths.txt`, `head-before.txt`, `git diff`, executed tests and reviewer findings.
3. If available, prepare a **private draft**, without copying raw model output:

   ```bash
   bash scripts/capture-experience.sh TASK-EXAMPLE-001 TASK-EXAMPLE-001-run.XXXXXX
   ```

   Replace `XXXXXX` with the run folder's actual suffix. The output stays in `.claude/experience-drafts/` (ignored) and must be reviewed before sharing.
4. A wrapper exit code 0 is **not** an acceptance criterion PASS; missing results remain UNVERIFIED.

## Analyze / propose

- Root-cause categories: requirements, planning/handoff, implementation, verification, environment/tooling, external dependency, unknown.
- Identify a repeated pattern or critical blind spot; single minor incidents do not create permanent rules.
- Describe the **cue**, observed failure, hypothesis, **before behavior**, minimal proposed workflow change, expected improvement and possible cost.
- Prefer reuse of existing skills and documentation; avoid new agent/database/automatic probe loops.

## Validate

- Run relevant regression or comparable tasks only when safe and approved.
- Record **before/after** results, commands, exit codes and durable references (Git SHA/PR/CI), or explicitly UNVERIFIED.
- Track which specific `CLAUDE.md`, `AGENTS.md`, skill, template or script change caused the improvement **as a hypothesis unless validated**.
- Reconstruct harness configuration from Git SHA + changed file paths rather than storing another full copy.
- Separate task success from workflow improvement and do not infer causality from one pass.

## Adopt (requires user approval)

- Use `.claude/lessons/EXPERIENCE_TEMPLATE.md` for a concise, **redacted** persistent record after review.
- States: DRAFT (ignored) → PROPOSED → VALIDATED → ADOPTED, or REJECTED/RETIRED.
- Only ADOPTED records provide reusable guidance in `.claude/lessons/INDEX.md`.
- Never auto-update `CLAUDE.md`, `AGENTS.md` or skills. Approval and validation are required before permanent instruction changes.
- Do not commit ignored raw handoffs, prompts, logs, passwords or personal data. Cite immutable code/CI references when available.

## Output

Cue, concrete evidence, hypothesis, proposed change, before/after validation, limits, current state and a clear approval request. If no reusable learning signal exists, say so and stop.
