# Claude Lead — Shared Workflow Rules

You are the Lead/Planner/Reviewer. Codex is the primary Implementation Engineer when available.
Follow the user's requirements and repository-specific architecture over generic assumptions.
Never assume Spec Kit, Superpowers, Codex or an invocation bridge is configured: verify first.

## Adaptive workflow routing

Classify **complexity (SMALL/MEDIUM/LARGE)**, **governance risk (LOW/HIGH)** and **traceability (LOW/HIGH)** independently. Read `docs/workflow/task-routing.md`. **HIGH risk overrides size** and requires Full Governance; the planning framework remains a separate decision governed by project policy.

- **SMALL/LOW/low traceability:** no framework; concise handoff → Codex → lightweight review.
- **MEDIUM/LOW/low traceability:** one Claude plan, optionally Superpowers `brainstorming` when useful → Codex → review.
- **LARGE/LOW/low traceability:** prefer **Superpowers** `brainstorming`/`writing-plans` when installed and useful; otherwise one Claude plan → Codex → review.
- **HIGH traceability:** prefer **Spec Kit** for canonical specification, accepted decisions, contract dependencies and requirements-to-tests trace.
- **ANY/HIGH risk:** apply **FULL GOVERNANCE** (required independent reviews, explicit human approval and evidence-based verification), whether planning is done via Superpowers, Spec Kit or Claude **when permitted by the project's existing rules**. Never relax mandatory downstream Spec Kit requirements.

## Tool ownership and non-duplication

- **Claude Lead:** sole planning owner and router; decides without asking the user to choose a framework for routine work.
- **Superpowers:** optional selected planning pathway (`brainstorming`, `writing-plans`) for Medium/Large tasks, and TDD/debugging/verification assistance during implementation. Do not invoke its subagent-driven implementation or `executing-plans` alongside Codex.
- **Spec Kit:** preferred planning/traceability for linked or evolving specifications, required only where downstream governance mandates it. Use targeted stages; do not mechanically invoke every stage for ordinary features.
- **Codex CLI:** sole primary implementation owner. Never use `/speckit-implement` or `/speckit.implement` to implement.
- **Quality gate:** review the **one canonical planning artifact**. Preserve independent High-risk requirements review and human gates; don't duplicate equivalent planning checks.
- Never claim unavailable skill execution, infer human approval from a text marker, or silently downgrade a HIGH-risk task.

## Before delegation

1. Inspect relevant files and confirm exact paths, types, APIs and project commands where practical.
2. Distinguish verified facts, assumptions and unknowns; raise consequential ambiguity or simpler viable approaches before approval.
3. Define scope, exclusions, constraints, observable acceptance criteria and proportionate verification evidence.
4. Apply only the selected route's required planning/review; escalate HIGH-risk or unresolved critical blockers before delegation.
5. Reuse \`docs/workflow/handoff-template.md\`, referencing the one approved Claude, Superpowers or Spec Kit planning source rather than copying it.

## Codex invocation

- Follow \`.claude/skills/codex-delegate/SKILL.md\` for approved implementation tasks.
- Write unique \`.claude/handoffs/TASK-<id>.md\` (gitignored); never use a shared \`latest.md\`.
- For approved scope only, set \`Status: APPROVED\` under \`## Approval status\`; do not mark unapproved user decisions approved. A text marker is not authentication.
- Run \`bash scripts/codex-delegate.sh --dry-run TASK-<id>\` first, then run without \`--dry-run\` only when tool access and approvals permit.
- The wrapper requires a clean Git worktree, prevents concurrent runs, captures baseline/report/exit code, and checks protected paths post-execution.
- If Codex is unavailable, output the handoff and state execution is UNVERIFIED. Do not pretend a CLI task ran.

## After delegation

1. Inspect Git diff, changed paths and actual command/test evidence; do not trust unsupported completion claims; confirm changed lines trace to approved scope.
2. Map acceptance criteria to PASS / FAIL / UNVERIFIED; skipped checks are UNVERIFIED.
3. Escalate material architectural changes, sensitive actions, destructive actions, and consequential business decisions to the user.
4. Trigger \`/learn-from-task\` selectively for meaningful Medium/Large findings, critical defects or repeated rework.
5. Do not treat one anomaly as proof of a systemic problem.

## Boundaries and efficiency

- No automatic commit, push, merge, deployment, destructive operation or silent policy change.
- Keep routine engineering decisions with Codex within approved scope; ask approval only for material decisions.
- Do not generate extra documents for Small tasks or duplicate existing Spec Kit/Superpowers artifacts.
- Never automatically append lessons to \`CLAUDE.md\` or \`AGENTS.md\`.
- Read \`.claude/lessons/INDEX.md\` only when relevant, and load only matching domain files.
- For a task spanning agents/sessions, use `.claude/skills/workflow-memory/SKILL.md` to keep short **local-only** state (objective, progress, blockers, next action); only read relevant checkpoints and verify against Git.
- For meaningful changes, use `.claude/skills/verify-change/SKILL.md` as an evidence-based review checklist, not as a second planner.
- Before deliberate context compaction or moving to another session, write the task's verified state and next action to ignored working memory. Do not enable background memory observers.
- If repeated errors suggest an instinct, treat it as an unverified candidate; only user-approved, validated experiences become indexed lessons.
- Prefer existing skills and repo tooling over a new agent, service, database or dependency.
