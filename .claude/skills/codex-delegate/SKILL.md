---
name: codex-delegate
description: Delegate an approved task to Codex CLI using a unique ignored handoff and repository-local sandboxed wrapper; verify exit evidence, scope, clean tree and protected paths.
---

# Codex Delegation

Metrics are recorded by opt-in hooks when `WORKFLOW_METRICS=1`; do not invoke metrics commands during normal tasks.

## Tool ownership

- Codex is the implementation executor, including for Large features planned through Spec Kit. Never delegate implementation to `/speckit-implement` or `/speckit.implement`.
- Reference the **one approved planning source** chosen by Claude: concise Claude plan, Superpowers plan or canonical Spec Kit specification/plan. For HIGH risk also follow required independently approved governance artifacts. Do not create duplicate plans.
- Codex may use Superpowers for **TDD, systematic debugging and verification** when available. Claude may have used its brainstorming/writing-plans for planning; Codex does not repeat them or run competing subagent implementation/`executing-plans`.

1. Verify `codex` is installed and authenticated, and this Git repository has a clean worktree (a `--follow-up` fix round instead needs the tree the previous round left).
2. Confirm scope is approved. Material architecture, security, costs and irreversible operations still require explicit user approval.
3. Apply HIGH-risk approval and review gates from `CLAUDE.md §1` and `docs/workflow/task-routing.md`. Reuse genuine approval for the exact scope; otherwise request consequential decisions once. Write the handoff with `Status: APPROVED` only after appropriate approval (the marker is not authentication). Read the full handoff template only for FULL GOVERNANCE.
4. Verify `AGENTS.md > Protected paths` is configured for this project, if applicable.
5. Dry run: mandatory for FULL GOVERNANCE (except `--follow-up` fix rounds), optional for STANDARD: `bash scripts/codex-delegate.sh --dry-run TASK-ID` (no model invocation). The real run performs the same pre-invocation validation.
6. Execute only when permitted: use `bash scripts/codex-standard.sh TASK-ID` for LOW-risk/LOW-traceability initial runs; for HIGH risk, follow-ups or network-dependent work use `bash scripts/codex-delegate.sh TASK-ID` with the applicable approval.
7. Read the wrapper summary, then `diff.patch` once; that is the independent diff review. If the summary marks the diff `INCOMPLETE` (`DIFF_COMPLETE=0`), the patch lacks new files: read every new path listed in `changed-paths.txt` before mapping any criterion. Open `completion.md`, `quick-check.log` or `codex.log` only when the summary shows a non-zero exit, a failed quick check, a protected violation or missing acceptance-criteria lines.

The wrapper uses `codex exec --sandbox workspace-write --output-last-message ... -`. Handoffs and logs are gitignored, saved separately for every run. The wrapper blocks dirty worktrees and overlapping invocations, uses a portable time limit (default 1800 seconds; configure `CODEX_TIMEOUT_SECONDS`), passes `network_access=false` explicitly unless `CODEX_NETWORK=1`, and post-checks protected paths. Do not bypass the sandbox.

The wrapper runs the configured quick check after Codex unless `CODEX_QUICK_CHECK=0`; inspect its compact summary and `quick-check.log`. Model choice is handled in **Model selection** below, not in this wrapper.

**Important:** A protected-path postcheck detects changes **after** they happen and cannot prevent their creation; it never auto-reverts user files. The text approval marker can be edited and is not an independently verified user authorization. The secret scanner is heuristic. A timed-out Codex child may require manual inspection. If Codex cannot run, return the handoff and mark execution UNVERIFIED.

Follow `CLAUDE.md §3–4` for evidence and authorization boundaries; unchecked criteria remain UNVERIFIED.

## Model selection

When delegating, choose the model and reasoning effort from the task's actual complexity and risk, without a separate classifier call:

| Task type | Model | Reasoning effort |
| --- | --- | --- |
| HARD — Complex tasks or high data/PIT risk | `AGENTS.md` Codex model (hard / review) | `high` |
| STANDARD — Moderate tasks with established patterns | `AGENTS.md` Codex model (standard / small fix) | `high` |
| SMALL FIX — Minor follow-up fixes or test corrections | `AGENTS.md` Codex model (standard / small fix) | `medium` |
| INDEPENDENT REVIEW — Separate, read-only review | `AGENTS.md` Codex model (hard / review) | `medium` |

Read the two Codex model lines in `AGENTS.md > Project Configuration` when delegating; if either line is missing or `[NOT CONFIGURED]`, ask the user rather than guessing.

For implementation, choose a supported model ID. For **LOW-risk / LOW-traceability initial runs**, record `Codex model` and `Codex reasoning effort` in the handoff's `## Route`, then invoke `bash scripts/codex-standard.sh TASK-ID`; it validates and forwards the selected model/effort. For other runs invoke `CODEX_MODEL=<model-id> CODEX_REASONING_EFFORT=<effort> bash scripts/codex-delegate.sh TASK-ID`; insert `--dry-run` before TASK-ID when required. For independent Codex review, use a separate read-only session with the hard / review model from `AGENTS.md` and `medium` effort; do not use the implementation wrapper or allow the reviewer to modify code. The skill owns the selection, while the wrapper only validates and forwards the two optional environment variables (unset values preserve legacy CLI defaults). HIGH-risk data/PIT work, including its fixes, uses the HARD profile regardless of diff size. Other HIGH-governance tasks must follow their required approvals and independent review gates; never downgrade them just because the change is small.

## Before delegation

1. Inspect relevant files and confirm exact paths, types, APIs and project commands where practical.
2. Distinguish verified facts, assumptions and unknowns; raise consequential ambiguity or simpler viable approaches before approval.
3. Define scope, exclusions, constraints, observable acceptance criteria and verification evidence; follow the Simplicity Ladder in `CLAUDE.md §4` without adding a competing plan.
4. Require a minimal complete change: include affected callers, tests, fixtures, configuration and exports; preserve necessary validation, error handling, security and accessibility. Apply only the selected route's required planning/review; escalate HIGH-risk or unresolved critical blockers before delegation.
5. Reference the one approved Claude, Superpowers or Spec Kit planning source rather than copying it.

**Handoff skeleton** (write this directly; do not re-read the template for every task):

```markdown
## Task ID
TASK-<id>
## Route
- Complexity: SMALL / MEDIUM / LARGE
- Governance risk: LOW / HIGH
- Traceability: LOW / HIGH
- Codex model: <supported model ID selected by this skill>
- Codex reasoning effort: <minimal / low / medium / high / xhigh>
- Selected planning path: NONE / CLAUDE / SUPERPOWERS / SPEC KIT
- Governance: STANDARD / FULL GOVERNANCE
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
2. Follow `CLAUDE.md §3` for PASS/FAIL/UNVERIFIED evidence and avoid duplicate checks already passed on the same tree. In headless runs, issue each verification command as its own Bash call (not chained); only re-run when new changes or missing evidence require it.
3. Review fixes:
   - **HIGH-risk task:** Follow `CLAUDE.md §2`: Codex implements fixes and Claude independently reviews. Do not edit the tree after the run. Write a focused `.workflow/handoffs/TASK-ID-fix-N.md` citing the finding, expected behavior, test and original approval, then invoke `bash scripts/codex-delegate.sh --follow-up <parent TASK-ID> TASK-ID-fix-N` (no dry-run). The wrapper checks the exact parent tree; any new scope requires approval. After two fix rounds, stop and report. If Codex is unavailable and Claude must fix, mark the fix not independently reviewed.
   - Not HIGH risk and the fix fits implementer rule (1): Claude fixes it directly and runs the quick check once.
   - Otherwise re-delegate the fix only. Never re-delegate the whole task for a small fix.
4. Escalate material decisions and sensitive actions per `CLAUDE.md §4`.
5. Trigger `/learn-from-task` selectively for meaningful Medium/Large findings, critical defects or repeated rework.
6. Do not treat one anomaly as proof of a systemic problem.
