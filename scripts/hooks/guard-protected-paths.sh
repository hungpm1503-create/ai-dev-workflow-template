#!/usr/bin/env bash
# Claude Code PreToolUse hook: ask the user before Claude edits a protected path.
# Reads the hook JSON on stdin. Protected paths = wrapper defaults + AGENTS.md > Protected paths.
# Outputs a permissionDecision of "ask" for protected files; otherwise exits 0 silently.
# Intentionally dependency-free (no jq/python). Not a security boundary: the user can still approve.
set -euo pipefail
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
input="$(cat)"

# Extract "file_path" (Edit/Write/MultiEdit) or "notebook_path" (NotebookEdit).
path="$(printf '%s' "$input" | tr '\n' ' ' \
  | sed -E -n 's/.*"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"([^"]*)".*/\2/p' | head -n 1)"
[[ -n "$path" ]] || exit 0

# Normalise to a repository-relative path.
rel="${path#"$root"/}"
rel="${rel#./}"
case "$rel" in /*) exit 0 ;; esac   # outside the project: leave to normal permissions

protected() {
  printf '%s\n' 'CLAUDE.md' 'AGENTS.md' 'scripts/codex-delegate.sh' 'scripts/hooks/' '.claude/settings.json' '.claude/skills/' '.github/workflows/'
  if [[ -f "$root/AGENTS.md" ]]; then
    sed -n 's/^[[:space:]]*-[[:space:]]*Protected paths:[[:space:]]*//p' "$root/AGENTS.md" | head -n 1 | tr ',' '\n'
  fi
}

while IFS= read -r p; do
  p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "$p" || "$p" == '[NOT CONFIGURED]' ]] && continue
  case "$p" in /*|*'..'*|*'*'*|*'?'*) continue ;; esac
  if [[ "$rel" == "$p" || ( "$p" == */ && "$rel" == "$p"* ) ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s is a protected path (AGENTS.md / workflow defaults). Confirm this edit is intended."}}\n' "$rel"
    exit 0
  fi
done < <(protected)
exit 0
