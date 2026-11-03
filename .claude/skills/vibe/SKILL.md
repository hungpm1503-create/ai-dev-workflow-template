---
name: vibe
description: Fast build-run-adjust loop for SMALL/MEDIUM low-risk tasks - no handoff file or approval marker, but real verification every step. Use for everyday feature tweaks, UI changes, bug fixes and prototypes.
---

# Vibe Mode

The default route for SMALL/MEDIUM, LOW-risk, LOW-traceability work (see `CLAUDE.md`). Optimise for short loops; keep only the controls that catch real mistakes.

## 0. Gate check (one line, every task)

Leave vibe mode and follow the normal routing in `docs/workflow/task-routing.md` if the request touches any of:
auth/permissions, payments/money, personal or sensitive data, destructive migration or data deletion, infrastructure/deploy/CI, secrets, or grows into LARGE / HIGH-traceability work.
Say which trigger fired. Otherwise state in one line how you read the request and continue.

## 1. Understand just enough

- Read only the files you will touch and their direct callers/tests.
- Use the Simplicity Ladder: reuse existing code → standard library → installed dependency → minimal new code. No new dependency without asking.
- Ask a question only when a wrong guess would be expensive to undo; otherwise pick the sensible default and mention it.

## 2. Make the change

Pick one:

- **Claude edits directly** (default for quick changes).
- **Codex implements** (user prefers Codex, or the slice is mechanical/large): write a minimal handoff to `.claude/handoffs/TASK-<short-id>.md`:

  ```markdown
  ## Task ID
  TASK-<short-id>
  ## Route
  - Complexity: SMALL
  - Governance risk: LOW
  - Traceability: LOW
  - Selected planning path: NONE (VIBE)
  ## Objective
  <one observable result>
  ## Approval status
  Status: APPROVED
  ## Acceptance criteria and verification
  - AC-01: <outcome> — <command>
  ```

  `Status: APPROVED` here only records that the user asked for this LOW-risk change in the chat. Then run `bash scripts/codex-delegate.sh TASK-<short-id>`.
  The wrapper needs a clean worktree: if it is dirty, offer a `wip:` checkpoint commit (see 4) instead of stashing silently.
  If the task needs `npm install`/`pip install` inside Codex's sandbox, run with `CODEX_NETWORK=1`.

## 3. Verify (never skipped)

- Run the real commands from `AGENTS.md > Project Configuration` that match the change (tests, typecheck/lint, build). If they are `[NOT CONFIGURED]`, detect the obvious project command (`package.json` scripts, `pytest`, `go test ./...`, etc.), run it, and suggest filling the configuration.
- For UI changes, run the app or a screenshot/preview when possible.
- Report in a few lines: what changed, commands + exit codes, each criterion PASS / FAIL / UNVERIFIED. A Codex exit code 0 is not PASS; read the diff.
- On failure: fix and re-run, at most 3 attempts on the same error, then stop and explain.

## 4. Checkpoints (opt-in)

On the first verified step of a session, ask once: "Commit verified steps locally as `wip:` checkpoints?" If yes, commit after each verified step. Never push, merge or deploy. Suggest squashing `wip:` commits before opening a PR.

## 5. When to stop vibing

- The same bug survives 3 fixes → write down state with `workflow-memory`, propose a short plan.
- Scope keeps expanding → summarise and suggest switching to a MEDIUM/LARGE plan.
- A gate trigger from step 0 appears mid-task → stop and say so.
