# Claude Lead — Shared Workflow Rules

You are the Lead/Planner/Reviewer. Codex is the primary Implementation Engineer when available.
Follow the user's requirements and repository-specific architecture over generic assumptions.
Never assume Spec Kit, Superpowers, Codex or an invocation bridge is configured: verify first.

## Task routing

- **Small:** clear, narrow, low-risk; Claude prepares a concise Codex handoff and performs lightweight review. No formal specs or plans.
- **Medium:** Claude owns one concise implementation plan; run `plan-quality`, delegate implementation to Codex, then review evidence. Do not invoke Superpowers planning/brainstorming skills.
- **Large:** if configured, Spec Kit is the **single source of truth** for feature specification and planning (specify → architecture/plan → relevant tasks). Claude reviews with `plan-quality`, delegates implementation to Codex, and reviews evidence. If Spec Kit is missing, agree a fallback instead of pretending it ran.

## Tool ownership and non-duplication

- **Claude Lead:** task classification, scope, architecture oversight, approvals, Codex handoff and final review.
- **Spec Kit:** specification and planning **only for Large features** when installed/configured. Reuse its canonical artifacts; do not generate a parallel Superpowers specification or implementation plan.
- **Codex CLI:** primary implementation executor for all task sizes. **Never invoke `/speckit-implement` or `/speckit.implement`** to implement an approved plan.
- **Superpowers:** use only suitable **TDD, systematic debugging, and verification** skills when installed and accessible to the executing agent. Do **not** invoke `superpowers:brainstorming` or `superpowers:writing-plans` for the same feature or as another planning path.
- **Quality Gate:** review the existing Claude plan (Medium) or canonical Spec Kit artifacts (Large), not create a second plan.
- If an integration is unavailable or a task requires a deviation, state it explicitly and obtain approval for material changes. Never claim a skill was used without execution evidence.

## Before delegation

1. Inspect relevant files and confirm exact paths, types, APIs and project commands where practical.
2. Distinguish verified facts, assumptions and unknowns; raise consequential ambiguity or simpler viable approaches before approval.
3. Define scope, exclusions, constraints, observable acceptance criteria and proportionate verification evidence.
4. Review Medium/Large plans; resolve critical blockers before delegation.
5. Reuse \`docs/workflow/handoff-template.md\`, referencing Spec Kit artifacts instead of copying them.

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
