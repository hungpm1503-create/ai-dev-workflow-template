# AI Dev Workflow Template

**Version:** 0.5.0 (pilot)  
Reusable, stack-independent workflow for **Claude Lead → Codex CLI** with selective Quality Gates and Learning Loop. Everyday low-risk work runs in a fast **VIBE mode**; heavier governance applies only when risk or scope demands it. Spec Kit and Superpowers are optional integrations when installed.

## Quick start (5 minutes)

1. **Use this template → Create a new repository**, then clone it. (On the source repo, enable **Settings → General → Template repository** first.)
2. Fill `AGENTS.md > Project Configuration` with your real stack, test/lint/build commands and protected paths.
3. Check the workflow offline (no model calls, no tokens):

   ```bash
   bash scripts/validate-workflow.sh
   bash scripts/test-guard-hook.sh
   bash scripts/test-codex-delegate.sh
   ```

4. Open Claude Code in the repo and just describe what you want. Small, low-risk tasks use **`/vibe`** automatically: change → run real tests → short PASS/FAIL report. Codex is optional for this mode.

## What runs when

| Task | Mode | What you get |
| --- | --- | --- |
| Small/medium, low risk, clear path (UI tweak, bug fix, small feature) | **VIBE** (`.claude/skills/vibe/`) | No handoff/approval paperwork; real tests every step; optional local `wip:` checkpoints |
| Medium with ambiguity / Large, low risk | One Claude or Superpowers plan → Codex | Plan review, handoff, Codex run, independent review |
| Needs durable requirement ↔ decision ↔ test links | Spec Kit preferred | One canonical spec |
| **Any HIGH risk** (auth, money, personal data, destructive migration, infra, secrets) | **FULL GOVERNANCE** | Real human gates, independent checks, verified acceptance |

**Risk determines safeguards; complexity and traceability select the planning tool.** The full matrix, VIBE exit triggers and examples live in `docs/workflow/task-routing.md` (single source of truth). This template never relaxes a downstream project's mandatory gates.

## Guardrails built in

- `.claude/settings.json`: a PreToolUse hook (`scripts/hooks/guard-protected-paths.sh`) **asks before** Claude edits protected paths (`CLAUDE.md`, `AGENTS.md`, `.claude/`, workflows, plus your `AGENTS.md` list); `.env`/key files are unreadable; `git push`, `git reset --hard` and `rm -rf` always ask.
- `scripts/codex-delegate.sh`: clean-tree requirement, lock, timeout, per-run logs and a post-run protected-path check for Codex.
- Verification contract everywhere: PASS / FAIL / UNVERIFIED with real commands and exit codes.

## Delegation

Create `.claude/handoffs/TASK-LOGIN-001.md` from `docs/workflow/handoff-template.md`. After genuine scope approval, put the exact `Status: APPROVED` under `## Approval status`. The marker is not proof of who approved the task.

```bash
bash scripts/codex-delegate.sh --dry-run TASK-LOGIN-001
bash scripts/codex-delegate.sh TASK-LOGIN-001
```

The second command invokes actual Codex via `codex exec --sandbox workspace-write`. Add `CODEX_NETWORK=1` when the task needs package installs inside the sandbox (network stays off by default). It checks Git status and a worktree-wide lock, preserves the full prompt before invocation to avoid early-stdin SIGPIPE, records results/baselines under ignored `.claude/handoffs/`, and detects changes to protected paths. It imposes a portable timeout (default 1800 seconds). It never commits, pushes, merges or deploys.

A zero exit code is **not** acceptance: Claude must inspect Git diff, verification commands, acceptance criteria and protected-path warnings. Postchecks cannot prevent modifications, and interrupted child processes require inspection. The secret pattern scan is only a heuristic, not a substitute for dedicated security scanners.

## Project structure

- `CLAUDE.md` — Lead role and routing rules.
- `AGENTS.md` — implementation rules and project configuration.
- `.claude/skills/vibe/SKILL.md` — default fast loop for low-risk work.
- `.claude/settings.json` + `scripts/hooks/` — Claude Code permissions and protected-path hook.
- `docs/workflow/examples/` — a filled-in handoff example.
- `.claude/skills/plan-quality/SKILL.md` — PASS/WARNING/BLOCK review for Medium/Large.
- `.claude/skills/codex-delegate/SKILL.md` — approved handoff and safe Codex invocation.
- `.claude/skills/learn-from-task/SKILL.md` — evidence-based lessons.
- `.claude/lessons/INDEX.md` — project-local lesson index.
- `docs/workflow/` — project setup, handoff, evaluation templates.
- `scripts/` — wrapper and offline regression tests.
- `.github/workflows/validate-template.yml` — CI checks, no model invocation.

Existing repositories created from a GitHub template do not automatically receive changes from this source repository. See `docs/workflow/project-setup.md`.


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
