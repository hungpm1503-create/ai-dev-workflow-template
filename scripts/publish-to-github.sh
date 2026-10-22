#!/usr/bin/env bash
set -euo pipefail

# Optional helper for publishing this extracted template when the target GitHub repository does NOT yet exist.
# Requires a locally authenticated GitHub CLI and git identity.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
name="ai-dev-workflow-template"

command -v gh >/dev/null || { echo 'ERROR: install GitHub CLI (gh) first.'; exit 1; }
command -v git >/dev/null || { echo 'ERROR: git is required.'; exit 1; }
gh auth status >/dev/null || { echo 'ERROR: authenticate with gh auth login.'; exit 1; }
owner="$(gh api user --jq .login)"
repo="$owner/$name"

if gh repo view "$repo" >/dev/null 2>&1; then
  echo "ERROR: $repo already exists. Do not overwrite it. Use README manual push procedure instead."
  exit 1
fi

bash scripts/validate-workflow.sh
if [[ ! -d .git ]]; then
  git init -b main
fi
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m 'chore: initial AI development workflow template'
fi
branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
  echo "ERROR: expected local main branch, found '$branch'. Resolve manually."
  exit 1
fi

# No explicit token is stored in this repository.
gh repo create "$repo" --private --description 'Shared Claude Lead + Codex AI development workflow template' --source=. --remote=origin --push
# GitHub REST PATCH accepts a boolean; gh -F converts true to JSON boolean.
gh api --method PATCH "repos/$repo" -F is_template=true --silent

echo "Published template: https://github.com/$repo"
echo 'Review Settings > General > Template repository to verify.'
