# AI Dev Workflow Template

**Version:** 0.4.0 (pilot)  
Reusable, stack-independent workflow for **Claude Lead → Codex CLI** with selective Quality Gates and Learning Loop. Spec Kit and Superpowers are optional integrations when installed.

## Start a new project

Enable **Settings → General → Template repository** on the source repository if not already enabled. Select **Use this template → Create a new repository**. Clone the independent project, fill \`AGENTS.md > Project Configuration\` and verify Claude/Codex locally.

\`\`\`bash
bash scripts/validate-workflow.sh
bash scripts/test-secret-scan.sh
bash scripts/test-codex-delegate.sh
\`\`\`

No tests above call real Codex or bill tokens.

## Adaptive workflow: Claude chooses NONE / Superpowers / Spec Kit

**Claude Lead → one planning path → Codex implementation → independent Claude review → human approval when needed.**

| Classification | Planning choice | Non-negotiable controls |
| --- | --- | --- |
| Small / Low-risk / low traceability | **NONE** | Concise handoff, tests, review |
| Medium / Low-risk / low traceability | Claude short plan, optionally Superpowers | One plan, proportionate review |
| Large / Low-risk / low traceability | **Superpowers preferred** for brainstorming/writing-plans (or one Claude plan) | Codex implements; Claude reviews |
| Any size / High traceability | **Spec Kit preferred** for requirements/decisions/tests links | One canonical spec/plan |
| **Any HIGH-risk task** | **FULL GOVERNANCE + selected tool** (only if allowed by project rules) | Real human gates, independent checks, verification and acceptance as required |

**Risk determines safeguards; complexity and traceability select the planning tool.** Superpowers may replace Spec Kit *planning* when the task does not need persistent requirements traceability. Do not run both for the same plan, and do not activate Superpowers subagent implementation or Spec Kit implementation alongside Codex. Superpowers TDD/debugging/verification can still assist Codex.

**HIGH-risk does not universally imply Spec Kit**, but downstream policies may require it. Existing InvestmentAgent financial HIGH-risk Spec Kit gates remain mandatory until separately approved changes; this template does not modify those rules.

See `docs/workflow/task-routing.md` for the full matrix and examples. Working Memory, verification and evidence-based learning v0.4 remain unchanged.

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


## Evidence-based Experience Library

After meaningful failures, rework, or a critical workflow gap, Claude can use the existing `learn-from-task` skill to capture evidence and propose a reusable improvement. No task-by-task auto-learning or model retraining is implied.

For a completed delegated run:

```bash
# Replace XXXXXX with the exact suffix printed by codex-delegate
bash scripts/capture-experience.sh TASK-LOGIN-001 TASK-LOGIN-001-run.XXXXXX
```

This creates a **private, ignored** draft in `.claude/experience-drafts/`. It references `status.txt`, `changed-paths.txt`, the baseline Git SHA, and local logs **without copying full logs or prompts**. Record actual before/after tests and the precise workflow change (Git commit/PR) in the draft.

Once reviewed and approved, use `.claude/lessons/EXPERIENCE_TEMPLATE.md` for a concise, redacted permanent lesson and link it from `.claude/lessons/INDEX.md`. Store the changed harness as **Git commit + file paths**, not a duplicate configuration tree. Only validated and adopted lessons should direct future tasks. The index is read selectively to minimize context.

Offline checks:

```bash
bash scripts/test-capture-experience.sh
```

This is inspired by evidence-backed harness improvement; it is **not** the full Harness² recursive probing or automatic harness optimizer.

## ECC-inspired additions (v0.4.0, no new model)

The template now includes **low-cost patterns inspired by ECC** without installing ECC or the ECC runtime:

- **Working Memory:** `scripts/workflow-memory.sh` shares compact task state and per-run metadata between Claude and Codex in the **same local working copy**.
- **Verification:** `.claude/skills/verify-change/` adds a risk-based code review, linking actual tests and diff to acceptance criteria; it does not invoke a second planning process.
- **Learning:** `learn-from-task` may create unverified, ignored **instinct candidates** from meaningful failures. Only validated + user-approved experiences become adopted lessons.
- **Context:** save short task state before `/compact` or session transitions; reopen from `STATE.md` and Git evidence instead of rereading whole transcripts.

```bash
bash scripts/workflow-memory.sh init TASK-EXAMPLE-001
# Edit .claude/work-memory/TASK-EXAMPLE-001/STATE.md with verified state/next action.
bash scripts/workflow-memory.sh show TASK-EXAMPLE-001
bash scripts/test-workflow-memory.sh
```

Run metadata is captured from `scripts/codex-delegate.sh` on a best-effort basis, without copying raw logs. `.claude/work-memory/` and `.claude/instinct-candidates/` are gitignored. **They do not sync between devices/clones automatically.** No hooks, observers, cron jobs or new API calls are enabled.

See `docs/workflow/ecc-selective-integration.md` for design, authority boundaries, limitations and acceptance scenarios. These additions do **not** make the harness an ECC Memory Vault installation.
