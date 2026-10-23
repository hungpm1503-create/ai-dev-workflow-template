---
name: codex-delegate
description: Delegate an approved implementation task to the local Codex CLI using a repository-local, ignored handoff file and a sandboxed execution wrapper. Use after planning/quality gate, not for reviews or unapproved work.
---

# Codex Delegation

The **CLI bridge** is a local Bash wrapper, not an agent service, MCP server or model API. It does not install or authenticate Codex.

## Preconditions

1. Confirm a repository root and an approved task within the current Small/Medium/Large workflow.
2. Verify Codex CLI availability using `command -v codex`, and ensure the owner has authenticated Codex.
3. Check material approval boundaries, relevant AGENTS.md rules, and the plan-quality result for Medium/Large tasks.
4. Never execute tasks that require an unapproved architecture, security, cost, destructive or deployment change.

## Handoff

- For Medium/Large use `docs/workflow/handoff-template.md`; Small tasks may use a compact version.
- Create `.claude/handoffs/TASK-<unique>.md` inside the current repository. The directory is gitignored.
- Use a **unique task ID**, e.g. `TASK-LOGIN-001`; don't overwrite an in-progress handoff.
- Include exact scope, observable acceptance criteria and verified commands.
- Never place credentials in handoffs or logs.

## Invocation

```bash
bash scripts/codex-delegate.sh --dry-run TASK-LOGIN-001
bash scripts/codex-delegate.sh TASK-LOGIN-001
```

The wrapper uses `codex exec --sandbox workspace-write --output-last-message ... -`. It supplies the handoff on stdin, captures the last message and full log into a unique ignored `TASK-...-run.XXXXXX/` directory, and returns Codex's exit code. Every invocation has a separate run directory; do not reuse `latest.md`.

**Never use** `--dangerously-bypass-approvals-and-sandbox`, unrestricted `danger-full-access`, or automatic auth workarounds. Respect Claude's tool approval system. If local CLI access is unavailable, provide the handoff and report that execution is UNVERIFIED.

## Post-run review

- Read the wrapper's exit code and ignored completion report, not only the final chat text.
- Inspect `git diff` and executed build/test evidence independently.
- Mark acceptance criteria PASS / FAIL / UNVERIFIED.
- For fixes, update the scoped handoff or create a new task ID; previous run logs are retained.
- Do not automatically commit, push, merge or deploy.
