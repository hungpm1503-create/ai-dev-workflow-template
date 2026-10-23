# Initialize a Project from This Template

## 1. Check local tools

\`\`\`bash
git --version
claude --version
codex --version
\`\`\`

Install and authenticate Claude and Codex separately. This template does not install models, Spec Kit or Superpowers. If using Spec Kit, initialize carefully and inspect generated artifacts; do not force-overwrite project config. Verify Superpowers is installed before referring to its skills.

## 2. Configure each project

Fill \`AGENTS.md > Project Configuration\`: actual stack, build/test/lint commands and protected paths. Protected paths are **literal repository-relative paths**, comma-separated, e.g. \`src/config/, infrastructure/\`. Directories end in \`/\`. The wrapper also protects \`CLAUDE.md\`, \`AGENTS.md\`, \`scripts/codex-delegate.sh\`, \`.claude/skills/\` and \`.github/workflows/\` by default. This is a **post-run detector**, not a file-system access control boundary.

## 3. Verify workflow without a model

\`\`\`bash
bash scripts/validate-workflow.sh
bash scripts/test-secret-scan.sh
bash scripts/test-codex-delegate.sh
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
