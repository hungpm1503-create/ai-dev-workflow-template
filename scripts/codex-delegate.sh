#!/usr/bin/env bash
# Run one explicitly approved handoff. Requires a clean Git worktree.
# The whole script is one { ... } block so Bash parses it completely before running it:
# a delegated task may legitimately edit this file, and Bash otherwise reads scripts
# incrementally, which would corrupt the post-run protected-path check.
{
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

handoff_dir="$root/.workflow/handoffs"
handoff="$handoff_dir/$task_id.md"
legacy_handoff="$root/.claude/handoffs/$task_id.md"
if [[ ! -e "$handoff" && ! -L "$handoff" && -f "$legacy_handoff" ]]; then
  handoff="$legacy_handoff"
fi
if [[ -L "$handoff_dir" || -L "$(dirname "$handoff")" || ! -f "$handoff" || -L "$handoff" || ! -s "$handoff" ]]; then
  echo 'ERROR: approved handoff not found, empty, or symlinked.' >&2
  exit 2
fi
if [[ "$handoff" == "$legacy_handoff" ]]; then
  echo "WARNING: .claude/handoffs/$task_id.md is deprecated; move it to .workflow/handoffs/." >&2
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

reasoning_effort="${CODEX_REASONING_EFFORT:-}"
case "$reasoning_effort" in
  ''|minimal|low|medium|high|xhigh) ;;
  *) echo 'ERROR: CODEX_REASONING_EFFORT must be minimal, low, medium, high or xhigh.' >&2; exit 2 ;;
esac

if (( dry_run )); then
  echo "DRY RUN: approved handoff ${handoff#"$root/"}"
  dry_network=false; if [[ "${CODEX_NETWORK:-0}" == 1 ]]; then dry_network=true; fi
  echo "Reasoning effort: ${reasoning_effort:-default}"
  echo "Would invoke: codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=$dry_network${reasoning_effort:+ -c model_reasoning_effort=\"$reasoning_effort\"} --output-last-message <run>/completion.md -"
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
mkdir -p "$handoff_dir"
lock_dir="$handoff_dir/.codex-delegate.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo 'ERROR: another Codex task holds this worktree lock; inspect it before manually removing a stale lock.' >&2
  exit 5
fi
printf '%s\n' "$$" > "$lock_dir/pid"
codex_pid=''
watchdog_pid=''
# A process group exists as long as it has non-zombie members. A zombie may keep
# kill -0 successful briefly after SIGKILL but can no longer execute code.
group_active() {
  local listing
  listing="$(ps -eo pgid=,stat= 2>/dev/null)" || {
    echo 'WARNING: cannot inspect process groups; conservatively retaining the lock.' >&2
    return 0
  }
  printf '%s\n' "$listing" | awk -v pgid="$1" '
    $1 == pgid && $2 !~ /^Z/ { found=1; exit }
    END { exit found ? 0 : 1 }
  '
}
# Allow kernel/process supervisor up to 5 seconds to reap after a forced stop.
wait_group_quiet() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if ! group_active "$1"; then return 0; fi
    sleep 0.5
  done
  ! group_active "$1"
}
stop_group() {
  local pgid="$1"
  if ! group_active "$pgid"; then return 0; fi
  kill -TERM -- "-$pgid" 2>/dev/null || :
  sleep 2
  if group_active "$pgid"; then kill -KILL -- "-$pgid" 2>/dev/null || :; fi
  wait_group_quiet "$pgid"
}
cleanup() {
  # Keep the lock only if a non-zombie descendant may still be executing.
  if [[ -n "$codex_pid" ]] && group_active "$codex_pid"; then
    printf 'WARNING: live Codex group %s remains; inspect it before removing the lock.\n' "$codex_pid" >&2
    return
  fi
  rm -f "$lock_dir/pid"
  rmdir "$lock_dir" >/dev/null 2>&1 || :
}
on_interrupt() {
  trap '' INT TERM
  if [[ -n "$watchdog_pid" ]]; then
    kill "$watchdog_pid" 2>/dev/null || :
    wait "$watchdog_pid" 2>/dev/null || :
  fi
  if [[ -n "$codex_pid" ]]; then
    stop_group "$codex_pid" || :
    wait "$codex_pid" 2>/dev/null || :
  fi
  exit 130
}
trap cleanup EXIT
trap on_interrupt INT TERM
run_dir="$(mktemp -d "$handoff_dir/$task_id-run.XXXXXX")"
result="$run_dir/completion.md"
log="$run_dir/codex.log"
status="$run_dir/status.txt"
prompt="$run_dir/prompt.md"
before="$run_dir/status-before.txt"
head_sha="$(git rev-parse HEAD)"
printf '%s\n' "$head_sha" > "$run_dir/head-before.txt"
printf '%s\n' "${reasoning_effort:-default}" > "$run_dir/effort.txt"
git status --porcelain=v1 --untracked-files=all > "$before"
if [[ -s "$before" ]]; then
  echo 'ERROR: working tree is dirty. Commit, safely stash, or isolate your changes before delegating; no changes were made.' >&2
  printf 'RESULT=BLOCKED_DIRTY_WORKTREE\n' > "$status"
  exit 6
fi

# Snapshot protected paths before Codex can change AGENTS.md.
{
  printf '%s\n' 'CLAUDE.md' 'AGENTS.md' 'scripts/codex-delegate.sh' 'scripts/hooks/' '.claude/settings.json' '.claude/skills/' '.github/workflows/'
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
    'Start from the files listed in the handoff and open other files only when needed to satisfy the acceptance criteria.'
  if [[ -f "$root/docs/workflow/codex-rules.md" ]]; then
    printf '\n%s\n' '--- BEGIN CODEX RULES ---'
    cat "$root/docs/workflow/codex-rules.md"
    printf '\n%s\n' '--- END CODEX RULES ---'
  fi
  printf '\n%s\n' '--- BEGIN APPROVED HANDOFF ---'
  cat "$handoff"
  printf '\n%s\n' '--- END APPROVED HANDOFF ---'
} > "$prompt"

# Network is always set explicitly so ~/.codex/config.toml cannot silently enable it.
# Opt in per run with CODEX_NETWORK=1 (e.g. dependency installs); sandbox stays workspace-write.
network_access=false
if [[ "${CODEX_NETWORK:-0}" == 1 ]]; then network_access=true; fi
codex_args=(exec --sandbox workspace-write -c "sandbox_workspace_write.network_access=$network_access")
if [[ -n "$reasoning_effort" ]]; then codex_args+=(-c "model_reasoning_effort=\"$reasoning_effort\""); fi
printf 'NETWORK_ACCESS=%s\n' "$network_access" > "$run_dir/network.txt"
# Launch Codex in a dedicated process group (Bash job control also works on macOS Bash 3.2).
# This lets the watchdog terminate child tools, not just the Codex parent.
set -m
codex "${codex_args[@]}" --output-last-message "$result" - < "$prompt" > "$log" 2>&1 &
codex_pid=$!
set +m
(
  sleep "$((10#$timeout_seconds))" &
  sleep_pid=$!
  trap 'kill "$sleep_pid" 2>/dev/null || :; exit 0' TERM INT
  wait "$sleep_pid" || exit 0
  # Timeout is checked against the whole group, including surviving child processes.
  if group_active "$codex_pid"; then
    printf '%s\n' 'TIMEOUT' > "$run_dir/timed-out.txt"
    kill -TERM -- "-$codex_pid" 2>/dev/null || :
    sleep 3
    if group_active "$codex_pid"; then kill -KILL -- "-$codex_pid" 2>/dev/null || :; fi
  fi
) >/dev/null 2>&1 </dev/null &
watchdog_pid=$!
if wait "$codex_pid"; then exit_code=0; else exit_code=$?; fi
# The process group can outlive its leader; stop descendants before releasing the lock.
if group_active "$codex_pid"; then
  stop_group "$codex_pid" || :
fi
kill "$watchdog_pid" 2>/dev/null || :
wait "$watchdog_pid" 2>/dev/null || :
codex_exit_code="$exit_code"
if [[ -f "$run_dir/timed-out.txt" ]]; then exit_code=124; fi
if group_active "$codex_pid"; then
  printf '%s\n' 'WARNING: Codex descendants survived forced shutdown. Inspect process group and lock.' >&2
  exit_code=125
fi

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
quick_check_exit=SKIPPED
quick_log="$run_dir/quick-check.log"
if (( exit_code == 124 || exit_code == 125 )); then
  printf '%s\n' 'Quick check skipped: Codex timed out or left processes; tree state is not final.' > "$quick_log"
elif [[ "${CODEX_QUICK_CHECK:-1}" != 0 ]]; then
  if bash "$root/scripts/hooks/auto-verify.sh" --check-now > "$quick_log" 2>&1; then
    quick_check_exit=0
    if grep -Fq 'Quick check not configured; skipped.' "$quick_log"; then quick_check_exit=SKIPPED; fi
  else
    quick_check_exit=$?
    if (( exit_code == 0 )); then exit_code=7; fi
  fi
else
  printf '%s\n' 'Quick check disabled by CODEX_QUICK_CHECK=0.' > "$quick_log"
fi
printf 'CODEX_EXIT_CODE=%s\nQUICK_CHECK_EXIT=%s\nFINAL_EXIT_CODE=%s\nHEAD_BEFORE=%s\n' "$codex_exit_code" "$quick_check_exit" "$exit_code" "$head_sha" > "$status"

# Deterministic, local-only memory checkpoint (best effort); never change the Codex verdict.
if [[ -f "$root/scripts/workflow-memory.sh" ]]; then
  if ! bash "$root/scripts/workflow-memory.sh" record-run "$task_id" "$(basename "$run_dir")" >> "$log" 2>&1; then
    echo "WARNING: working-memory checkpoint failed; Codex result remains $exit_code." >&2
  fi
fi
printf 'Final exit code: %s\n' "$exit_code"
printf 'Changed files:\n'
summary_files="$run_dir/summary-files.txt"
git diff --numstat HEAD | awk -F '\t' '{printf "  %s (+%s/-%s)\n", $3, $1, $2}' > "$summary_files"
git ls-files --others --exclude-standard | sed 's/^/  /; s/$/ (new)/' >> "$summary_files"
head -n 6 "$summary_files"
file_count="$(wc -l < "$summary_files" | tr -d ' ')"
if (( file_count > 6 )); then printf '  ... %s more\n' "$((file_count - 6))"; fi
if [[ -s "$run_dir/protected-violations.txt" ]]; then
  printf 'Protected violations:\n'
  head -n 3 "$run_dir/protected-violations.txt" | sed 's/^/  /'
fi
printf 'Quick check: %s\n' "$quick_check_exit"
if [[ "$quick_check_exit" != SKIPPED && "$quick_check_exit" != 0 ]]; then
  tail -n 8 "$quick_log" | sed 's/^/  /'
elif [[ -s "$quick_log" ]]; then
  head -n 1 "$quick_log" | sed 's/^/  /'
fi
if [[ -f "$result" ]]; then
  grep -E '^AC-|\| AC-' "$result" | head -n 3 || :
fi
printf 'Run folder: %s\n' "${run_dir#"$root/"}"
if (( exit_code != 0 )); then echo 'Review ignored logs and diff; do not mark the task PASS.' >&2; fi
exit "$exit_code"
}
