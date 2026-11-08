#!/usr/bin/env bash
# Opt-in per-prompt metrics. Never outputs context or calls a model.
set -euo pipefail
[[ "${WORKFLOW_METRICS:-0}" == 1 ]] || exit 0
[[ $# == 1 && ( "$1" == start || "$1" == finish ) ]] || exit 0
event="$1"
root="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
[[ "$(git rev-parse --show-toplevel 2>/dev/null || :)" == "$root" ]] || exit 0

# Parse only session/transcript metadata. Do not persist prompts or hook JSON.
if command -v python3 >/dev/null 2>&1; then
  fields="$(python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    session=d.get("session_id","")
    transcript=d.get("transcript_path","")
    if not isinstance(session,str) or not isinstance(transcript,str): sys.exit(0)
    if not session or any(c in session+transcript for c in "\t\n\r"): sys.exit(0)
    print(session+"\t"+transcript)
except (ValueError,TypeError): pass
' 2>/dev/null || :)"
elif command -v jq >/dev/null 2>&1; then
  fields="$(jq -r 'if (.session_id | type) == "string" and (.transcript_path | type) == "string" then [.session_id, .transcript_path] | @tsv else empty end' 2>/dev/null || :)"
else
  exit 0
fi
[[ "$fields" == *$'\t'* ]] || exit 0
IFS=$'\t' read -r session transcript <<< "$fields"
[[ -n "$session" ]] || exit 0
key="$(printf '%s' "$session" | git hash-object --stdin | cut -c1-16)"
state_dir="$root/.workflow/metrics/hook-state"
[[ ! -L "$root/.workflow" && ! -L "$root/.workflow/metrics" && ! -L "$state_dir" ]] || exit 0
mkdir -p "$state_dir" || exit 0
active="$state_dir/$key.active"
[[ ! -L "$active" ]] || exit 0
if [[ "$event" == start ]]; then
  task="TASK-HOOK-$key-$(date +%s)-$$"
  if WORKFLOW_METRICS_TRANSCRIPT="$transcript" bash "$root/scripts/workflow-metrics.sh" start "$task" >/dev/null 2>&1; then
    tmp="$(mktemp "$state_dir/.active.XXXXXX")" || exit 0
    printf '%s\n' "$task" > "$tmp"
    mv "$tmp" "$active"
  fi
else
  [[ -f "$active" ]] || exit 0
  task="$(cat "$active")"
  [[ "$task" =~ ^TASK-HOOK-[0-9a-f]{16}-[0-9]+-[0-9]+$ ]] || exit 0
  [[ -f "$root/.workflow/metrics/$task.start" ]] || exit 0
  bash "$root/scripts/workflow-metrics.sh" finish "$task" >/dev/null 2>&1 || :
fi
