# ECC-Inspired Integration — Low Cost, Project Local

This repository selectively adopts **ideas** from `affaan-m/ECC` (Continuous Learning v2.1, Unified Memory and Strategic Compact, Verification Loop). It **does not** install ECC, its observer, daemon, memory MCP/server or any new model. Everything below uses existing Claude/Codex sessions plus local scripts.

## Roles and truth hierarchy

| Layer | Contains | Storage | Authority |
| --- | --- | --- | --- |
| Working Memory | Current task progress, blockers, next action, verification references | Ignored `.claude/work-memory/TASK-ID/` | **Unreviewed context** |
| Instinct Candidate | One observed trigger/action hypothesis and evidence | Ignored `.claude/instinct-candidates/` | **Unverified proposal** |
| Experience Library | Tested, approved workflow lessons | Versioned `.claude/lessons/` | Reusable guidance, subordinate to project/spec/user |
| Canonical plan/decisions | Scope, approval, requirements, ADRs | Existing project artifacts | **Source of truth** |

## Working Memory: same-working-copy handoff

```bash
bash scripts/workflow-memory.sh init TASK-DEMO-001
# Edit .claude/work-memory/TASK-DEMO-001/STATE.md with concise verified facts
bash scripts/workflow-memory.sh show TASK-DEMO-001
bash scripts/workflow-memory.sh search "migration"
```

The wrapper calls `record-run` after Codex execution (best effort), creating an immutable-per-run metadata checkpoint. `STATE.md` can be edited by the Lead to track approved decisions, actual progress and the next action. Use STATE + LATEST to resume a task; then verify against the Git worktree, diff, tests and canonical plan. Records never prove human approval.

Memory is **local and ignored**. Two separate clones or cloud computers do not automatically share it. Use an explicitly reviewed/redacted artifact (for example PR/issue or team memory) if cross-machine continuity is necessary; do not commit ignored private memory just to sync it.

## Learning: observation without a background observer

- Existing `learn-from-task` examines meaningful test failures, rework and user corrections.
- If evidence suggests a repeatable pattern, draft **one** candidate using `.claude/lessons/INSTINCT_CANDIDATE_TEMPLATE.md`, saved under `.claude/instinct-candidates/`.
- Prefer linking to actual `capture-experience.sh` drafts, commit SHA and tests.
- Compare similar candidates; a confidence label counts observations but does not independently prove benefit.
- Review or reproduce the proposed change, then ask the user to promote a **validated** and **redacted** experience into `.claude/lessons/`.
- No perpetual observation hooks or autonomous LLM calls. This avoids the extra ongoing model usage of a background ECC observer.

## Verification and context management

For meaningful changes, `verify-change` reviews scope and evidence with actual project commands. Existing Codex sandbox/protected-path/exit-code controls remain in place. Run heavy tests only when relevant and available.

Before a phase transition or `/compact`, update `STATE.md`: confirmed facts, accepted decisions, last completed checks, blockers and next action. A new session starts from that concise checkpoint; it need not read entire model transcripts. Do not compact mid-task before saving critical state.

## Cost and privacy

- Script initialization, lexical search, metadata checkpoint and CLI validation perform **zero extra LLM calls**.
- Model tokens are consumed only when an **existing agent** reads useful memory or reviews/categorizes evidence. An additional agent is not started automatically.
- Do not copy secrets, raw prompts, private financial or customer data, receipts, complete logs or large transcripts into the shared state.
- Source documentation: `https://github.com/affaan-m/ECC` (ideas only; not an installed dependency).

## Real acceptance scenarios

1. Complete a small Codex handoff in a test project, then start a new Claude session and recover current status/next action from STATE.md + LATEST.md. Verify actual Git diff before marking PASS.
2. Introduce a repeatable sandbox/test failure in an isolated fixture, propose an instinct, compare it with an adopted lesson and **do not** promote without human approval and evidence.
3. Measure whether read-back reduces time/repeated file reads; no unsupported percentage/token-savings claims.
