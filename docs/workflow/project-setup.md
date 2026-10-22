# Initialize a Project from This Template

## 1. Check prerequisites on your own development machine

```bash
git --version
claude --version  # if Claude Code is installed
codex --version   # if Codex CLI is installed
```

This template does **not** install Claude, Codex, Spec Kit or Superpowers. Use each tool's official installation and authentication flow.

## 2. Configure the project, not the shared template

- Add the real tech stack, architecture constraints, build/test commands and project approvals.
- Review `CLAUDE.md` and `AGENTS.md` in light of local conventions.
- Confirm how Claude invokes Codex (manual handoff, CLI integration or approved agent bridge); template alone does not provide execution.
- Avoid committing credentials, account settings, project-specific secrets or private lessons to the template.

## 3. Spec Kit (for justified Large tasks)

If necessary, install the official `specify-cli`, then initialize *within the project* using the Claude integration. The current CLI offers `specify init --here --integration claude`; if the folder is non-empty it may prompt to merge or require `--force`. **Back up/commit changes and review diffs before running a forceful merge.**

```bash
# After installing specify-cli separately:
specify version
# Inspect supported options for your installed version:
specify init --help
```

Do not run Spec Kit setup automatically as part of template creation. Spec Kit may generate `.specify/` files and agent commands, so avoid conflicts with existing skills.

## 4. Superpowers

Check Superpowers is installed and available for your particular Claude/Codex environment. Follow its upstream instructions; do not assume sharing a template installs it.

## 5. Pilot exercise

```bash
bash scripts/validate-workflow.sh
```

Ask Claude to perform a read-only audit of this new repository, classify one Small and one Medium hypothetical task, evaluate the Medium plan via `/plan-quality`, and output a Codex handoff. **Do not change application code** during the smoke test.

## 6. Upgrading the common template

Lessons stay local until evaluated. Propose approved reusable changes as reviewed commits to the template repo. Existing repositories created from the template do not update automatically.
