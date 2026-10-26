#!/usr/bin/env bash
# Run one explicitly approved handoff. Requires a clean Git worktree.
set -euo pipefail
umask 077

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
usage() { echo 'Usage: bash scripts/codex-delegate.sh [--dry-run] TASK-ID' >&2; }

dry_run=0
if [[ "${1:-}" == '--dry-run' ]]; then dry_run=1; shift; fi
if [[ $# -ne 1 ]]; then usage; exit 2; fi
task_id="$1"
if [[ ! "$task_id" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || (( ${#task_id} > 72 )); then
  echo 'ERROR: invalid task ID (expected TASK-[A-Za-z0-9_-], maximum 72 characters).' >&2
  exit 2
fi
if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ "$repo_root" != "$root" ]]; then
  echo 'ERROR: script must run at the root of its own Git worktree.' >&2
  exit 2
fi

handoff_dir="$root/.claude/handoffs"
handoff="$handoff_dir/$task_id.md"
if [[ -L "$handoff_dir" || ! -f "$handoff" || -L "$handoff" || ! -s "$handoff" ]]; then
  echo 'ERROR: approved handoff not found, empty, or symlinked.' >&2
  exit 2
fi

# Parse an exact status from the designated section (not a substring such as NOT APPROVED).
approval_status="$(awk '
  /^## Approval status[[:space:]]*$/ { inside=1; next }
  inside && /^##[[:space:]]/ { exit }
  inside && /^Status:[[:space:]]*/ {
    sub(/^Status:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit
  }
' "$handoff")"
if [[ "$approval_status" != 'APPROVED' ]]; then
  echo 'ERROR: handoff needs ## Approval status containing exactly Status: APPROVED.' >&2
  exit 3
fi

if (( dry_run )); then
  echo "DRY RUN: approved handoff .claude/handoffs/$task_id.md"
  echo 'Would invoke: codex exec --sandbox workspace-write --output-last-message <run>/completion.md -'
  echo 'No Codex invocation or file modification performed.'
  exit 0
fi
if ! command -v codex >/dev/null 2>&1; then
  echo 'ERROR: Codex CLI is missing; install and authenticate it separately.' >&2
  exit 127
fi

# Portable Bash+sleep watchdog (no GNU timeout dependency on macOS).
timeout_seconds="${CODEX_TIMEOUT_SECONDS:-1800}"
if [[ ! "$timeout_seconds" =~ ^[0-9]+$ ]] || (( ${#timeout_seconds} > 6 )) || (( 10#$timeout_seconds < 1 || 10#$timeout_seconds > 86400 )); then
  echo 'ERROR: CODEX_TIMEOUT_SECONDS must be an integer between 1 and 86400.' >&2
  exit 2
fi

# An atomic repo-worktree lock; do not run two Codex tasks on the same working tree.
lock_dir="$handoff_dir/.codex-delegate.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo 'ERROR: another Codex task holds this worktree lock; inspect it before manually removing a stale lock.' >&2
  exit 5
fi
printf '%s\n' "$$" > "$lock_dir/pid"
cleanup() { rm -f "$lock_dir/pid"; rmdir "$lock_dir" >/dev/null 2>&1 || :; }
trap cleanup EXIT

run_dir="$(mktemp -d "$handoff_dir/$task_id-run.XXXXXX")"
result="$run_dir/completion.md"
log="$run_dir/codex.log"
status="$run_dir/status.txt"
prompt="$run_dir/prompt.md"
before="$run_dir/status-before.txt"
head_sha="$(git rev-parse HEAD)"
printf '%s\n' "$head_sha" > "$run_dir/head-before.txt"
git status --porcelain=v1 --untracked-files=all > "$before"
if [[ -s "$before" ]]; then
  echo 'ERROR: working tree is dirty. Commit, safely stash, or isolate your changes before delegating; no changes were made.' >&2
  printf 'RESULT=BLOCKED_DIRTY_WORKTREE\n' > "$status"
  exit 6
fi

# Snapshot protected paths before Codex can change AGENTS.md.
{
  printf '%s\n' 'CLAUDE.md' 'AGENTS.md' 'scripts/codex-delegate.sh' '.claude/skills/' '.github/workflows/'
  sed -n 's/^[[:space:]]*-[[:space:]]*Protected paths:[[:space:]]*//p' AGENTS.md | head -n 1 | tr ',' '\n'
} | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v -E '^$|^\[NOT CONFIGURED\]$' > "$run_dir/protected-paths.txt" || :

# Construct the complete prompt before launching Codex. No producer SIGPIPE if it exits early.
{
  printf '%s\n' \
    'Implement only the approved task below, following AGENTS.md and relevant repository instructions.' \
    'Respect the scoped acceptance criteria and workspace-write sandbox.' \
    'Do not commit, push, merge, deploy, remove safety controls or perform destructive operations.' \
    'Escalate material scope, security or architectural changes instead of guessing.' \
    'Report actual build/test commands and exit codes; mark unchecked criteria UNVERIFIED.' \
    '' '--- BEGIN APPROVED HANDOFF ---'
  cat "$handoff"
  printf '\n%s\n' '--- END APPROVED HANDOFF ---'
} > "$prompt"

codex exec --sandbox workspace-write --output-last-message "$result" - < "$prompt" > "$log" 2>&1 &
codex_pid=$!
(
  sleep "$((10#$timeout_seconds))" &
  sleep_pid=$!
  trap 'kill "$sleep_pid" 2>/dev/null || :' TERM EXIT
  wait "$sleep_pid" || exit 0
  if kill -0 "$codex_pid" 2>/dev/null; then
    printf '%s\n' 'TIMEOUT' > "$run_dir/timed-out.txt"
    kill -TERM "$codex_pid" 2>/dev/null || :
    sleep 3
    kill -KILL "$codex_pid" 2>/dev/null || :
  fi
) &
watchdog_pid=$!
if wait "$codex_pid"; then exit_code=0; else exit_code=$?; fi
kill "$watchdog_pid" 2>/dev/null || :
wait "$watchdog_pid" 2>/dev/null || :
codex_exit_code="$exit_code"
if [[ -f "$run_dir/timed-out.txt" ]]; then exit_code=124; fi

git status --porcelain=v1 --untracked-files=all > "$run_dir/status-after.txt"
{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u > "$run_dir/changed-paths.txt"
: > "$run_dir/protected-violations.txt"
while IFS= read -r changed; do
  [[ -n "$changed" ]] || continue
  while IFS= read -r protected; do
    [[ -n "$protected" ]] || continue
    case "$protected" in
      /*|*'..'*|*'*'*|*'?'*) continue ;; # Only literal repo-relative paths and directory prefixes
    esac
    if [[ "$changed" == "$protected" || ( "$protected" == */ && "$changed" == "$protected"* ) ]]; then
      printf '%s\n' "$changed" >> "$run_dir/protected-violations.txt"
      break
    fi
  done < "$run_dir/protected-paths.txt"
done < "$run_dir/changed-paths.txt"
if [[ -s "$run_dir/protected-violations.txt" ]]; then
  echo 'ERROR: protected paths changed; inspect diff and revert manually if needed.' >&2
  cat "$run_dir/protected-violations.txt" >&2
  exit_code=4
fi
printf 'CODEX_EXIT_CODE=%s\nFINAL_EXIT_CODE=%s\nHEAD_BEFORE=%s\n' "$codex_exit_code" "$exit_code" "$head_sha" > "$status"

# Deterministic, local-only memory checkpoint (best effort); never change the Codex verdict.
if [[ -f "$root/scripts/workflow-memory.sh" ]]; then
  if ! bash "$root/scripts/workflow-memory.sh" record-run "$task_id" "$(basename "$run_dir")" >> "$log" 2>&1; then
    echo "WARNING: working-memory checkpoint failed; Codex result remains $exit_code." >&2
  fi
fi
printf 'Task: %s\nFinal exit code: %s\n' "$task_id" "$exit_code"
printf 'Run folder: %s\n' "${run_dir#"$root/"}"
if (( exit_code != 0 )); then echo 'Review ignored logs and diff; do not mark the task PASS.' >&2; fi
exit "$exit_code"
