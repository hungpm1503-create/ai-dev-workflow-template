#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

files=(
  "README.md"
  "CLAUDE.md"
  "AGENTS.md"
  ".claude/skills/plan-quality/SKILL.md"
  ".claude/skills/learn-from-task/SKILL.md"
  ".claude/lessons/INDEX.md"
  "docs/workflow/handoff-template.md"
  "docs/workflow/evaluation-template.md"
  "docs/workflow/project-setup.md"
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

for skill in .claude/skills/*/SKILL.md; do
  if [[ -f "$skill" ]]; then
    if [[ "$(head -n 1 "$skill")" != "---" ]] || ! grep -q '^name:' "$skill" || ! grep -q '^description:' "$skill"; then
      echo "FAIL: missing skill frontmatter in $skill"
      failed=1
    fi
  fi
done

if grep -R -E --include='*.md' --include='*.sh' 'sk-[A-Za-z0-9]{24,}|ghp_[A-Za-z0-9]{24,}' . >/dev/null 2>&1; then
  echo "FAIL: possible credential pattern in committed text"
  failed=1
fi

if [[ "$failed" -eq 0 ]]; then
  echo "PASS: static workflow structure checks"
else
  echo "FAILED: template static checks"
  exit 1
fi

echo 'NOTE: CLI integration, skills discovery, Spec Kit/Superpowers and real Codex delegation require testing on your machine.'
