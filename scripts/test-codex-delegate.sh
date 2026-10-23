#!/usr/bin/env bash
# Regression tests use a fake Codex binary only. No model/API use.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
tmp="$(mktemp -d)"
id="TASK-SMOKE-$$"
handoffs="$root/.claude/handoffs"
handoff="$handoffs/$id.md"
probe="$root/.github/workflows/.protected-probe-$$"
mkdir -p "$handoffs"
cleanup() {
  rm -f "$handoff" "$probe"
  find "$handoffs" -maxdepth 1 -type d -name "$id-run.*" -exec rm -rf {} +
  rmdir "$handoffs/.codex-delegate.lock" 2>/dev/null || :
  rm -rf "$tmp"
}
trap cleanup EXIT

cat > "$tmp/codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >> "${FAKE_INVOKED:?}"
[[ "${1:-}" == exec ]] || exit 41
shift
out=''; sandbox=''; stdin_flag=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sandbox) sandbox="$2"; shift 2;;
    --output-last-message) out="$2"; shift 2;;
    -) stdin_flag='-'; shift;;
    *) exit 42;;
  esac
done
[[ "$sandbox" == workspace-write && "$stdin_flag" == '-' && -n "$out" ]] || exit 43
if [[ -n "${FAKE_PROTECTED_PATH:-}" ]]; then
  printf 'unauthorized\n' > "$FAKE_PROTECTED_PATH"
fi
if [[ -n "${FAKE_SLEEP:-}" ]]; then sleep "$FAKE_SLEEP"; fi
if [[ "${FAKE_SKIP_STDIN:-0}" != 1 ]]; then cat > "${FAKE_PROMPT_FILE:?}"; fi
printf 'AC-01: PASS (fake Codex only)\n' > "$out"
exit "${FAKE_CODEX_EXIT:-0}"
FAKE
chmod +x "$tmp/codex"
export PATH="$tmp:$PATH" FAKE_INVOKED="$tmp/invoked.txt" FAKE_PROMPT_FILE="$tmp/prompt.txt"

cat > "$handoff" <<'TASK'
## Task ID
TASK-SMOKE
## Approval status
Status: PENDING
## Objective
Simulated no-op
TASK

# PENDING and NOT APPROVED both must fail closed.
for state in PENDING 'NOT APPROVED'; do
  sed -i.bak "s/^Status:.*/Status: $state/" "$handoff"; rm -f "$handoff.bak"
  if bash scripts/codex-delegate.sh "$id" > "$tmp/approval.txt" 2>&1; then
    echo "FAIL: accepted $state approval" >&2; exit 1
  else [[ $? == 3 ]] || { echo 'FAIL: unexpected approval exit' >&2; exit 1; }; fi
done
[[ ! -e "$FAKE_INVOKED" ]] || { echo 'FAIL: invoked Codex without approval' >&2; exit 1; }
sed -i.bak 's/^Status:.*/Status: APPROVED/' "$handoff"; rm -f "$handoff.bak"

bash scripts/codex-delegate.sh --dry-run "$id" > "$tmp/dry.txt"
[[ ! -e "$FAKE_INVOKED" ]] || { echo 'FAIL: dry-run invoked fake Codex' >&2; exit 1; }
if bash scripts/codex-delegate.sh '../escape' >/dev/null 2>&1; then
  echo 'FAIL: path traversal accepted' >&2; exit 1
fi

# Repository must be clean (handoff and run logs are ignored).
printf 'dirty\n' > ".dirty-worktree-probe-$$"
if bash scripts/codex-delegate.sh "$id" > "$tmp/dirty.txt" 2>&1; then
  echo 'FAIL: accepted a dirty worktree' >&2; exit 1
else [[ $? == 6 ]] || { echo 'FAIL: dirty worktree error code' >&2; exit 1; }; fi
rm -f ".dirty-worktree-probe-$$"

bash scripts/codex-delegate.sh "$id" > "$tmp/success.txt"
grep -q 'BEGIN APPROVED HANDOFF' "$FAKE_PROMPT_FILE"
grep -q 'Final exit code: 0' "$tmp/success.txt"
grep -q 'AC-01: PASS' "$handoffs"/"$id"-run.*/completion.md

if FAKE_CODEX_EXIT=9 bash scripts/codex-delegate.sh "$id" > "$tmp/failure.txt" 2>&1; then
  echo 'FAIL: lost Codex failure exit code' >&2; exit 1
else [[ $? == 9 ]] || { echo 'FAIL: wrong Codex exit code' >&2; exit 1; }; fi

# Early exit without reading stdin, with 400KB+ handoff: no SIGPIPE/141.
awk 'BEGIN {for (i=0; i<10000; i++) print "0123456789012345678901234567890123456789"}' >> "$handoff"
FAKE_SKIP_STDIN=1 bash scripts/codex-delegate.sh "$id" > "$tmp/early-exit.txt"
grep -q 'Final exit code: 0' "$tmp/early-exit.txt"

# Existing default protected directory must trigger FAIL without reverting edits.
if FAKE_PROTECTED_PATH="$probe" bash scripts/codex-delegate.sh "$id" > "$tmp/protected.txt" 2>&1; then
  echo 'FAIL: protected-path change accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: protected-path error code' >&2; exit 1; }; fi
rm -f "$probe"

# Concurrent invocations on same tree: second must be blocked by atomic lock.
FAKE_SLEEP=3 bash scripts/codex-delegate.sh "$id" > "$tmp/background.txt" 2>&1 &
background_pid=$!
ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [[ -d "$handoffs/.codex-delegate.lock" ]]; then ready=1; break; fi
  sleep 0.1
done
[[ "$ready" == 1 ]] || { echo 'FAIL: lock not acquired' >&2; exit 1; }
if bash scripts/codex-delegate.sh "$id" > "$tmp/locked.txt" 2>&1; then
  echo 'FAIL: concurrent invocation accepted' >&2; exit 1
else [[ $? == 5 ]] || { echo 'FAIL: unexpected lock error code' >&2; exit 1; }; fi
wait "$background_pid"

# Timed-out fake Codex cannot be reported as a successful task.
if CODEX_TIMEOUT_SECONDS=1 FAKE_SLEEP=6 bash scripts/codex-delegate.sh "$id" > "$tmp/timed-out.txt" 2>&1; then
  echo 'FAIL: time limit not enforced' >&2; exit 1
else [[ $? == 124 ]] || { echo 'FAIL: timeout exit code not 124' >&2; exit 1; }; fi

echo 'PASS: fake-Codex approval, dry-run, traversal, clean tree, early exit, protected paths, locking, timeout and exit-code tests'
