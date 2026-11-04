#!/usr/bin/env bash
# Claude Code hook: run the project's quick check on changes that have not been verified yet.
#
#   UserPromptSubmit:  auto-verify.sh --mark-turn-start   records a baseline fingerprint
#   Stop:              auto-verify.sh                     checks if anything changed since then
#
# - Command comes from AGENTS.md > "Quick check command". [NOT CONFIGURED], N/A and NONE → do nothing.
# - Fingerprint = HEAD + diff against HEAD + untracked files (names and contents).
# - Stop skips when: the tree is clean; the fingerprint equals this turn's baseline (the turn
#   changed nothing — e.g. a question-only turn on an already dirty tree); or the same state
#   already passed. Without a baseline (UserPromptSubmit hook not installed) it falls back to
#   "any unverified changes in the working tree".
# - On failure, blocks Claude from stopping and returns only the last lines of output (token economy).
# - Gives up after AUTO_VERIFY_MAX_BLOCKS failures in one turn (default 3) and tells the user instead,
#   so it can never loop forever. A new user prompt resets the count.
# Env: AUTO_VERIFY_TIMEOUT (seconds, default 300), AUTO_VERIFY_TAIL (lines, default 40),
#      AUTO_VERIFY_MAX_BLOCKS (default 3), AUTO_VERIFY_DISABLE=1 to switch off.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
check_now=0
[[ "${1:-}" == --check-now ]] && check_now=1
if (( ! check_now )); then cat >/dev/null; fi   # hook input is not needed
[[ "${AUTO_VERIFY_DISABLE:-0}" == 1 ]] && exit 0
cd "$root" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

cmd=''
[[ -f AGENTS.md ]] && cmd="$(sed -n 's/^[[:space:]]*-[[:space:]]*Quick check command:[[:space:]]*//p' AGENTS.md | head -n 1)"
cmd="$(printf '%s' "$cmd" | sed 's/^`//; s/`$//; s/[[:space:]]*$//')"
if [[ -z "$cmd" || "$cmd" == '[NOT CONFIGURED]' || "$cmd" == 'N/A' || "$cmd" == 'NONE' ]]; then
  if (( check_now )); then echo 'Quick check not configured; skipped.'; fi
  exit 0
fi

timeout_s="${AUTO_VERIFY_TIMEOUT:-300}"; tail_n="${AUTO_VERIFY_TAIL:-40}"; max_blocks="${AUTO_VERIFY_MAX_BLOCKS:-3}"
[[ "$timeout_s" =~ ^[0-9]+$ && "$tail_n" =~ ^[0-9]+$ && "$max_blocks" =~ ^[0-9]+$ ]] || exit 0

state_dir="$root/.workflow/work-memory"
state="$state_dir/.auto-verify-state"
turn_file="$state_dir/.auto-verify-turn"
mkdir -p "$state_dir" 2>/dev/null || exit 0

hash_cmd() { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; }
fingerprint() {
  {
    git rev-parse HEAD 2>/dev/null
    git diff HEAD --no-ext-diff 2>/dev/null
    git ls-files --others --exclude-standard -z 2>/dev/null | while IFS= read -r -d '' f; do
      printf '%s\n' "$f"; [[ -f "$f" ]] && hash_cmd < "$f"
    done
  } | hash_cmd | cut -d' ' -f1
}

if [[ "${1:-}" == --mark-turn-start ]]; then
  printf '%s\n' "$(fingerprint)" > "$turn_file"
  # The attempt limit is per turn: a new user prompt gets a fresh set of attempts.
  if [[ -f "$state" ]]; then
    printf 'PASS=%s\nFAILS=0\nFAIL_FP=\n' "$(sed -n 's/^PASS=//p' "$state")" > "$state"
  fi
  exit 0
fi

if (( ! check_now )); then
  [[ -n "$(git status --porcelain --untracked-files=normal 2>/dev/null)" ]] || exit 0
fi
fp="$(fingerprint)"
# This turn did not change anything (question-only turn, possibly on an already dirty tree).
if (( ! check_now )) && [[ -f "$turn_file" && "$(cat "$turn_file")" == "$fp" ]]; then exit 0; fi
last_pass=''; fails=0; last_fail_fp=''
if [[ -f "$state" ]]; then
  last_pass="$(sed -n 's/^PASS=//p' "$state")"
  fails="$(sed -n 's/^FAILS=//p' "$state")"; [[ "$fails" =~ ^[0-9]+$ ]] || fails=0
  last_fail_fp="$(sed -n 's/^FAIL_FP=//p' "$state")"
fi
if (( ! check_now )) && [[ "$fp" == "$last_pass" ]]; then exit 0; fi
# Same failing state as last time and the limit is reached: stay quiet (already reported).
if (( ! check_now && fails > max_blocks )) && [[ "$fp" == "$last_fail_fp" ]]; then exit 0; fi

out="$(mktemp)"; trap 'rm -f "$out" "$out.timedout"' EXIT
set -m   # own process group, so a timeout also stops children (npm → node, etc.)
bash -c "$cmd" >"$out" 2>&1 </dev/null &
pid=$!
set +m
# Watchdog: detached from our stdout (otherwise the caller waits for its sleep). Once it fires it
# ignores cancellation and always escalates TERM → KILL on the whole process group, because the
# main process may exit on TERM while children that ignore TERM keep running.
timed_out="$out.timedout"
(
  sleep "$timeout_s" & sp=$!
  trap 'kill "$sp" 2>/dev/null; exit 0' TERM
  wait "$sp" || exit 0
  trap '' TERM
  : > "$timed_out"
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  sleep 2
  kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
) >/dev/null 2>&1 </dev/null &
watchdog=$!
# Intentional signal-based cancellation should not leak Bash job-control messages.
wait "$pid" 2>/dev/null; rc=$?
if [[ -f "$timed_out" ]]; then
  wait "$watchdog" 2>/dev/null          # let it finish the KILL step; do not cancel it
  kill -KILL -- "-$pid" 2>/dev/null || :  # belt and braces: nothing in the group may survive
else
  kill "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null
fi

# Strip ANSI colours and control characters, then encode as a JSON string (with quotes).
clean() { local esc=$'\033'; LC_ALL=C sed "s/${esc}\[[0-9;?]*[A-Za-z]//g" | LC_ALL=C tr -d '\000-\010\013\014\016-\037'; }
json_str() {
  if command -v jq >/dev/null 2>&1; then jq -Rs .
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; print(json.dumps(sys.stdin.buffer.read().decode("utf-8","replace")))'
  else sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r//g' | awk 'BEGIN{ORS="\\n"; printf "\""}{print} END{printf "\""}'
  fi
}

if (( rc == 0 )) && [[ ! -f "$timed_out" ]]; then
  printf 'PASS=%s\nFAILS=0\nFAIL_FP=\n' "$fp" > "$state"
  if (( check_now )); then  # evidence for the caller, so nobody re-runs the check just to see it
    printf 'Quick check PASS (exit 0): %s\n' "$cmd"
    tail -n 5 "$out" | clean
  fi
  exit 0
fi

if (( check_now )); then
  [[ -f "$timed_out" ]] && rc=124
  printf 'PASS=\nFAILS=0\nFAIL_FP=\n' > "$state"
  tail -n "$tail_n" "$out" | clean
  exit "$rc"
fi

fails=$((fails + 1))
printf 'PASS=%s\nFAILS=%s\nFAIL_FP=%s\n' "$last_pass" "$fails" "$fp" > "$state"
label="exit $rc"; [[ -f "$timed_out" ]] && label="timed out after ${timeout_s}s"
if (( fails <= max_blocks )); then
  reason="$( { printf 'Auto-verify: quick check failed (%s), attempt %s/%s.\nCommand: %s\nLast %s lines:\n' "$label" "$fails" "$max_blocks" "$cmd" "$tail_n"
               tail -n "$tail_n" "$out" | clean
               printf '\nFix the failure, or explain why it is out of scope. Do not claim PASS.\n'; } | json_str)"
  printf '{"decision":"block","reason":%s}\n' "$reason"
else
  msg="$(printf 'Auto-verify still failing after %s attempts (%s). Command: %s. Review manually or set AUTO_VERIFY_DISABLE=1.' "$max_blocks" "$label" "$cmd" | json_str)"
  printf '{"systemMessage":%s}\n' "$msg"
fi
exit 0
