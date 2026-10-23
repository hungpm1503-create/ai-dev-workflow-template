# AI Dev Workflow Template

**Version:** 0.2.0 (pilot)  
A small, stack-independent GitHub template for **Claude Lead → Codex CLI** with Planning Quality Gate, selective Learning Loop and optional Spec Kit/Superpowers.

> These are project-level instructions and scripts, not a packaged Claude/Codex installation. Authenticate both CLIs separately. A real Codex run consumes your available model usage and can edit files.

## Workflow

| Task | Flow |
| --- | --- |
| Small | Claude → Codex → lightweight review |
| Medium | Claude plan → plan-quality → codex-delegate → review |
| Large | Claude → Spec Kit (if installed) → plan-quality → codex-delegate → review |

Superpowers skills can assist Codex implementation where installed and appropriate. Important architecture, business, security and destructive decisions still require user approval. No automatic commits, pushes, deployments or merges.

## Project files

- `CLAUDE.md` — Claude Lead routing, approval and delegation rules.
- `AGENTS.md` — Codex implementation rules and project-specific placeholders.
- `.claude/skills/plan-quality/SKILL.md` — plan checklist, blocks only critical issues.
- `.claude/skills/codex-delegate/SKILL.md` — Codex invocation procedure, sandbox constraints and output review.
- `.claude/skills/learn-from-task/SKILL.md` — evidence-based lessons (selective).
- `.claude/lessons/INDEX.md` — project-local lesson index.
- `docs/workflow/handoff-template.md` — per-task handoff contract.
- `docs/workflow/project-setup.md` — tool checks and project bootstrap.
- `docs/workflow/evaluation-template.md` — observable workflow metrics.
- `scripts/codex-delegate.sh` — Codex CLI execution with ignored, isolated per-run logs.
- `scripts/validate-workflow.sh` and `scripts/test-codex-delegate.sh` — offline structure and fake-Codex smoke tests.
- `.github/workflows/validate-template.yml` — CI validation for push and pull requests.

## New project

1. Choose **Use this template → Create a new repository** on GitHub.
2. Clone the new repo and run `bash scripts/validate-workflow.sh` and `bash scripts/test-codex-delegate.sh`.
3. Fill **Project Configuration** in `AGENTS.md` with real build/test/lint commands and protected paths.
4. Verify Claude Code, Codex CLI, and any Spec Kit/Superpowers integrations on your machine.
5. Run the first task; use `/plan-quality` for Medium/Large tasks when appropriate.

## Claude → Codex (approved task example)

After Claude prepares a handoff at `.claude/handoffs/TASK-LOGIN-001.md`:

```bash
bash scripts/codex-delegate.sh --dry-run TASK-LOGIN-001
bash scripts/codex-delegate.sh TASK-LOGIN-001
```

The second command **runs the model** using `codex exec --sandbox workspace-write`, reads the handoff from stdin, and stores `completion.md`, `codex.log` and `status.txt` in a unique ignored task run folder. Claude must verify the implementation diff and acceptance criteria; an exit code of zero alone is not acceptance.

Never use full-access sandbox bypasses. Do not pass API tokens in handoffs. The wrapper does not grant additional permission beyond your tool approval policy.

## Limitations

- This template does not automatically install or authenticate third-party skills, agents or CLIs.
- Codex execution needs a local Codex CLI and working model credentials; GitHub Actions uses a **fake** Codex only.
- Tests validate wrapper behavior and project files, not actual model quality.
- Commit reusable lessons back to the template only after evidence and review.
- Existing projects made from earlier versions do not update automatically.

See `docs/workflow/project-setup.md` for details.
