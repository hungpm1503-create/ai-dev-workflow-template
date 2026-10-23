#!/usr/bin/env bash
# Run one approved Claude -> Codex handoff. No model invocation in --dry-run.
set -euo pipefail
umask 077

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

usage() {
  echo "Usage: bash scripts/codex-delegate.sh [--dry-run] TASK-ID" >&2
  echo "Handoff: .claude/handoffs/TASK-ID.md (never committed)" >&2
}

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi
if [[ "$#" -ne 1 ]]; then usage; exit 2; fi
task_id="$1"

# Restrict task IDs to simple filenames; reject traversal and shell metacharacters.
if [[ ! "$task_id" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || (( ${#task_id} > 72 )); then
  echo "ERROR: invalid task ID; expected TASK-[A-Za-z0-9_-], max 72 chars." >&2
  exit 2
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: run inside a Git repository." >&2
  exit 2
fi

handoff_dir="$root/.claude/handoffs"
handoff="$handoff_dir/$task_id.md"
if [[ ! -f "$handoff" || -L "$handoff" || ! -s "$handoff" ]]; then
  echo "ERROR: handoff missing, empty, or symlinked: .claude/handoffs/$task_id.md" >&2
  exit 2
fi

if [[ "$dry_run" -eq 1 ]]; then
  echo "DRY RUN: codex exec --sandbox workspace-write --output-last-message <run>/completion.md -"
  echo "Input: .claude/handoffs/$task_id.md"
  echo "No Codex invocation or implementation performed."
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: Codex CLI not found on PATH; install and authenticate separately." >&2
  exit 127
fi

run_dir="$(mktemp -d "$handoff_dir/$task_id-run.XXXXXX")"
result="$run_dir/completion.md"
log="$run_dir/codex.log"
status="$run_dir/status.txt"

# Handoff content is data, not a shell command. Codex still follows AGENTS.md
# and the repository's approval boundaries. Do not use danger-full-access.
if {
  printf '%s\n' \
    "Implement the APPROVED task below in this Git repository." \
    "Follow AGENTS.md and project-specific instructions." \
    "Use only the approved scope and workspace-write sandbox." \
    "Do not commit, push, merge, deploy, change security policy, or perform destructive operations." \
    "If the task requires a major scope/architecture/security change, stop and report it." \
    "For each acceptance criterion report PASS, FAIL, or UNVERIFIED, with actual commands and exit codes." \
    "" \
    "--- BEGIN APPROVED HANDOFF ---"
  cat "$handoff"
  printf '\n%s\n' "--- END APPROVED HANDOFF ---"
} | codex exec --sandbox workspace-write --output-last-message "$result" - >"$log" 2>&1; then
  exit_code=0
else
  exit_code=$?
fi

printf 'EXIT_CODE=%s\n' "$exit_code" > "$status"
printf 'Task: %s\nCodex exit code: %s\n' "$task_id" "$exit_code"
printf 'Output: %s\nLog: %s\nStatus: %s\n' \
  "${result#"$root/"}" "${log#"$root/"}" "${status#"$root/"}"
if [[ "$exit_code" -ne 0 ]]; then
  echo "Codex failed. Review the ignored log and treat all unverified criteria as UNVERIFIED." >&2
fi
exit "$exit_code"
