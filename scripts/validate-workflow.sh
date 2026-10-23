#!/usr/bin/env bash
# Non-destructive static checks. No external model calls.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

files=(
  README.md CLAUDE.md AGENTS.md .gitignore
  .claude/skills/plan-quality/SKILL.md
  .claude/skills/codex-delegate/SKILL.md
  .claude/skills/learn-from-task/SKILL.md
  .claude/lessons/INDEX.md
  docs/workflow/handoff-template.md
  docs/workflow/evaluation-template.md
  docs/workflow/project-setup.md
  scripts/codex-delegate.sh
  scripts/test-codex-delegate.sh
)

failed=0
for file in "${files[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "FAIL: missing or empty $file"
    failed=1
  else
    echo "OK: $file"
  fi
done

# Validate opening AND closing frontmatter delimiters plus required fields.
for skill in .claude/skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  if ! awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { closed = 1; exit }
    /^name:[[:space:]]+[^[:space:]]/ { has_name = 1 }
    /^description:[[:space:]]+[^[:space:]]/ { has_description = 1 }
    END { if (!closed || !has_name || !has_description) exit 1 }
  ' "$skill"; then
    echo "FAIL: invalid YAML frontmatter (name/description/closing ---) in $skill"
    failed=1
  fi
done

for script in scripts/*.sh; do
  if ! bash -n "$script"; then echo "FAIL: shell syntax $script"; failed=1; fi
done

# Lightweight common token-pattern check in project workflow files.
if find README.md CLAUDE.md AGENTS.md .claude docs/workflow scripts -type f \
  \( -name '*.md' -o -name '*.sh' \) \
  -exec grep -E -q 'sk-[A-Za-z0-9]{24,}|ghp_[A-Za-z0-9]{24,}' {} +; then
  echo "FAIL: possible plaintext secret in workflow files"
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then echo "FAIL: template static checks"; exit 1; fi
echo "PASS: static workflow checks (no model called)"
echo "NOTE: Real Claude/Codex/Spec Kit/Superpowers availability must be checked locally."
