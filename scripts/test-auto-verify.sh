#!/usr/bin/env bash
# Offline tests for the Claude Code Stop hook (scripts/hooks/auto-verify.sh). No model/API use.
# Runs in a throwaway Git repository; never touches this repository's state.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$root/scripts/hooks/auto-verify.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; count="$tmp/count"
fail() { echo "FAIL: $*" >&2; exit 1; }

grep -Fq 'auto-verify.sh' "$root/.claude/settings.json" || fail 'Stop hook not registered in settings.json'
grep -Fq 'Quick check command:' "$root/AGENTS.md" || fail 'AGENTS.md lacks Quick check command'

mkdir -p "$repo" && cd "$repo"
git init -q && git config user.email t@example.com && git config user.name t
printf '.claude/work-memory/\n' > .gitignore
set_cmd() { printf -- '- Quick check command: %s\n' "$1" > AGENTS.md; git add -A; git commit -qm cfg; }
run() { printf '{"hook_event_name":"Stop","stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$repo" bash "$hook"; }
runs() { [[ -f "$count" ]] && wc -l < "$count" | tr -d ' ' || echo 0; }
valid_json() {
  python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null \
    || node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>JSON.parse(s))'
}

# 1. Not configured → silent, nothing runs.
set_cmd '[NOT CONFIGURED]'; echo a > a.txt
[[ -z "$(run)" && "$(runs)" == 0 ]] || fail 'ran while not configured'

# 2. Configured but clean tree → silent, nothing runs.
rm a.txt; set_cmd "echo run >> '$count'"
[[ -z "$(run)" && "$(runs)" == 0 ]] || fail 'ran on a clean tree'

# 3. Change + passing check → silent; unchanged state is not re-checked.
echo b > b.txt
[[ -z "$(run)" && "$(runs)" == 1 ]] || fail 'passing check should run once silently'
[[ -z "$(run)" && "$(runs)" == 1 ]] || fail 'unchanged passing state was re-checked'
echo c >> b.txt
[[ -z "$(run)" && "$(runs)" == 2 ]] || fail 'new change was not re-checked'

# 4. Failing check → block with valid JSON, only the tail, ANSI and quotes handled.
git add -A; git commit -qm b
set_cmd "echo run >> '$count'; for i in \$(seq 1 100); do printf 'line-%s \"q\" \\\\ \\033[31mred\\033[0m\\n' \$i; done; exit 3"
echo d > d.txt
out="$(run)"
printf '%s' "$out" | valid_json || fail "block output is not valid JSON: $out"
grep -q '"decision":"block"' <<<"$out" || fail 'failing check did not block'
grep -q 'exit 3' <<<"$out" || fail 'exit code missing'
grep -q 'line-100' <<<"$out" || fail 'tail missing'
grep -q 'line-1 ' <<<"$out" && fail 'output not truncated to tail'
grep -q $'\033' <<<"$out" && fail 'ANSI escape leaked'

# 5. Attempt limit: blocks up to 3 times, then tells the user once, then stays quiet.
out="$(run)"; grep -q 'attempt 2/3' <<<"$out" || fail 'second attempt not reported'
out="$(run)"; grep -q 'attempt 3/3' <<<"$out" || fail 'third attempt not reported'
out="$(run)"; grep -q '"systemMessage"' <<<"$out" || fail 'limit message missing'
grep -q '"decision"' <<<"$out" && fail 'still blocking after limit'
before="$(runs)"; out="$(run)"
[[ -z "$out" && "$(runs)" == "$before" ]] || fail 'kept re-running the same failing state after limit'
# A new change resets nothing silently: it is checked again (and reported).
echo e > e.txt; out="$(run)"; [[ -n "$out" ]] || fail 'new change after limit not checked'

# 6. Passing again clears the failure counter.
set_cmd "echo run >> '$count'"; echo f > f.txt
[[ -z "$(run)" ]] || fail 'pass after failures should be silent'
grep -q '^FAILS=0$' .claude/work-memory/.auto-verify-state || fail 'failure counter not reset'

# 7. Timeout stops the command and its children.
marker="23.$$"; set_cmd "bash -c 'sleep $marker'"; echo g > g.txt
start=$(date +%s); out="$(AUTO_VERIFY_TIMEOUT=1 run)"; elapsed=$(( $(date +%s) - start ))
grep -q 'timed out after 1s' <<<"$out" || fail "timeout not reported: $out"
(( elapsed < 10 )) || fail "timeout took ${elapsed}s"
sleep 1; pgrep -f "sleep $marker" >/dev/null && fail 'child process survived timeout'

# 8. Kill switch.
echo h > h.txt; [[ -z "$(AUTO_VERIFY_DISABLE=1 run)" ]] || fail 'AUTO_VERIFY_DISABLE ignored'

echo 'PASS: auto-verify Stop hook: config gate, change detection, tail-only JSON, attempt limit, reset, timeout, kill switch'
