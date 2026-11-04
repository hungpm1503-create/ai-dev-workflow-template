# Initialize a Project from This Template

## 1. Check local tools

```bash
git --version
claude --version
codex --version
```

Install and authenticate Claude and Codex separately. This template does not install models, Spec Kit or Superpowers. If using Spec Kit, initialize carefully and inspect generated artifacts; do not force-overwrite project config. Verify Superpowers is installed before referring to its skills.

## Tool ownership — one planner, one implementer

Routing rules live in `docs/workflow/task-routing.md`; don't duplicate them here. In short: everyday LOW-risk work uses **VIBE mode**; Medium/Large use one Claude/Superpowers/Spec Kit plan with Codex implementing; **ANY/HIGH risk** keeps mandatory FULL GOVERNANCE, including Project-required approvals and independent checks. Never silently downgrade HIGH risk.

## 2. Configure each project

Fill `AGENTS.md > Project Configuration`: actual stack, build/test/lint commands and protected paths. Protected paths are **literal repository-relative paths**, comma-separated, e.g. `src/config/, infrastructure/`. Directories end in `/`. The wrapper also protects `CLAUDE.md`, `AGENTS.md`, `scripts/codex-delegate.sh`, `scripts/codex-standard.sh`, `scripts/workflow-memory.sh`, `scripts/hooks/`, `.claude/settings.json`, `.claude/skills/` and `.github/workflows/` by default. For Codex this is a **post-run detector**; for Claude Code the hook in `.claude/settings.json` asks *before* Edit/Write tool calls (best-effort for Bash). Neither is a file-system access control boundary.

Set **Quick check command** to something fast (lint + affected tests, ideally under 60 seconds). The Claude Code Stop hook runs it automatically after a turn that changed not-yet-passing files and sends Claude back to fix failures, so a slow command slows every turn.

After configuring, run the live checks in `docs/workflow/pilot-checklist.md` once.

After configuring a new project, run **Project Doctor** (checks syntax and hooks; does not execute your build/test commands):

```bash
bash scripts/validate-workflow.sh --project
```

Unset fields cause a failure, including the Quick check command (otherwise the Stop hook silently skips). Use `N/A` for inapplicable build/test/lint commands, and `Protected paths: NONE` when no *additional* paths need protection. A PASS is not evidence that application tests or live Claude/Codex sessions succeed.

## 3. Verify workflow without a model

```bash
bash scripts/validate-workflow.sh
bash scripts/test-secret-scan.sh
bash scripts/test-codex-delegate.sh
bash scripts/test-guard-hook.sh
bash scripts/test-auto-verify.sh
bash scripts/test-capture-experience.sh
bash scripts/test-workflow-memory.sh
```

The simulated `codex` tests do not use tokens or modify application code. They check approval, dry-run, dirty tree, early stdin close (SIGPIPE regression), exit codes, timeout, protected paths and concurrency.

## Model tiers and permission economy

Claude must record an implementation-difficulty tier `Codex difficulty: EASY / STANDARD / HARD` in the handoff's Route section. Model defaults are `gpt-6-luna/medium`, `gpt-6-sol/medium`, `gpt-6-sol/high`. Difficulty is independent of governance risk. HIGH-risk always requires FULL GOVERNANCE and at least STANDARD, and does not become safe just because code is short. Model overrides are supported through `CODEX_MODEL_EASY`, `CODEX_MODEL_STANDARD`, `CODEX_MODEL_HARD`, `CODEX_MODEL`, and `CODEX_REASONING_EFFORT`; verify availability on your local CLI.

For LOW-risk, LOW-traceability initial delegations, `bash scripts/codex-standard.sh TASK-ID` is the narrow pre-approved tool command: it refuses HIGH risk and forces network off. Do not auto-allow the unrestricted delegate wrapper. The default project permission mode is `acceptEdits`, which avoids routine edit prompts but **does not** override protected-path hook checks or explicit high-risk authorization. Prefer scoped permission allowlists; do not enable blanket bypass mode. An initial HIGH-risk Codex run continues using `bash scripts/codex-delegate.sh` with genuine human approval. 

## 4. Run an approved task

Create `.workflow/handoffs/TASK-DEMO-001.md` with `## Approval status` followed by `Status: APPROVED` **only after approval**. The wrapper rejects pending/non-approved tasks. This line is a process reminder, not proof of human authorization.

For an existing project, create `.workflow/` and move local scratch folders, for example `mv .claude/handoffs .workflow/handoffs`; repeat for `work-memory`, `experience-drafts` and `instinct-candidates` when present. The wrapper and `workflow-memory.sh show` still read legacy files with a deprecation warning.

```bash
bash scripts/codex-delegate.sh --dry-run TASK-DEMO-001
bash scripts/codex-delegate.sh TASK-DEMO-001
bash scripts/codex-delegate.sh --follow-up TASK-DEMO-001 TASK-DEMO-FIX-001
```

The second and third commands call a real model and can modify repo files. A first run refuses a dirty Git tree; a follow-up requires the same HEAD and complete worktree tree left by its newest parent run. Both refuse an existing lock. Use `CODEX_TIMEOUT_SECONDS=1800` to adjust the default 30-minute timeout. A stale lock from an interrupted process must be inspected and removed manually. Each run captures an ignored prompt, completion, log, git baseline and changed paths. A zero exit code is not acceptance.

## 5. Network and dependencies

Codex `workspace-write` sandbox usually restricts outbound network depending on CLI version/configuration. Verify on the target Mac before tasks requiring package installation. The wrapper always passes `-c sandbox_workspace_write.network_access=false`, so a global `~/.codex/config.toml` cannot silently enable network. When a run genuinely needs it, set `CODEX_NETWORK=1` (passes `=true`, sandbox stays `workspace-write`). Never disable the sandbox.

## 6. GitHub Template

For this source repository, open **Settings → General → Template repository** to enable template use. For each new app choose **Use this template → Create a new repository**. New projects are independent snapshots and do not automatically receive future template updates.


## 7. Capture and reuse verified workflow experience

For a meaningful failed/reworked task, inspect the run folder printed by `codex-delegate.sh` and generate a **private draft**:

```bash
bash scripts/capture-experience.sh TASK-LOGIN-001 TASK-LOGIN-001-run.XXXXXX
```

Use the run folder's actual six-character suffix, never the literal `XXXXXX`. The draft stays under ignored `.workflow/experience-drafts/` and contains metadata/references, not copied private logs. Inspect and redact the evidence before moving an approved, useful record into `.claude/lessons/` using `.claude/lessons/EXPERIENCE_TEMPLATE.md`.

Document **cue → observed failure → workflow change → before/after verification → adoption decision**. A baseline SHA and an adopted-change SHA let you reconstruct the relevant prompt/skill/scripts from Git without storing full harness duplicates.

An unverified hypothesis must not become a global rule. Only index lessons that have both evidence and appropriate approval. Do not commit credentials, raw handoffs, or private model logs.

## 8. ECC-inspired, no-observer workflow (v0.4.0)

A task expected to cross an agent/session boundary can start with:

```bash
bash scripts/workflow-memory.sh init TASK-EXAMPLE-001
bash scripts/workflow-memory.sh show TASK-EXAMPLE-001
```

Write only a concise objective, verified decisions, actual blockers and next action in ignored `.workflow/work-memory/TASK-EXAMPLE-001/STATE.md`. The Codex wrapper records an additional run checkpoint automatically **when possible**. Claude still checks Git diff and real test evidence; a completed run is not an accepted feature.

Use the `verify-change` skill on meaningful changes and the existing `learn-from-task` skill only for serious or repeated issues. Draft optional instincts from `.claude/lessons/INSTINCT_CANDIDATE_TEMPLATE.md`, under ignored `.workflow/instinct-candidates/`, and never auto-apply candidates. Keep model-based reasoning on-demand inside the current Claude/Codex interaction.

Before `/compact` or opening a new session, refresh the short task state. Work memory is local to this worktree, not shared across machines unless the operator deliberately exports a reviewed, redacted artifact. See `docs/workflow/ecc-selective-integration.md`.
