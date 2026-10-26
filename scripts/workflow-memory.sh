#!/usr/bin/env bash
# Local-only shared checkpoints for Claude and Codex. No model or network calls.
set -euo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
memory_dir="$root/.claude/work-memory"
handoff_dir="$root/.claude/handoffs"

usage() {
  echo 'Usage: bash scripts/workflow-memory.sh init TASK-ID | record-run TASK-ID TASK-ID-run.XXXXXX | show TASK-ID | search QUERY' >&2
}
fail() { echo "ERROR: $*" >&2; exit 2; }
valid_task() {
  [[ "$1" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$ ]] && (( ${#1} <= 72 ))
}
guard_root() {
  [[ "$(git rev-parse --show-toplevel 2>/dev/null || :)" == "$root" ]] || fail 'not at repository root'
  [[ ! -L "$memory_dir" ]] || fail 'memory directory must not be a symlink'
}
ensure_task() {
  local task="$1" dir="$memory_dir/$task"
  [[ ! -L "$dir" ]] || fail 'task directory must not be a symlink'
  mkdir -p "$dir"
  if [[ ! -e "$dir/STATE.md" && ! -L "$dir/STATE.md" ]]; then
    # Exclusive create; do not replace an existing state file.
    ( set -C
      cat > "$dir/STATE.md" <<EOF
# Shared task state — $task

Status: ACTIVE
Source: HUMAN_OR_AGENT_UNVERIFIED
Review: UNVERIFIED

## Objective / approved source
[Link to the approved handoff or canonical plan; do not copy sensitive data.]

## Confirmed decisions
[Only evidence-backed facts and decision references.]

## Current progress and blockers
[What is verified done, blocked, or unverified.]

## Next action
[One concrete step for the next Claude or Codex session.]

## Evidence links
[Git SHA, paths to test results, review records; never secrets or raw transcripts.]
EOF
    ) || fail 'could not initialize task state'
  fi
}

[[ $# -gt 0 ]] || { usage; exit 2; }
cmd="$1"
shift
guard_root
case "$cmd" in
  init)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    task="$1"; valid_task "$task" || fail 'invalid task ID'
    ensure_task "$task"
    echo "Task state: .claude/work-memory/$task/STATE.md"
    ;;
  record-run)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    task="$1"; run="$2"; valid_task "$task" || fail 'invalid task ID'
    [[ "$run" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*-run\.[A-Za-z0-9]{6}$ && "$run" == "$task"-run.* ]] || fail 'invalid run directory'
    [[ ! -L "$handoff_dir" && ! -L "$handoff_dir/$run" && -d "$handoff_dir/$run" ]] || fail 'missing or symlinked run directory'
    path="$handoff_dir/$run"
    [[ -f "$path/status.txt" && ! -L "$path/status.txt" ]] || fail 'missing/symlinked status.txt'
    [[ -f "$path/head-before.txt" && ! -L "$path/head-before.txt" ]] || fail 'missing/symlinked head-before.txt'
    head_sha="$(cat "$path/head-before.txt")"
    [[ "$head_sha" =~ ^[0-9a-fA-F]{40}$ || "$head_sha" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'invalid Git baseline SHA'
    exit_code="$(sed -n 's/^FINAL_EXIT_CODE=\([0-9][0-9]*\)$/\1/p' "$path/status.txt" | head -n1)"
    [[ -n "$exit_code" ]] || fail 'missing final exit code'
    if [[ -f "$path/changed-paths.txt" && ! -L "$path/changed-paths.txt" ]]; then
      paths_count="$(awk 'END { print NR+0 }' "$path/changed-paths.txt")"
    else
      paths_count='UNVERIFIED'
    fi
    ensure_task "$task"
    dir="$memory_dir/$task"
    event="$dir/RUN-$run.md"
    [[ ! -e "$event" && ! -L "$event" ]] || fail 'run checkpoint already exists; refusing overwrite'
    ( set -C
      cat > "$event" <<EOF
# Codex run evidence — $task

Run: .claude/handoffs/$run/
Baseline HEAD: $head_sha
Reported final exit code: $exit_code
Changed paths count: $paths_count
Acceptance review: UNVERIFIED
Evidence: .claude/handoffs/$run/status.txt; .claude/handoffs/$run/changed-paths.txt; .claude/handoffs/$run/completion.md

The exit code reports CLI execution only. Claude must independently review actual diff, acceptance criteria and test evidence.
No raw logs, prompts or model completion text is copied here.
EOF
    ) || fail 'cannot write checkpoint'
    # LATEST.md is machine-created; atomically replace only this pointer file.
    [[ ! -L "$dir/LATEST.md" ]] || fail 'latest pointer must not be a symlink'
    temp="$(mktemp "$dir/.LATEST.XXXXXX")"
    printf '# Latest recorded Codex run\n\nTask: %s\nCheckpoint: %s\nReported final exit code: %s\nReview: UNVERIFIED\nNext action: Claude independently reviews the changes and updates STATE.md.\n' "$task" "RUN-$run.md" "$exit_code" > "$temp"
    mv -f "$temp" "$dir/LATEST.md"
    echo "Checkpoint recorded: .claude/work-memory/$task/RUN-$run.md"
    ;;
  show)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    task="$1"; valid_task "$task" || fail 'invalid task ID'
    dir="$memory_dir/$task"
    [[ -f "$dir/STATE.md" && ! -L "$dir" && ! -L "$dir/STATE.md" ]] || fail 'no such task state'
    cat "$dir/STATE.md"
    if [[ -f "$dir/LATEST.md" && ! -L "$dir/LATEST.md" ]]; then
      printf '\n---\n'
      cat "$dir/LATEST.md"
    fi
    ;;
  search)
    [[ $# -eq 1 && -n "$1" && ${#1} -le 160 ]] || fail 'search phrase required, max 160 characters'
    [[ -d "$memory_dir" ]] || exit 0
    # Bounded, lexical, project-local search. Never inspect logs or outside scopes.
    count=0
    while IFS= read -r -d '' state; do
      [[ ! -L "$state" ]] || continue
      if grep -qFi -- "$1" "$state"; then
        printf '%s\n' "${state#"$root/"}"
        count=$((count+1))
        if (( count >= 20 )); then break; fi
      fi
    done < <(find "$memory_dir" -type f -name STATE.md -print0)
    ;;
  *) usage; exit 2 ;;
esac
