---
name: codex-delegate
description: Delegate an approved task to Codex CLI using a unique ignored handoff and repository-local sandboxed wrapper; verify exit evidence, scope, clean tree and protected paths.
---

# Codex Delegation

## Tool ownership

- Codex is the implementation executor, including for Large features planned through Spec Kit. Never delegate implementation to `/speckit-implement` or `/speckit.implement`.
- Reference the **one approved planning source** chosen by Claude: concise Claude plan, Superpowers plan or canonical Spec Kit specification/plan. For HIGH risk also follow required independently approved governance artifacts. Do not create duplicate plans.
- Codex may use Superpowers for **TDD, systematic debugging and verification** when available. Claude may have used its brainstorming/writing-plans for planning; Codex does not repeat them or run competing subagent implementation/`executing-plans`.

1. Verify \`codex\` is installed and authenticated, and this Git repository has a clean worktree.
2. Confirm scope is approved. Material architecture, security, costs and irreversible operations still require explicit user approval.
3. Review the one canonical plan proportionately when needed; for ANY/HIGH, ensure required independent project review and human approval gates without duplicated reviews. Use \`docs/workflow/handoff-template.md\`. Write \`.claude/handoffs/TASK-ID.md\` with **## Approval status** and exact **Status: APPROVED**, only after appropriate approval. This text is not cryptographic authorization.
4. Verify \`AGENTS.md > Protected paths\` is configured for this project, if applicable.
5. Dry run: \`bash scripts/codex-delegate.sh --dry-run TASK-ID\` (no model invocation).
6. Execute only when permitted: \`bash scripts/codex-delegate.sh TASK-ID\`.
7. Inspect the ignored run directory: \`prompt.md\`, \`completion.md\`, \`codex.log\`, \`status.txt\`, Git baseline and changed-paths report. Review \`git diff\` independently.

The wrapper uses \`codex exec --sandbox workspace-write --output-last-message ... -\`. Handoffs and logs are gitignored, saved separately for every run. The wrapper blocks dirty worktrees and overlapping invocations, uses a portable time limit (default 1800 seconds; configure \`CODEX_TIMEOUT_SECONDS\`), and post-checks protected paths. Do not bypass the sandbox.

**Important:** A protected-path postcheck detects changes **after** they happen and cannot prevent their creation; it never auto-reverts user files. The text approval marker can be edited and is not an independently verified user authorization. The secret scanner is heuristic. A timed-out Codex child may require manual inspection. If Codex cannot run, return the handoff and mark execution UNVERIFIED.

Never auto-commit, push, merge or deploy. Never claim unrun tests passed.
