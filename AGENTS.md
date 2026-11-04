# Codex — Shared Implementation Rules

Work as the primary implementation engineer on approved tasks. Respect project-specific `AGENTS.md` files and the current codebase's conventions.

Codex must follow `docs/workflow/codex-rules.md`; the delegation wrapper injects its full content into the prompt.

## Project Configuration — fill once for each new project

- Stack: [NOT CONFIGURED]
- Build command: [NOT CONFIGURED]
- Test command: [NOT CONFIGURED]
- Lint / typecheck command: [NOT CONFIGURED]
- Quick check command: [NOT CONFIGURED]
  (fast lint + affected tests, under ~60s; run automatically by the Claude Code Stop hook when files changed, e.g. `npm run lint && npm test -- --run`)
- Protected paths: [NOT CONFIGURED]
- Project-specific constraints: [NOT CONFIGURED]

Do not invent executable commands from these placeholders. Verify against the actual project and update them during bootstrap.
