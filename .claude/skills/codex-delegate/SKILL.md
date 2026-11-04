---
name: codex-delegate
description: Delegate an approved task to Codex CLI using a unique ignored handoff and repository-local sandboxed wrapper; verify exit evidence, scope, clean tree and protected paths.
---

# Codex Delegation

## Tool ownership

- Codex is the implementation executor, including for Large features planned through Spec Kit. Never delegate implementation to `/speckit-implement` or `/speckit.implement`.
- Reference the **one approved planning source** chosen by Claude: concise Claude plan, Superpowers plan or canonical Spec Kit specification/plan. For HIGH risk also follow required independently approved governance artifacts. Do not create duplicate plans.
- Codex may use Superpowers for **TDD, systematic debugging and verification** when available. Claude may have used its brainstorming/writing-plans for planning; Codex does not repeat them or run competing subagent implementation/`executing-plans`.

1. Verify `codex` is installed and authenticated, and this Git repository has a clean worktree (a `--follow-up` fix round instead needs the tree the previous round left).
2. Confirm scope is approved. Material architecture, security, costs and irreversible operations still require explicit user approval.
3. Review the one canonical plan proportionately when needed; for ANY/HIGH, ensure required independent project review and human approval gates without duplicated reviews. For HIGH risk, send the user a plan of at most about 10 lines plus the approval question first; write the handoff only after approval. Use the skeleton below. Do not open `docs/workflow/handoff-template.md` when this skeleton covers the route; open it only for FULL GOVERNANCE. Write `.workflow/handoffs/TASK-ID.md` with **## Approval status** and exact **Status: APPROVED**, only after appropriate approval. This text is not cryptographic authorization.
4. Verify `AGENTS.md > Protected paths` is configured for this project, if applicable.
5. Dry run: mandatory for FULL GOVERNANCE (except `--follow-up` fix rounds), optional for STANDARD: `bash scripts/codex-delegate.sh --dry-run TASK-ID` (no model invocation). The real run performs the same pre-invocation validation.
6. Execute only when permitted: for LOW-risk/LOW-traceability ordinary first runs, `bash scripts/codex-standard.sh TASK-ID` (auto-approved with a narrow rule); otherwise `bash scripts/codex-delegate.sh TASK-ID` with the applicable human approval.
7. Read the wrapper summary, then `diff.patch` once; that is the independent diff review. If the summary marks the diff `INCOMPLETE` (`DIFF_COMPLETE=0`), the patch lacks new files: read every new path listed in `changed-paths.txt` before mapping any criterion. Open `completion.md`, `quick-check.log` or `codex.log` only when the summary shows a non-zero exit, a failed quick check, a protected violation or missing acceptance-criteria lines.

The wrapper uses `codex exec --sandbox workspace-write --output-last-message ... -`. Handoffs and logs are gitignored, saved separately for every run. The wrapper blocks dirty worktrees and overlapping invocations, uses a portable time limit (default 1800 seconds; configure `CODEX_TIMEOUT_SECONDS`), passes `network_access=false` explicitly unless `CODEX_NETWORK=1`, and post-checks protected paths. Do not bypass the sandbox.

The wrapper runs the configured quick check after Codex unless `CODEX_QUICK_CHECK=0`; inspect its compact summary and `quick-check.log`. `Codex difficulty` is an explicit EASY/STANDARD/HARD routing dimension independent of complexity, risk and traceability. The wrapper selects `gpt-6-luna/medium`, `gpt-6-sol/medium`, or `gpt-6-sol/high` respectively (configurable via CODEX_MODEL_EASY/STANDARD/HARD, CODEX_MODEL and CODEX_REASONING_EFFORT); HIGH-risk may not be EASY. No LLM-based model router is used. For LOW-risk, LOW-traceability first runs, use the pre-approved `bash scripts/codex-standard.sh TASK-ID` entrypoint instead of requesting a separate Codex Bash approval; it fails closed for HIGH risk and disables network. For FULL GOVERNANCE or follow-ups, use `codex-delegate.sh`.

**Important:** A protected-path postcheck detects changes **after** they happen and cannot prevent their creation; it never auto-reverts user files. The text approval marker can be edited and is not an independently verified user authorization. The secret scanner is heuristic. A timed-out Codex child may require manual inspection. If Codex cannot run, return the handoff and mark execution UNVERIFIED.

Never auto-commit, push, merge or deploy. Never claim unrun tests passed.

## Before delegation

1. Inspect relevant files and confirm exact paths, types, APIs and project commands where practical.
2. Distinguish verified facts, assumptions and unknowns; raise consequential ambiguity or simpler viable approaches before approval.
3. Define scope, exclusions, constraints, observable acceptance criteria and proportionate verification evidence. Apply the Simplicity Ladder when shaping the handoff: is the work needed, can existing project code or patterns solve it, then standard library/native platform, then an installed dependency, then an obvious one-line solution, and only then minimum new code. Choose the first option that fully meets the criteria.
4. Require a minimal complete change: include affected callers, tests, fixtures, configuration and exports; preserve necessary validation, error handling, security and accessibility. Apply only the selected route's required planning/review; escalate HIGH-risk or unresolved critical blockers before delegation.
5. Reference the one approved Claude, Superpowers or Spec Kit planning source rather than copying it.

**Handoff skeleton** (write this directly; do not re-read the template for every task):

```markdown
## Task ID
TASK-<id>
## Route
- Complexity: SMALL / MEDIUM / LARGE
- Governance risk: LOW / HIGH
- Selected planning path: NONE / CLAUDE / SUPERPOWERS / SPEC KIT
- Governance: STANDARD / FULL GOVERNANCE
- Codex difficulty: EASY / STANDARD / HARD (implementation difficulty, independent of governance risk)
## Objective
<one observable result>
## Approval status
Status: APPROVED
## Files
- read: <exact paths>
- change: <exact paths>
- callers/consumers of every changed function or type (e.g. import, export or quote paths that pass the value through): <exact paths>
## Acceptance criteria and verification
| ID | Outcome | Command |
| --- | --- | --- |
| AC-01 | <outcome> | <command> |
## Constraints
- Out of scope: <list>
```

**FULL GOVERNANCE additions** (same sections as the full form in `docs/workflow/handoff-template.md`; write them from here instead of re-reading the template, and open the template only if a section's meaning is unclear):

```markdown
## Route (add to the lines above)
- Traceability: LOW / HIGH
- Single canonical source: <approved plan path or concise in-handoff plan>
- Required independent reviews and human approval evidence: <actual records or PENDING; never infer authorization>
## Verified context
<paths, symbols, project docs; label assumptions>
## Scope
- In scope: <modules/outcomes>
- Out of scope: <exclusions>
- Constraints: <architecture/security/backward compatibility>
## Implementation steps
1. <actionable step>
## Verification commands
<commands verified against the project, or UNVERIFIED>
## Escalation triggers
<missing requirements, unexpected scope, architectural/security changes, data loss>
## Completion contract
Codex reports changed files, each criterion PASS/FAIL/UNVERIFIED, commands with exit codes, failure excerpts and remaining risk. A zero CLI exit code does not prove the task passed.
```

Approval status stays `PENDING` until the human approves; only then set exactly `Status: APPROVED`. Money, auth and data-flow changes must list every caller path in `## Files`; a partial implementation found after Codex returns is costly to fix in Claude's own turns. Keep every section within the length limits there (about 2 KB total unless justified).

## After delegation

1. Inspect Git diff, changed paths and actual command/test evidence; do not trust unsupported completion claims; confirm changed lines trace to approved scope. On exit 4 (protected paths changed) review those files first and run no tests, quick check or project script until the user accepts them: they can run commands from the changed files on the host.
2. In headless or delegated runs, put each verification command in its own Bash call; do not chain them with `;` and `echo $?`, which the permission approver may deny and which costs an extra turn. Map acceptance criteria to PASS / FAIL / UNVERIFIED; skipped checks are UNVERIFIED. If the wrapper summary reports `Quick check: 0` (or `SKIPPED` with a reason) and the quick check covers the acceptance criteria, do not re-run lint or tests; review the diff and map the criteria from that evidence. Re-run only when the summary is missing or you change files afterwards.
3. Review fixes:
   - **HIGH-risk task: Claude never edits the code itself, however small the fix.** Do not touch the tree after the run. Write a short handoff `.workflow/handoffs/TASK-ID-fix-N.md` (finding, file and line, expected behaviour, the test that must prove it, a reference to the original approval) and run `bash scripts/codex-delegate.sh --follow-up <previous round's TASK-ID> TASK-ID-fix-N` (no dry-run needed). The wrapper refuses if anything changed since that round, and `diff.patch` then holds only the fix; review that diff. A fix handoff may stay only within the approved scope and files; anything new needs the human again. After 2 fix rounds, stop and report to the user. Claude stays the independent reviewer. Only if Codex is unavailable may Claude make the fix, and the report must then say `Fix <X> made by the reviewer: not independently reviewed; needs human review`.
   - Not HIGH risk and the fix fits implementer rule (1): Claude fixes it directly and runs the quick check once.
   - Otherwise re-delegate the fix only. Never re-delegate the whole task for a small fix.
4. Escalate material architectural changes, sensitive actions, destructive actions, and consequential business decisions to the user.
5. Trigger `/learn-from-task` selectively for meaningful Medium/Large findings, critical defects or repeated rework.
6. Do not treat one anomaly as proof of a systemic problem.
