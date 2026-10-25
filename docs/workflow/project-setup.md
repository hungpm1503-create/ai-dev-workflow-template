# Initialize a Project from This Template

## 1. Check local tools

\`\`\`bash
git --version
claude --version
codex --version
\`\`\`

Install and authenticate Claude and Codex separately. This template does not install models, Spec Kit or Superpowers. If using Spec Kit, initialize carefully and inspect generated artifacts; do not force-overwrite project config. Verify Superpowers is installed before referring to its skills.

## Tool ownership — avoid duplicate plans

- **Small:** Claude prepares a compact handoff; Codex implements; Claude reviews.
- **Medium:** Claude owns the only implementation plan; `plan-quality` verifies it; Codex implements.
- **Large:** use Spec Kit for feature specification and architecture/implementation planning if installed; its artifacts are authoritative. `plan-quality` reviews those artifacts; Codex implements.
- Superpowers is **only** for TDD, systematic debugging and verification where installed. Do not use its `brainstorming` or `writing-plans` skills in parallel with Claude/Spec Kit planning.
- Do **not** run `/speckit-implement` or `/speckit.implement` under this workflow. Codex CLI is the implementation engine.
- When a tool is unavailable, report it; do not pretend the associated skill or command ran. Reference a single canonical set of planning artifacts.

## 2. Configure each project

Fill \`AGENTS.md > Project Configuration\`: actual stack, build/test/lint commands and protected paths. Protected paths are **literal repository-relative paths**, comma-separated, e.g. \`src/config/, infrastructure/\`. Directories end in \`/\`. The wrapper also protects \`CLAUDE.md\`, \`AGENTS.md\`, \`scripts/codex-delegate.sh\`, \`.claude/skills/\` and \`.github/workflows/\` by default. This is a **post-run detector**, not a file-system access control boundary.

## 3. Verify workflow without a model

\`\`\`bash
bash scripts/validate-workflow.sh
bash scripts/test-secret-scan.sh
bash scripts/test-codex-delegate.sh
bash scripts/test-capture-experience.sh
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
