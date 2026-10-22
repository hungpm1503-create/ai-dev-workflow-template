# AI Dev Workflow Template

**Version:** 0.1.0 (pilot)  
**Purpose:** reusable, stack-agnostic GitHub template for **Claude Lead → Codex Engineer**, with conditional Spec Kit/Superpowers, Planning Quality Gate and a lightweight learning loop.

> This repository stores **instructions and templates**, not the Claude CLI, Codex CLI, Spec Kit, Superpowers, or any model/API credentials. It does not silently install them.

## Workflow

| Task | Flow |
| --- | --- |
| Small | Claude → Codex → concise review |
| Medium | Claude plan → plan-quality → Codex + relevant Superpowers skills → review |
| Large | Claude → Spec Kit (if installed) → architecture/plan → plan-quality → Codex + relevant Superpowers skills → review |

**Approval:** business decisions, security/permission changes, destructive actions, major architecture or infrastructure changes go to the user. No automatic commit, push or merge.

## Included files

- `CLAUDE.md` — lead responsibilities and routing rules.
- `AGENTS.md` — implementation and verification rules for Codex.
- `.claude/skills/plan-quality/SKILL.md` — evidence-based plan gate.
- `.claude/skills/learn-from-task/SKILL.md` — selective post-task learning.
- `.claude/lessons/INDEX.md` — index for domain-specific lessons.
- `docs/workflow/handoff-template.md` — concise Claude → Codex contract.
- `docs/workflow/evaluation-template.md` — actual verification/quality signals.
- `docs/workflow/project-setup.md` — initialize a project from this template.
- `scripts/validate-workflow.sh` — non-destructive static checks.
- `scripts/publish-to-github.sh` — optional GitHub CLI publish helper.

## Bootstrap this template on GitHub

1. Create an **empty private GitHub repository** named `ai-dev-workflow-template` (do not initialize with README/license).
2. From the extracted folder, run:

   ```bash
   bash scripts/validate-workflow.sh
   git init -b main
   git add .
   git commit -m "chore: initial AI development workflow template"
   git remote add origin https://github.com/YOUR_USERNAME/ai-dev-workflow-template.git
   git push -u origin main
   ```

   Use an authenticated `gh` CLI / Git credential manager. Never paste tokens into the repository.
3. Open **Settings → General → Template repository** and enable it. Alternatively, use the optional `scripts/publish-to-github.sh` helper if `gh` is authenticated and the repository does **not** already exist.
4. For a new project, click **Use this template → Create a new repository**. Each project has its own Git history.

See official [GitHub template instructions](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository).

## Start a new project

1. Click **Use this template** to create a new repository.
2. Clone it and review `docs/workflow/project-setup.md`.
3. Check Claude Code and Codex CLI are installed/authenticated locally. For Large tasks, install/init Spec Kit **in the project** as needed. Verify Superpowers separately.
4. Customize project-specific technology, test commands, coding rules in existing instruction files **without erasing the shared workflow**.
5. Run `bash scripts/validate-workflow.sh`, then exercise one Small and one Medium task.

> Copying this template does not automatically update older projects after future template releases. Port adopted changes through reviewed PRs.

## Safety and limitations

- This is a **workflow baseline**, not a working Claude↔Codex automation bridge. Actual Codex invocation must be configured for the local environment, and agent handoffs must honor the user's approvals.
- Skills do not prove outcomes. Tests, builds, repository diffs and human review remain the source of verification.
- Do not store tokens, secrets, personal data or private business artifacts in the shared template.
- Lessons are project-local; promote a reusable rule to the template only after validation and review.
