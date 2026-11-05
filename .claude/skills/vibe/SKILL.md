---
name: vibe
description: Fast build-run-adjust loop for SMALL/MEDIUM low-risk tasks - no handoff paperwork or approval marker, but real verification every step. Use for everyday feature tweaks, UI changes, bug fixes and prototypes.
---

# Vibe Mode

The default route for SMALL (and clear-path MEDIUM), LOW-risk, LOW-traceability work (see `CLAUDE.md`). Optimise for short loops; keep only the controls that catch real mistakes.

## 0. Gate check (one line, every task)

Classify complexity, governance risk and traceability independently, including the project's own rules; if unsure, read `docs/workflow/task-routing.md` first. Leave vibe mode and follow that routing if the request touches auth/permissions, payments or money, financial methodology or point-in-time rules, personal or sensitive data, destructive migrations or data deletion, infrastructure/deploy, secrets, autonomous execution, or anything the project's own rules (`AGENTS.md`, downstream governance) mark as HIGH risk, or grows into LARGE / HIGH-traceability work. Any HIGH risk → FULL GOVERNANCE.
Say which trigger fired. Otherwise state in one line how you read the request and who implements it (see 2).

## 1. Understand just enough

- Read only the files you will touch and their direct callers/tests.
- Use the Simplicity Ladder: reuse existing code → standard library → installed dependency → minimal new code. No new dependency without asking.
- Ask a question only when a wrong guess would be expensive to undo; otherwise pick the sensible default and mention it.

## 2. Who implements

**Implementer rule:** (1) Claude implements directly SMALL, LOW-risk changes — text/copy, styles, config values, or a local fix or small feature with simple logic in at most 3 source files (plus their tests), with no new module, schema, API or dependency. (2) Codex implements MEDIUM or larger work, anything beyond (1), and every HIGH-risk change, when Codex is installed. (3) If Codex is unavailable, Claude implements and says so. (4) Claude always reviews the diff and runs verification. An explicit user choice overrides (1)–(2).

### Codex handoff (minimal form)

Write `.workflow/handoffs/TASK-<short-id>.md`:

```markdown
## Task ID
TASK-<short-id>
## Route
- Complexity: SMALL
- Governance risk: LOW
- Traceability: LOW
- Codex model: <selected by codex-delegate skill>
- Codex reasoning effort: <selected by codex-delegate skill>
- Selected planning path: NONE (VIBE)
## Objective
<one observable result>
## Approval status
Status: APPROVED
## Files
- Read/change: <exact repository paths>
## Acceptance criteria and verification
- AC-01: <outcome> — <command>
```

`Status: APPROVED` here only records that the user asked for this LOW-risk change in the chat. Use the `codex-delegate` skill for model/effort selection and then run `bash scripts/codex-standard.sh TASK-<short-id>` for LOW-risk, LOW-traceability initial delegations without another confirmation; it refuses HIGH risk and missing model fields. The standard runner always disables network. For dependency installation or another network-dependent task, use the normal `codex-delegate.sh` path with explicit approval; do not use the auto-approved runner.
For STANDARD governance, a dry-run is optional; the real wrapper validates the same prerequisites before invoking Codex.

### If the worktree is dirty

The wrapper needs a clean tree so Codex's diff can be attributed. Never stash silently. Pick one and say which:

1. The pending edits are part of this task and verified → ask once to commit them locally, then run Codex.
2. The Codex slice is independent of the pending edits → run it in a separate worktree from `HEAD`:
   ```bash
   git worktree add ../"$(basename "$PWD")"-TASK-<id> -b vibe/TASK-<id>
   mkdir -p ../"$(basename "$PWD")"-TASK-<id>/.workflow/handoffs
   cp .workflow/handoffs/TASK-<id>.md ../"$(basename "$PWD")"-TASK-<id>/.workflow/handoffs/
   (cd ../"$(basename "$PWD")"-TASK-<id> && bash scripts/codex-delegate.sh TASK-<id>)
   ```
   Review that worktree's diff, then let the user decide how to bring it back (merge/cherry-pick) and remove the worktree.
3. The slice is small enough → Claude finishes it directly and says why.

## 3. Verify (never skipped)

- Run the real commands from `AGENTS.md > Project Configuration` that match the change (tests, typecheck/lint, build). If they are `[NOT CONFIGURED]`, detect the obvious project command (`package.json` scripts, `pytest`, `go test ./...`, etc.), run it, and suggest filling the configuration.
- For UI changes, run the app or a screenshot/preview when possible.
- Report in a few lines: what changed, commands + exit codes, each criterion PASS / FAIL / UNVERIFIED. A Codex exit code 0 is not PASS; read the diff.
- The Stop hook re-runs `Quick check command` automatically when you finish a turn that changed not-yet-passing files; treat its block message as the test result and fix from that excerpt instead of re-running everything.
- On failure: fix and re-run, at most 3 attempts on the same error, then stop and explain.

## 4. Commits

Do not ask about checkpoints by default. Offer one local commit only when the work is long and multi-step, before handing a dirty tree to Codex (see 2), or before a session handoff. Never push, merge or deploy.

## 5. When to stop vibing

- The same bug survives 3 fixes → write down state with `workflow-memory`, propose a short plan.
- Scope keeps expanding → summarise and suggest switching to a MEDIUM/LARGE plan.
- A gate trigger from step 0 appears mid-task → stop and say so.
