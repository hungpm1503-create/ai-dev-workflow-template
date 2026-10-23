# AI Dev Workflow Template

**Version:** 0.2.0 (pilot, patched PR)  
Reusable, stack-independent workflow for **Claude Lead → Codex CLI** with selective Quality Gates and Learning Loop. Spec Kit and Superpowers are optional integrations when installed.

## Start a new project

Enable **Settings → General → Template repository** on the source repository if not already enabled. Select **Use this template → Create a new repository**. Clone the independent project, fill \`AGENTS.md > Project Configuration\` and verify Claude/Codex locally.

\`\`\`bash
bash scripts/validate-workflow.sh
bash scripts/test-secret-scan.sh
bash scripts/test-codex-delegate.sh
\`\`\`

No tests above call real Codex or bill tokens.

## Routing

- **Small:** Claude → Codex → lightweight review.
- **Medium:** Claude plan → \`plan-quality\` → \`codex-delegate\` → Claude review.
- **Large:** Claude + existing Spec Kit if configured → architecture/plan → \`plan-quality\` → \`codex-delegate\` → review.

Superpowers is reused only where available. This repository does not install CLIs, models or skills.

## Delegation

Create \`.claude/handoffs/TASK-LOGIN-001.md\` from \`docs/workflow/handoff-template.md\`. After genuine scope approval, put the exact \`Status: APPROVED\` under \`## Approval status\`. The marker is not proof of who approved the task.

\`\`\`bash
bash scripts/codex-delegate.sh --dry-run TASK-LOGIN-001
bash scripts/codex-delegate.sh TASK-LOGIN-001
\`\`\`

The second command invokes actual Codex via \`codex exec --sandbox workspace-write\`. It checks Git status and a worktree-wide lock, preserves the full prompt before invocation to avoid early-stdin SIGPIPE, records results/baselines under ignored \`.claude/handoffs/\`, and detects changes to protected paths. It imposes a portable timeout (default 1800 seconds). It never commits, pushes, merges or deploys.

A zero exit code is **not** acceptance: Claude must inspect Git diff, verification commands, acceptance criteria and protected-path warnings. Postchecks cannot prevent modifications, and interrupted child processes require inspection. The secret pattern scan is only a heuristic, not a substitute for dedicated security scanners.

## Project structure

- \`CLAUDE.md\` — Lead role and routing rules.
- \`AGENTS.md\` — implementation rules and project configuration.
- \`.claude/skills/plan-quality/SKILL.md\` — PASS/WARNING/BLOCK review for Medium/Large.
- \`.claude/skills/codex-delegate/SKILL.md\` — approved handoff and safe Codex invocation.
- \`.claude/skills/learn-from-task/SKILL.md\` — evidence-based lessons.
- \`.claude/lessons/INDEX.md\` — project-local lesson index.
- \`docs/workflow/\` — project setup, handoff, evaluation templates.
- \`scripts/\` — wrapper and offline regression tests.
- \`.github/workflows/validate-template.yml\` — CI checks, no model invocation.

Existing repositories created from a GitHub template do not automatically receive changes from this source repository. See \`docs/workflow/project-setup.md\`.
