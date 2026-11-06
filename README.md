# AI Dev Workflow Template

**Version:** 0.6.0 (pilot)  
Reusable, stack-independent workflow for **Claude Lead → Codex CLI** with selective Quality Gates and Learning Loop. Everyday low-risk work runs in a fast **VIBE mode**; heavier governance applies only when risk or scope demands it. Spec Kit and Superpowers are optional integrations when installed.

## Quick start (5 minutes)

1. **Use this template → Create a new repository**, then clone it. (On the source repo, enable **Settings → General → Template repository** first.)
2. Fill `AGENTS.md > Project Configuration` with your real stack, test/lint/build commands, protected paths and a fast **Quick check command** (lint + affected tests, under ~60s).
3. Check the configured project's bootstrap (no commands/models executed):

   ```bash
   bash scripts/validate-workflow.sh --project
   ```

   On this unconfigured source template the doctor intentionally fails; configure project fields first. Use `N/A` for genuinely inapplicable build/test/lint commands and `Protected paths: NONE` when no additional project paths need protecting.

4. Check the workflow offline (no model calls, no tokens):

   ```bash
   bash scripts/validate-workflow.sh
   bash scripts/test-guard-hook.sh
   bash scripts/test-auto-verify.sh
   bash scripts/test-codex-delegate.sh
   ```

5. Open Claude Code in the repo and just describe what you want. Claude first classifies complexity, risk and traceability; small, low-risk tasks then use **`/vibe`** automatically: change → run real tests → short PASS/FAIL report. Codex is optional for this mode.

## What runs when

| Task | Mode | What you get |
| --- | --- | --- |
| Small/medium, low risk, clear path (UI tweak, bug fix, small feature) | **VIBE** (`.claude/skills/vibe/`) | No plan or approval paperwork (Codex gets a short handoff); Claude handles qualifying SMALL changes with simple logic, Codex handles MEDIUM or larger work; real tests every step |
| Medium with ambiguity / Large, low risk | One Claude or Superpowers plan → Codex | Plan review, handoff, Codex run, independent review |
| Needs durable requirement ↔ decision ↔ test links | Spec Kit preferred | One canonical spec |
| **Any HIGH risk** (auth, money, financial methodology / point-in-time rules, personal data, destructive migration, infra, secrets, autonomous execution, project-defined) | **FULL GOVERNANCE** | Real human gates, independent checks, verified acceptance |

**Risk determines safeguards; complexity and traceability select the planning tool.** The full matrix, VIBE exit triggers and examples live in `docs/workflow/task-routing.md` (single source of truth). This template never relaxes a downstream project's mandatory gates.

## Guardrails built in

- `.claude/settings.json`:
  - a PreToolUse hook (`scripts/hooks/guard-protected-paths.sh`) **asks before** Claude's Edit/Write tools may change [protected paths](docs/workflow/project-setup.md#2-configure-each-project): the default core files and any paths configured in `AGENTS.md`. An Edit/Write that leaves content unchanged does not trigger this prompt. Paths are JSON-parsed and normalised (`..`, symlinks, case); unparseable input fails closed with a prompt. Bash commands get a **best-effort** check only.
  - `Read(...)` deny rules stop Claude's **Read tool** from opening `.env`/key files. They do not block other routes (Bash, scripts, other tools); keep real secrets out of the repo.
  - `git push`, `git reset --hard` and `rm -rf` always ask.
   - `Edit(./.workflow/**)` allows ignored handoffs and memory without repeated prompts. `acceptEdits` reduces routine edit confirmations. For LOW-risk/LOW-traceability initial Codex runs, only `Bash(bash scripts/codex-standard.sh:*)` is pre-allowed: it checks the route, the skill-selected model/effort, Quick check and runner integrity. **Never auto-allow unrestricted `codex-delegate.sh`**; HIGH-risk work, network access and material decisions still require authorization. `Status: APPROVED` alone never proves human consent.
  - a **Stop hook** (`scripts/hooks/auto-verify.sh`) runs `AGENTS.md > Quick check command` when Claude finishes a turn that changed files which have not passed yet (a `UserPromptSubmit` hook records the turn's starting point, so question-only turns on an already dirty tree do nothing). On failure Claude is sent back with only the last 40 lines of output (up to 3 attempts, then you are told). It skips unchanged states and does nothing until you configure the command. Disable per shell with `AUTO_VERIFY_DISABLE=1`. The command runs automatically on your machine, so review changes to `AGENTS.md` (especially in pull requests) as carefully as code.
  - This is an intent-confirmation layer for Claude, **not a security sandbox**; writes by Codex, scripts or editors are not intercepted (Codex runs get the wrapper's post-run check instead).
- `scripts/codex-delegate.sh`: clean-tree requirement for first runs, exact-tree follow-ups, lock, timeout, per-run logs and a post-run protected-path check for Codex.
- Host execution: the quick check, and tests Codex wrote, run on your machine outside the Codex sandbox. The wrapper skips the quick check when protected paths changed, and the auto-verify hooks skip while `AGENTS.md` or `scripts/hooks/` differ from HEAD. For untrusted input, run in an isolated environment or set `CODEX_QUICK_CHECK=0`. After a protected-path violation the wrapper runs no repository script (quick check and working-memory checkpoint are skipped), and the PreToolUse command asks instead of running `guard-protected-paths.sh` while it differs from HEAD. Residual risk: if Codex changes `.claude/settings.json` itself, Claude Code may use the changed hook commands; the wrapper reports exit 4, and a human must review before continuing.
- The tree snapshot hashes untracked files into the local `.git/objects` (unreferenced, never pushed, pruned by `git gc`). Keep sensitive files in `.gitignore`.
- Verification contract everywhere: PASS / FAIL / UNVERIFIED with real commands and exit codes.

## Delegation

Create `.workflow/handoffs/TASK-LOGIN-001.md` from `docs/workflow/handoff-template.md`. After genuine scope approval, put the exact `Status: APPROVED` under `## Approval status`. The marker is not proof of who approved the task.

```bash
bash scripts/codex-delegate.sh --dry-run TASK-LOGIN-001
bash scripts/codex-delegate.sh TASK-LOGIN-001
bash scripts/codex-delegate.sh --follow-up TASK-LOGIN-001 TASK-LOGIN-FIX-001
```

The second and third commands invoke actual Codex via `codex exec --sandbox workspace-write`. A follow-up requires the same HEAD and complete worktree tree left by the newest parent run; it reports only the new fix in `diff.patch`, while protected-path checks remain cumulative. The wrapper always passes `-c sandbox_workspace_write.network_access=false`, overriding `~/.codex/config.toml`; set `CODEX_NETWORK=1` only for a run that must install dependencies. It checks Git status and a worktree-wide lock, preserves the full prompt before invocation to avoid early-stdin SIGPIPE, records results/baselines under ignored `.workflow/handoffs/`, and detects changes to protected paths. It imposes a portable timeout (default 1800 seconds). It never commits, pushes, merges or deploys.

For existing projects, create `.workflow/` and move local scratch folders, for example `mv .claude/handoffs .workflow/handoffs`; do the same for `work-memory`, `experience-drafts` and `instinct-candidates` when present. Legacy handoffs and working-memory checkpoints still read with a deprecation warning.

A zero exit code is **not** acceptance: Claude must inspect Git diff, verification commands, acceptance criteria and protected-path warnings. Postchecks cannot prevent modifications, and interrupted child processes require inspection. The secret pattern scan is only a heuristic, not a substitute for dedicated security scanners.

## Project structure

- `CLAUDE.md` — Lead role and routing rules.
- `AGENTS.md` — implementation rules and project configuration.
- `.claude/skills/vibe/SKILL.md` — default fast loop for low-risk work.
- `.claude/settings.json` + `scripts/hooks/` — Claude Code permissions and protected-path hook.
- `docs/workflow/examples/` — a filled-in handoff example.
- `docs/workflow/pilot-checklist.md` — live Claude Code / Codex checks that offline tests cannot prove.
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

This creates a **private, ignored** draft in `.workflow/experience-drafts/`. It references `status.txt`, `changed-paths.txt`, the baseline Git SHA, and local logs **without copying full logs or prompts**. Record actual before/after tests and the precise workflow change (Git commit/PR) in the draft.

Once reviewed and approved, use `.claude/lessons/EXPERIENCE_TEMPLATE.md` for a concise, redacted permanent lesson and link it from `.claude/lessons/INDEX.md`. Store the changed harness as **Git commit + file paths**, not a duplicate configuration tree. Only validated and adopted lessons should direct future tasks. The index is read selectively to minimize context.

Offline checks:

```bash
bash scripts/test-capture-experience.sh
```

This is inspired by evidence-backed harness improvement; it is **not** the full Harness² recursive probing or automatic harness optimizer.

## Optional TokenEconomizer cost pilot (not installed)

[Microsoft TokenEconomizer](https://github.com/microsoft/TokenEconomizer) is an **optional, local experiment**, not a template dependency. The safe profile uses LLM-free environment facts, tool-pruning **proposals only**, and keeps the experimental loop guard **off** until explicitly enabled for a controlled fixture. It never relaxes Claude protected-path permissions, Codex sandbox/timeout, human approvals or real verification.

After inspecting/installing the upstream plugin on a disposable checkout, run `bash scripts/token-economizer-pilot.sh configure`; check `status` and use `TE_HOST=codex` for Codex-specific observations. No plugin, hooks, or models are installed or called by the helper. Run `bash scripts/test-token-economizer-pilot.sh` for offline contract tests. See [pilot instructions and rollback](docs/workflow/token-economizer-pilot.md) before enabling anything.

## ECC-inspired additions (v0.4.0, no new model)

The template now includes **low-cost patterns inspired by ECC** without installing ECC or the ECC runtime:

- **Working Memory:** `scripts/workflow-memory.sh` shares compact task state and per-run metadata between Claude and Codex in the **same local working copy**.
- **Verification:** `.claude/skills/verify-change/` adds a risk-based code review, linking actual tests and diff to acceptance criteria; it does not invoke a second planning process.
- **Learning:** `learn-from-task` may create unverified, ignored **instinct candidates** from meaningful failures. Only validated + user-approved experiences become adopted lessons.
- **Context:** save short task state before `/compact` or session transitions; reopen from `STATE.md` and Git evidence instead of rereading whole transcripts.

```bash
bash scripts/workflow-memory.sh init TASK-EXAMPLE-001
# Edit .workflow/work-memory/TASK-EXAMPLE-001/STATE.md with verified state/next action.
bash scripts/workflow-memory.sh show TASK-EXAMPLE-001
bash scripts/test-workflow-memory.sh
```

Run metadata is captured from `scripts/codex-delegate.sh` on a best-effort basis, without copying raw logs. `.workflow/work-memory/` and `.workflow/instinct-candidates/` are gitignored. **They do not sync between devices/clones automatically.** No hooks, observers, cron jobs or new API calls are enabled.

See `docs/workflow/ecc-selective-integration.md` for design, authority boundaries, limitations and acceptance scenarios. These additions do **not** make the harness an ECC Memory Vault installation.
