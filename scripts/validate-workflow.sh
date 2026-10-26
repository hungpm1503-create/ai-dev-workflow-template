#!/usr/bin/env bash
# Static checks only; do not call an AI model.
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
  docs/workflow/task-routing.md
  scripts/codex-delegate.sh
  scripts/test-codex-delegate.sh
  scripts/test-secret-scan.sh
  scripts/capture-experience.sh
  scripts/test-capture-experience.sh
  scripts/workflow-memory.sh
  scripts/test-workflow-memory.sh
  scripts/test-task-routing.sh
  .claude/skills/workflow-memory/SKILL.md
  .claude/skills/verify-change/SKILL.md
  .claude/lessons/INSTINCT_CANDIDATE_TEMPLATE.md
  docs/workflow/ecc-selective-integration.md
  docs/workflow/benchmark-workflow-resume.md
  scripts/benchmark-workflow-resume.sh
  scripts/benchmark-codex-ab.sh
  docs/workflow/codex-ab-pilot.md
  .claude/lessons/EXPERIENCE_TEMPLATE.md
)
failed=0
for file in "${files[@]}"; do
  if [[ ! -s "$file" ]]; then echo "FAIL: missing or empty $file"; failed=1; fi
done

for skill in .claude/skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  if ! awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { closed = 1; exit }
    /^name:[[:space:]]+[^[:space:]]/ { has_name = 1 }
    /^description:[[:space:]]+[^[:space:]]/ { has_description = 1 }
    END { if (!closed || !has_name || !has_description) exit 1 }
  ' "$skill"; then
    echo "FAIL: invalid skill frontmatter in $skill"; failed=1
  fi
done
for script in scripts/*.sh; do
  if ! bash -n "$script"; then echo "FAIL: shell syntax $script"; failed=1; fi
done

# Scan all tracked and untracked nonignored repo files; includes src/, .github/, etc.
# This is an intentionally limited common-token heuristic, NOT a replacement for gitleaks.
secret_pattern='sk-(ant|proj)-[A-Za-z0-9_-]{12,}|sk-[A-Za-z0-9]{24,}|ghp_[A-Za-z0-9]{24,}|github_pat_[A-Za-z0-9_]{16,}'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r -d '' path; do
    if [[ -f "$path" && ! -L "$path" ]] && grep -I -E -q "$secret_pattern" "$path"; then
      echo "FAIL: possible plaintext secret in $path"; failed=1
    fi
  done < <(git ls-files -z --cached --others --exclude-standard)
else
  echo 'FAIL: secret scan requires a Git repository'; failed=1
fi
if [[ "$failed" != 0 ]]; then echo 'FAIL: template static checks'; exit 1; fi
echo 'PASS: static workflow checks (no model invoked)'
echo 'NOTE: secret scanner uses limited patterns; review and dedicated tools remain necessary.'
