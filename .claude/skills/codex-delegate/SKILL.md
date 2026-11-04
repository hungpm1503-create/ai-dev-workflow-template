---
name: codex-delegate
description: Delegate an approved task to Codex CLI using a unique ignored handoff and repository-local sandboxed wrapper; verify exit evidence, scope, clean tree and protected paths.
---

# Codex Delegation

## Tool ownership

- Codex is the implementation executor, including for Large features planned through Spec Kit. Never delegate implementation to `/speckit-implement` or `/speckit.implement`.
- Reference the **one approved planning source** chosen by Claude: concise Claude plan, Superpowers plan or canonical Spec Kit specification/plan. For HIGH risk also follow required independently approved governance artifacts. Do not create duplicate plans.
- Codex may use Superpowers for **TDD, systematic debugging and verification** when available. Claude may have used its brainstorming/writing-plans for planning; Codex does not repeat them or run competing subagent implementation/`executing-plans`.

1. Verify `codex` is installed and authenticated, and this Git repository has a clean worktree.
2. Confirm scope is approved. Material architecture, security, costs and irreversible operations still require explicit user approval.
3. Review the one canonical plan proportionately when needed; for ANY/HIGH, ensure required independent project review and human approval gates without duplicated reviews. For HIGH risk, send the user a plan of at most about 10 lines plus the approval question first; write the handoff only after approval. Use `docs/workflow/handoff-template.md`. Write `.workflow/handoffs/TASK-ID.md` with **## Approval status** and exact **Status: APPROVED**, only after appropriate approval. This text is not cryptographic authorization.
4. Verify `AGENTS.md > Protected paths` is configured for this project, if applicable.
5. Dry run: mandatory for FULL GOVERNANCE, optional for STANDARD: `bash scripts/codex-delegate.sh --dry-run TASK-ID` (no model invocation). The real run performs the same pre-invocation validation.
6. Execute only when permitted: `bash scripts/codex-delegate.sh TASK-ID`.
7. Inspect the ignored run directory: `prompt.md`, `completion.md`, `codex.log`, `status.txt`, Git baseline and changed-paths report. Review `git diff` independently.

The wrapper uses `codex exec --sandbox workspace-write --output-last-message ... -`. Handoffs and logs are gitignored, saved separately for every run. The wrapper blocks dirty worktrees and overlapping invocations, uses a portable time limit (default 1800 seconds; configure `CODEX_TIMEOUT_SECONDS`), passes `network_access=false` explicitly unless `CODEX_NETWORK=1`, and post-checks protected paths. Do not bypass the sandbox.

The wrapper runs the configured quick check after Codex unless `CODEX_QUICK_CHECK=0`; inspect its compact summary and `quick-check.log`. `CODEX_REASONING_EFFORT=medium` may be tried for MEDIUM, LOW-risk delegations to measure token savings later; HIGH-risk tasks keep the default/high effort. This is an option to measure, not a routing rule.

**Important:** A protected-path postcheck detects changes **after** they happen and cannot prevent their creation; it never auto-reverts user files. The text approval marker can be edited and is not an independently verified user authorization. The secret scanner is heuristic. A timed-out Codex child may require manual inspection. If Codex cannot run, return the handoff and mark execution UNVERIFIED.

Never auto-commit, push, merge or deploy. Never claim unrun tests passed.

## Before delegation

1. Inspect relevant files and confirm exact paths, types, APIs and project commands where practical.
2. Distinguish verified facts, assumptions and unknowns; raise consequential ambiguity or simpler viable approaches before approval.
3. Define scope, exclusions, constraints, observable acceptance criteria and proportionate verification evidence. Apply the Simplicity Ladder when shaping the handoff: is the work needed, can existing project code or patterns solve it, then standard library/native platform, then an installed dependency, then an obvious one-line solution, and only then minimum new code. Choose the first option that fully meets the criteria.
4. Require a minimal complete change: include affected callers, tests, fixtures, configuration and exports; preserve necessary validation, error handling, security and accessibility. Apply only the selected route's required planning/review; escalate HIGH-risk or unresolved critical blockers before delegation.
5. Reuse `docs/workflow/handoff-template.md`, referencing the one approved Claude, Superpowers or Spec Kit planning source rather than copying it.

## After delegation

1. Inspect Git diff, changed paths and actual command/test evidence; do not trust unsupported completion claims; confirm changed lines trace to approved scope.
2. Map acceptance criteria to PASS / FAIL / UNVERIFIED; skipped checks are UNVERIFIED.
3. If review finds a fix that itself fits implementer rule (1) and the task is not HIGH risk, Claude fixes it directly and re-verifies. Re-delegate only fixes beyond rule (1) or HIGH-risk fixes to preserve author/reviewer independence. Never re-delegate the whole task for a small fix.
4. Escalate material architectural changes, sensitive actions, destructive actions, and consequential business decisions to the user.
5. Trigger `/learn-from-task` selectively for meaningful Medium/Large findings, critical defects or repeated rework.
6. Do not treat one anomaly as proof of a systemic problem.
