---
name: verify-change
description: Verify approved implementation changes using actual diff, applicable build/test/lint commands and risk-focused independent review, without falsely claiming missing checks passed.
---

# Scoped Verification and Independent Review

Use after Codex finishes meaningful code changes or before accepting a PR. For trivial Small tasks, keep this brief. Review the specific approved handoff and real worktree diff; never read unrelated files merely to fill context.

## Evidence-driven gate

1. Confirm task ID, Git baseline, scope and relevant acceptance criteria.
2. Read only changed files and adjacent impacted code. Validate against authoritative project configuration and established invariants.
3. Select actual project build/test/typecheck/lint commands from `AGENTS.md > Project Configuration`; do not run placeholder commands. Run checks that match the change and document their **actual exit codes**. Do not run the same expensive checks again when verified fresh evidence is sufficient.
4. Check relevant security and correctness issues (secrets, input validation, auth, privacy, data loss, regressions). Respect risk and project-specific protected directories.
5. Compare the result with acceptance criteria and classify each one **PASS / FAIL / UNVERIFIED**, citing observed tests, diffs or manual checks. No "PASS" for unrun or unavailable checks.
6. Record relevant failures/rework as *possible* instincts through `learn-from-task`; do not auto-promote.

## Result contract

- Changed files and intended scope; deviations.
- Executed verification commands, exit codes and decisive excerpts.
- Security/logic findings ranked BLOCKER/MAJOR/MINOR.
- Acceptance criteria by PASS/FAIL/UNVERIFIED.
- Remediation owner or next action.

An exit code of zero from Codex is execution evidence, **not** proof that the change meets requirements. Don't commit/push/merge/deploy without approval. Don't impose unrelated hard coverage targets or scan the entire repo on every small edit.
