# Initialize a Project from This Template

## 1. Check local tools

\`\`\`bash
git --version
claude --version
codex --version
\`\`\`

Install and authenticate Claude and Codex separately. This template does not install models, Spec Kit or Superpowers. If using Spec Kit, initialize carefully and inspect generated artifacts; do not force-overwrite project config. Verify Superpowers is installed before referring to its skills.

## Tool ownership — adaptive routing, not duplicate plans

See `docs/workflow/task-routing.md` for decision examples and escalation.

- Classify task **size and governance risk separately**; downstream project-specific HIGH-risk rules take priority.
- **SMALL/LOW:** short handoff, Codex and lightweight review; no Spec Kit.
- **MEDIUM/LOW:** one short Claude plan → proportionate `plan-quality` → Codex → review.
- **LARGE/LOW:** Spec Lite → one canonical short spec/design with ACs and slices → Codex → independent review. Invoke only useful Spec Kit stages if configured; avoid mandatory full chain and duplicate artifacts.
- **ANY/HIGH:** required full high-risk process and explicit human gates; never downgrade to Spec Lite just because formal tooling is missing.
- Superpowers is **only** for targeted TDD, systematic debugging and verification when installed. Never run separate brainstorming/writing-plans workflows on top of Claude or Spec Kit.
- Codex CLI remains implementation owner; **do not** use `/speckit-implement` or `/speckit.implement`.
- If a needed tool is unavailable, report that accurately. HIGH-risk work requires an approved equivalent process before proceeding, not a fictional Spec Kit run.

## 2. Configure each project

Fill \`AGENTS.md > Project Configuration\`: actual stack, build/test/lint commands and protected paths. Protected paths are **literal repository-relative paths**, comma-separated, e.g. \`src/config/, infrastructure/\`. Directories end in \`/\`. The wrapper also protects \`CLAUDE.md\`, \`AGENTS.md\`, \`scripts/codex-delegate.sh\`, \`.claude/skills/\` and \`.github/workflows/\` by default. This is a **post-run detector**, not a file-system access control boundary.

## 3. Verify workflow without a model

\`\`\`bash
bash scripts/validate-workflow.sh
bash scripts/test-secret-scan.sh
bash scripts/test-codex-delegate.sh
bash scripts/test-capture-experience.sh
bash scripts/test-workflow-memory.sh
\`\`\`

The simulated \`codex\` tests do not use tokens or modify application code. They check approval, dry-run, dirty tree, early stdin close (SIGPIPE regression), exit codes, timeout, protected paths and concurrency.

## 4. Run an approved task

Create \`.claude/handoffs/TASK-DEMO-001.md\` with \`## Approval status\` followed by \`Status: APPROVED\` **only after approval**. The wrapper rejects pending/non-approved tasks. This line is a process reminder, not proof of human authorization.

\`\`\`bash
bash scripts/codex-delegate.sh --dry-run TASK-DEMO-001
bash scripts/codex-delegate.sh TASK-DEMO-001
\`\`\`

The second command calls a real model and can modify repo files. It refuses to run if Git status is dirty or a lock already exists. Use \`CODEX_TIMEOUT_SECONDS=1800\` to adjust the default 30-minute timeout. A stale lock from an interrupted process must be inspected and removed manually. Each run captures an ignored prompt, completion, log, git baseline and changed paths. A zero exit code is not acceptance.

## 5. Network and dependencies

Codex \`workspace-write\` sandbox usually restricts outbound network depending on CLI version/configuration. Verify on the target Mac before tasks requiring package installation. Do not disable sandbox or enable unrestricted network just to make a build work.

## 6. GitHub Template

For this source repository, open **Settings → General → Template repository** to enable template use. For each new app choose **Use this template → Create a new repository**. New projects are independent snapshots and do not automatically receive future template updates.


## 7. Capture and reuse verified workflow experience

For a meaningful failed/reworked task, inspect the run folder printed by `codex-delegate.sh` and generate a **private draft**:

```bash
bash scripts/capture-experience.sh TASK-LOGIN-001 TASK-LOGIN-001-run.XXXXXX
```

Use the run folder's actual six-character suffix, never the literal `XXXXXX`. The draft stays under ignored `.claude/experience-drafts/` and contains metadata/references, not copied private logs. Inspect and redact the evidence before moving an approved, useful record into `.claude/lessons/` using `.claude/lessons/EXPERIENCE_TEMPLATE.md`.

Document **cue → observed failure → workflow change → before/after verification → adoption decision**. A baseline SHA and an adopted-change SHA let you reconstruct the relevant prompt/skill/scripts from Git without storing full harness duplicates.

An unverified hypothesis must not become a global rule. Only index lessons that have both evidence and appropriate approval. Do not commit credentials, raw handoffs, or private model logs.

## 8. ECC-inspired, no-observer workflow (v0.4.0)

A task expected to cross an agent/session boundary can start with:

```bash
bash scripts/workflow-memory.sh init TASK-EXAMPLE-001
bash scripts/workflow-memory.sh show TASK-EXAMPLE-001
```

Write only a concise objective, verified decisions, actual blockers and next action in ignored `.claude/work-memory/TASK-EXAMPLE-001/STATE.md`. The Codex wrapper records an additional run checkpoint automatically **when possible**. Claude still checks Git diff and real test evidence; a completed run is not an accepted feature.

Use the `verify-change` skill on meaningful changes and the existing `learn-from-task` skill only for serious or repeated issues. Draft optional instincts from `.claude/lessons/INSTINCT_CANDIDATE_TEMPLATE.md`, under ignored `.claude/instinct-candidates/`, and never auto-apply candidates. Keep model-based reasoning on-demand inside the current Claude/Codex interaction.

Before `/compact` or opening a new session, refresh the short task state. Work memory is local to this worktree, not shared across machines unless the operator deliberately exports a reviewed, redacted artifact. See `docs/workflow/ecc-selective-integration.md`.
