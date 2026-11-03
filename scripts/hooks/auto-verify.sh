#!/usr/bin/env bash
# Claude Code Stop hook: run the project's quick check when the working tree changed.
#
# - Command comes from AGENTS.md > "Quick check command". [NOT CONFIGURED] → do nothing.
# - Skips when nothing changed since the last passing check (fingerprint of diff + untracked files),
#   so a conversation that only reads code costs nothing.
# - On failure, blocks Claude from stopping and returns only the last lines of output (token economy).
# - Gives up after AUTO_VERIFY_MAX_BLOCKS consecutive failures (default 3) and tells the user instead,
#   so it can never loop forever.
# Env: AUTO_VERIFY_TIMEOUT (seconds, default 300), AUTO_VERIFY_TAIL (lines, default 40),
#      AUTO_VERIFY_MAX_BLOCKS (default 3), AUTO_VERIFY_DISABLE=1 to switch off.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cat >/dev/null   # hook input is not needed
[[ "${AUTO_VERIFY_DISABLE:-0}" == 1 ]] && exit 0
cd "$root" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

cmd=''
[[ -f AGENTS.md ]] && cmd="$(sed -n 's/^[[:space:]]*-[[:space:]]*Quick check command:[[:space:]]*//p' AGENTS.md | head -n 1)"
cmd="$(printf '%s' "$cmd" | sed 's/^`//; s/`$//; s/[[:space:]]*$//')"
[[ -z "$cmd" || "$cmd" == '[NOT CONFIGURED]' ]] && exit 0

timeout_s="${AUTO_VERIFY_TIMEOUT:-300}"; tail_n="${AUTO_VERIFY_TAIL:-40}"; max_blocks="${AUTO_VERIFY_MAX_BLOCKS:-3}"
[[ "$timeout_s" =~ ^[0-9]+$ && "$tail_n" =~ ^[0-9]+$ && "$max_blocks" =~ ^[0-9]+$ ]] || exit 0

state_dir="$root/.claude/work-memory"
state="$state_dir/.auto-verify-state"
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

[[ -n "$(git status --porcelain --untracked-files=normal 2>/dev/null)" ]] || exit 0
fp="$(fingerprint)"
last_pass=''; fails=0; last_fail_fp=''
if [[ -f "$state" ]]; then
  last_pass="$(sed -n 's/^PASS=//p' "$state")"
  fails="$(sed -n 's/^FAILS=//p' "$state")"; [[ "$fails" =~ ^[0-9]+$ ]] || fails=0
  last_fail_fp="$(sed -n 's/^FAIL_FP=//p' "$state")"
fi
[[ "$fp" == "$last_pass" ]] && exit 0
# Same failing state as last time and the limit is reached: stay quiet (already reported).
if (( fails > max_blocks )) && [[ "$fp" == "$last_fail_fp" ]]; then exit 0; fi

out="$(mktemp)"; trap 'rm -f "$out"' EXIT
set -m   # own process group, so a timeout also stops children (npm → node, etc.)
bash -c "$cmd" >"$out" 2>&1 </dev/null &
pid=$!
set +m
# Watchdog: detached from our stdout (otherwise the caller waits for the sleep to end) and
# stops its own sleep when cancelled.
(
  sleep "$timeout_s" & sp=$!
  trap 'kill "$sp" 2>/dev/null; exit 0' TERM
  wait "$sp" || exit 0
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  sleep 2
  kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
) >/dev/null 2>&1 </dev/null &
watchdog=$!
wait "$pid"; rc=$?
kill "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null

# Strip ANSI colours and control characters, then encode as a JSON string (with quotes).
clean() { local esc=$'\033'; LC_ALL=C sed "s/${esc}\[[0-9;?]*[A-Za-z]//g" | LC_ALL=C tr -d '\000-\010\013\014\016-\037'; }
json_str() {
  if command -v jq >/dev/null 2>&1; then jq -Rs .
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; print(json.dumps(sys.stdin.buffer.read().decode("utf-8","replace")))'
  else sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r//g' | awk 'BEGIN{ORS="\\n"; printf "\""}{print} END{printf "\""}'
  fi
}

if (( rc == 0 )); then
  printf 'PASS=%s\nFAILS=0\nFAIL_FP=\n' "$fp" > "$state"
  exit 0
fi

fails=$((fails + 1))
printf 'PASS=%s\nFAILS=%s\nFAIL_FP=%s\n' "$last_pass" "$fails" "$fp" > "$state"
label="exit $rc"; (( rc == 143 || rc == 137 )) && label="timed out after ${timeout_s}s"
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
