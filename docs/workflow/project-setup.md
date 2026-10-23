# Initialize a Project from This Template

## 1. Check tools installed on your computer

```bash
git --version
claude --version
codex --version
```

This template does not install/authenticate Claude CLI, Codex CLI, Spec Kit, or Superpowers.

## 2. Configure new project

- Fill `AGENTS.md > Project Configuration`: stack, build/test/lint commands, protected paths and constraints.
- Review `CLAUDE.md` to ensure project-specific approval rules are compatible.
- Use existing environment authentication; do not copy credentials to the repo or task handoffs.
- Check `command -v codex` and that Codex has been authenticated on the workstation.
- If the project uses Spec Kit, initialize and verify it deliberately. Review the generated `.specify/` and commands before committing; do not automatically force-merge generated files.
- Check Superpowers installation and discover relevant skills instead of assuming it came with this template.

## 3. Test the Claude → Codex handoff (without model cost)

Run the offline validations:

```bash
bash scripts/validate-workflow.sh
bash scripts/test-codex-delegate.sh
```

Ask Claude to classify one hypothetical Medium task, run its Planning Quality Gate, then save an approved practice handoff named `.claude/handoffs/TASK-PRACTICE-001.md`.

```bash
bash scripts/codex-delegate.sh --dry-run TASK-PRACTICE-001
```

The dry-run prints the intended action and does **not** execute Codex. A real `bash scripts/codex-delegate.sh TASK-PRACTICE-001` invocation calls a model and can modify workspace files; do it only after approving an actual task.

## 4. Operational notes

- Logs and completions live under uniquely named `.claude/handoffs/TASK-ID-run.XXXXXX/` folders; they are gitignored.
- The wrapper captures Codex's final message, exit code and log; this does not certify implementation correctness. Claude still inspects diff and verification evidence.
- The wrapper uses `workspace-write` sandbox. It must not be changed to a sandbox bypass for convenience.
- Keep lessons project-specific unless validated for reuse in the shared template.

## 5. Upgrading projects

New repositories get the current template snapshot via **Use this template**. Existing projects do not auto-update; port common changes through review.
