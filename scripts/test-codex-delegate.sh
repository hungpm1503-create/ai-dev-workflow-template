#!/usr/bin/env bash
# Regression tests use a fake Codex binary only. No model/API use.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
tmp="$(mktemp -d)"
id="TASK-SMOKE-$$"
handoffs="$root/.workflow/handoffs"
handoff="$handoffs/$id.md"
legacy_handoff="$root/.claude/handoffs/$id.md"
probe="$root/.github/workflows/.protected-probe-$$"
mkdir -p "$handoffs"
cleanup() {
  rm -f "$handoff" "$legacy_handoff" "$probe"
  rm -rf "$root/.workflow/work-memory/$id"
  find "$handoffs" -maxdepth 1 -type d -name "$id-run.*" -exec rm -rf {} +
  rmdir "$handoffs/.codex-delegate.lock" 2>/dev/null || :
  rm -rf "$tmp"
}
trap cleanup EXIT

cat > "$tmp/codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >> "${FAKE_INVOKED:?}"
if [[ -n "${FAKE_PGID_FILE:-}" ]]; then printf '%s\n' "$$" > "$FAKE_PGID_FILE"; fi
[[ "${1:-}" == exec ]] || exit 41
shift
out=''; sandbox=''; stdin_flag=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sandbox) sandbox="$2"; shift 2;;
    --output-last-message) out="$2"; shift 2;;
    -c) printf '%s\n' "$2" >> "${FAKE_CONFIG_FILE:-/dev/null}"; shift 2;;
    -) stdin_flag='-'; shift;;
    *) exit 42;;
  esac
done
[[ "$sandbox" == workspace-write && "$stdin_flag" == '-' && -n "$out" ]] || exit 43
if [[ -n "${FAKE_PROTECTED_PATH:-}" ]]; then
  printf 'unauthorized\n' > "$FAKE_PROTECTED_PATH"
fi
if [[ -n "${FAKE_CHANGED_PATH:-}" ]]; then
  printf 'new line\n' > "$FAKE_CHANGED_PATH"
fi
if [[ "${FAKE_STUBBORN_CHILD:-0}" == 1 ]]; then
  # A child survives TERM unless the watchdog escalates to KILL against the group.
  bash -c 'trap "" TERM; while :; do sleep 0.3; done' &
fi
if [[ "${FAKE_SELF_EDIT:-0}" == 1 ]]; then
  # Rewrite the running wrapper in place (same inode), shifting every byte offset after the edit.
  { printf '# line inserted by the delegated task\n%.0s' 1 2 3 4 5 6 7 8; cat scripts/codex-delegate.sh; } > "$out.self"
  cat "$out.self" > scripts/codex-delegate.sh; rm -f "$out.self"
fi
if [[ -n "${FAKE_SLEEP:-}" ]]; then sleep "$FAKE_SLEEP"; fi
if [[ "${FAKE_SKIP_STDIN:-0}" != 1 ]]; then cat > "${FAKE_PROMPT_FILE:?}"; fi
printf 'AC-01: PASS (fake Codex only)\n' > "$out"
exit "${FAKE_CODEX_EXIT:-0}"
FAKE
chmod +x "$tmp/codex"
export PATH="$tmp:$PATH" FAKE_INVOKED="$tmp/invoked.txt" FAKE_PROMPT_FILE="$tmp/prompt.txt"
if ! ps -eo pgid=,stat= >/dev/null 2>&1; then
  # Some restricted macOS sandboxes deny process listings. Preserve the timeout
  # contract test with a test-only group liveness probe for the fake Codex.
  export FAKE_PGID_FILE="$tmp/fake-pgid"
  cat > "$tmp/ps" <<'FAKE_PS'
#!/usr/bin/env bash
[[ -f "${FAKE_PGID_FILE:-}" ]] || exit 0
pgid="$(cat "$FAKE_PGID_FILE")"
if kill -0 -- "-$pgid" 2>/dev/null; then printf '%s R\n' "$pgid"; fi
FAKE_PS
  chmod +x "$tmp/ps"
fi

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
CODEX_REASONING_EFFORT=medium bash scripts/codex-delegate.sh --dry-run "$id" > "$tmp/dry-effort.txt"
grep -Fq 'medium' "$tmp/dry-effort.txt" || { echo 'FAIL: dry-run omitted reasoning effort' >&2; exit 1; }
if CODEX_REASONING_EFFORT=invalid bash scripts/codex-delegate.sh "$id" > /dev/null 2>&1; then
  echo 'FAIL: invalid reasoning effort accepted' >&2; exit 1
else [[ $? == 2 ]] || { echo 'FAIL: invalid reasoning effort exit code' >&2; exit 1; }; fi
[[ ! -e "$FAKE_INVOKED" ]] || { echo 'FAIL: invalid reasoning effort invoked Codex' >&2; exit 1; }
mkdir -p "$(dirname "$legacy_handoff")"
printf '## Approval status\nStatus: PENDING\n' > "$legacy_handoff"
bash scripts/codex-delegate.sh --dry-run "$id" > "$tmp/preferred.txt" 2> "$tmp/preferred.err"
grep -Fq ".workflow/handoffs/$id.md" "$tmp/preferred.txt" || { echo 'FAIL: new handoff was not preferred' >&2; exit 1; }
[[ ! -s "$tmp/preferred.err" ]] || { echo 'FAIL: warned while using new handoff' >&2; exit 1; }
rm -f "$legacy_handoff"
mv "$handoff" "$legacy_handoff"
bash scripts/codex-delegate.sh --dry-run "$id" > "$tmp/legacy.txt" 2> "$tmp/legacy.err"
grep -Fq ".claude/handoffs/$id.md" "$tmp/legacy.txt" || { echo 'FAIL: legacy handoff was not used' >&2; exit 1; }
grep -Fq 'deprecated' "$tmp/legacy.err" || { echo 'FAIL: legacy handoff warning missing' >&2; exit 1; }
[[ "$(grep -c '^WARNING:' "$tmp/legacy.err")" == 1 ]] || { echo 'FAIL: expected one legacy handoff warning' >&2; exit 1; }
sed -i.bak 's/^Status:.*/Status: PENDING/' "$legacy_handoff"; rm -f "$legacy_handoff.bak"
if bash scripts/codex-delegate.sh --dry-run "$id" > /dev/null 2>&1; then
  echo 'FAIL: unapproved legacy handoff accepted' >&2; exit 1
else [[ $? == 3 ]] || { echo 'FAIL: legacy approval exit code' >&2; exit 1; }; fi
cp "$legacy_handoff" "$handoff"
rm -f "$legacy_handoff"
mv "$handoff" "$tmp/legacy-target.md"
ln -s "$tmp/legacy-target.md" "$legacy_handoff"
if bash scripts/codex-delegate.sh --dry-run "$id" > /dev/null 2>&1; then
  echo 'FAIL: symlinked legacy handoff accepted' >&2; exit 1
else [[ $? == 2 ]] || { echo 'FAIL: legacy symlink exit code' >&2; exit 1; }; fi
rm -f "$legacy_handoff"
mv "$tmp/legacy-target.md" "$handoff"
sed -i.bak 's/^Status:.*/Status: APPROVED/' "$handoff"; rm -f "$handoff.bak"
mv "$handoff" "$tmp/new-target.md"
ln -s "$tmp/new-target.md" "$handoff"
if bash scripts/codex-delegate.sh --dry-run "$id" > /dev/null 2>&1; then
  echo 'FAIL: symlinked new handoff accepted' >&2; exit 1
else [[ $? == 2 ]] || { echo 'FAIL: new symlink exit code' >&2; exit 1; }; fi
rm -f "$handoff"
mv "$tmp/new-target.md" "$handoff"
if bash scripts/codex-delegate.sh '../escape' >/dev/null 2>&1; then
  echo 'FAIL: path traversal accepted' >&2; exit 1
fi
echo 'PASS: handoff precedence, legacy warning, approval, symlink and traversal dry-run checks'

# Repository must be clean (handoff and run logs are ignored).
printf 'dirty\n' > ".dirty-worktree-probe-$$"
if bash scripts/codex-delegate.sh "$id" > "$tmp/dirty.txt" 2>&1; then
  echo 'FAIL: accepted a dirty worktree' >&2; exit 1
else [[ $? == 6 ]] || { echo 'FAIL: dirty worktree error code' >&2; exit 1; }; fi
rm -f ".dirty-worktree-probe-$$"
grep -q "dirty-worktree-probe-$$" "$tmp/dirty.txt" || { echo 'FAIL: dirty-tree error does not list the dirty path' >&2; exit 1; }

bash scripts/codex-delegate.sh "$id" > "$tmp/success.txt"
grep -q 'BEGIN APPROVED HANDOFF' "$FAKE_PROMPT_FILE"
grep -q 'Start from the files listed in the handoff' "$FAKE_PROMPT_FILE" || { echo 'FAIL: prompt file-first guidance missing' >&2; exit 1; }
grep -q 'BEGIN CODEX RULES' "$FAKE_PROMPT_FILE" || { echo 'FAIL: Codex rules opening marker missing' >&2; exit 1; }
grep -q 'Codex must not redo planning' "$FAKE_PROMPT_FILE" || { echo 'FAIL: Codex rules missing from prompt' >&2; exit 1; }
grep -q 'Avoid storing credentials or user data.' "$FAKE_PROMPT_FILE" || { echo 'FAIL: Codex rules truncated in prompt' >&2; exit 1; }
grep -q 'END CODEX RULES' "$FAKE_PROMPT_FILE" || { echo 'FAIL: Codex rules closing marker missing' >&2; exit 1; }
grep -q 'Final exit code: 0' "$tmp/success.txt"
grep -q 'AC-01: PASS' "$handoffs"/"$id"-run.*/completion.md
grep -q 'Diff for review (one read)' "$tmp/success.txt" || { echo 'FAIL: summary does not point to diff.patch' >&2; exit 1; }
ls "$handoffs"/"$id"-run.*/diff.patch >/dev/null || { echo 'FAIL: diff.patch not written' >&2; exit 1; }
grep -qx 'default' "$handoffs"/"$id"-run.*/effort.txt || { echo 'FAIL: default effort record missing' >&2; exit 1; }

# Network is explicitly false by default (overrides ~/.codex/config.toml); CODEX_NETWORK=1 opts in.
FAKE_CONFIG_FILE="$tmp/config-default.txt" bash scripts/codex-delegate.sh "$id" > /dev/null
[[ "$(cat "$tmp/config-default.txt")" == 'sandbox_workspace_write.network_access=false' ]] || { echo 'FAIL: network not explicitly disabled by default' >&2; exit 1; }
CODEX_NETWORK=yes FAKE_CONFIG_FILE="$tmp/config-typo.txt" bash scripts/codex-delegate.sh "$id" > /dev/null
grep -qx 'sandbox_workspace_write.network_access=false' "$tmp/config-typo.txt" || { echo 'FAIL: only CODEX_NETWORK=1 may enable network' >&2; exit 1; }
CODEX_NETWORK=1 FAKE_CONFIG_FILE="$tmp/config-net.txt" bash scripts/codex-delegate.sh "$id" > /dev/null
grep -qx 'sandbox_workspace_write.network_access=true' "$tmp/config-net.txt" || { echo 'FAIL: CODEX_NETWORK=1 not passed' >&2; exit 1; }
CODEX_REASONING_EFFORT=medium FAKE_CONFIG_FILE="$tmp/config-effort.txt" bash scripts/codex-delegate.sh "$id" > /dev/null
grep -qx 'model_reasoning_effort="medium"' "$tmp/config-effort.txt" || { echo 'FAIL: reasoning effort not passed to Codex' >&2; exit 1; }
grep -qx 'medium' "$handoffs"/"$id"-run.*/effort.txt || { echo 'FAIL: effort.txt missing medium' >&2; exit 1; }

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

# Repeat timeout with TERM-resistant descendants: kill -0 may still see zombies.
# Exit must be 124, and a clean shutdown must not strand the delegation lock.
for repeat in 1 2 3 4; do
  if CODEX_TIMEOUT_SECONDS=1 FAKE_SLEEP=6 FAKE_STUBBORN_CHILD=1 bash scripts/codex-delegate.sh "$id" > "$tmp/stubborn-$repeat.txt" 2>&1; then
    echo "FAIL: stubborn descendant timeout accepted (run $repeat)" >&2; exit 1
  else
    [[ $? == 124 ]] || { echo "FAIL: stubborn descendant timeout wrong exit (run $repeat)" >&2; cat "$tmp/stubborn-$repeat.txt"; exit 1; }
  fi
  [[ ! -d "$handoffs/.codex-delegate.lock" ]] || { echo "FAIL: lock stranded after forced shutdown (run $repeat)" >&2; cat "$tmp/stubborn-$repeat.txt"; exit 1; }
done

# Quick checks use an isolated clean repository with a configured command.
quick="$(cd "$tmp" && pwd -P)/quick-repo"
mkdir -p "$quick/scripts/hooks" "$quick/docs/workflow" "$quick/.workflow/handoffs"
cp scripts/codex-delegate.sh "$quick/scripts/"
cp scripts/hooks/auto-verify.sh "$quick/scripts/hooks/"
cp docs/workflow/codex-rules.md "$quick/docs/workflow/"
cp "$handoff" "$quick/.workflow/handoffs/$id.md"
printf '.workflow/\n' > "$quick/.gitignore"
printf '# Fixture\n- Quick check command: bash scripts/check.sh\n- Protected paths: NONE\n' > "$quick/AGENTS.md"
printf 'old line\n' > "$quick/tracked.txt"
cat > "$quick/scripts/check.sh" <<'CHECK'
#!/usr/bin/env bash
printf 'x' >> "$QUICK_COUNT"
if [[ "${QUICK_FAIL:-0}" == 1 ]]; then
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22; do echo "failure-$i"; done
  exit 7
fi
CHECK
(cd "$quick" && git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -q -m fixture)
export QUICK_COUNT="$tmp/quick-count"
(cd "$quick" && FAKE_CHANGED_PATH=work.txt bash scripts/codex-delegate.sh "$id") > "$tmp/quick-pass.txt"
grep -q 'work.txt (new)' "$tmp/quick-pass.txt" || { echo 'FAIL: new-file summary missing' >&2; exit 1; }
grep -q 'AC-01: PASS' "$tmp/quick-pass.txt" || { echo 'FAIL: acceptance summary missing' >&2; exit 1; }
[[ "$(wc -c < "$QUICK_COUNT" | tr -d ' ')" == 1 ]] || { echo 'FAIL: quick check not run' >&2; exit 1; }
grep -q '^QUICK_CHECK_EXIT=0$' "$quick"/.workflow/handoffs/"$id"-run.*/status.txt || { echo 'FAIL: quick check pass status missing' >&2; exit 1; }
rm -f "$quick/work.txt"
if (cd "$quick" && QUICK_FAIL=1 FAKE_CHANGED_PATH=work.txt bash scripts/codex-delegate.sh "$id") > "$tmp/quick-fail.txt" 2>&1; then
  echo 'FAIL: failed quick check accepted' >&2; exit 1
else [[ $? == 7 ]] || { echo 'FAIL: quick check failure exit code' >&2; exit 1; }; fi
grep -q 'failure-22' "$tmp/quick-fail.txt" || { echo 'FAIL: failure tail missing' >&2; exit 1; }
grep -q 'failure-1$' "$tmp/quick-fail.txt" && { echo 'FAIL: summary exceeded 20 failure lines' >&2; exit 1; }
grep -q '^QUICK_CHECK_EXIT=7$' "$quick"/.workflow/handoffs/"$id"-run.*/status.txt || { echo 'FAIL: quick check failure status missing' >&2; exit 1; }
rm -f "$quick/work.txt"
(cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_CHANGED_PATH=work.txt bash scripts/codex-delegate.sh "$id") > "$tmp/quick-skip.txt"
grep -q 'QUICK_CHECK_EXIT=SKIPPED' "$quick"/.workflow/handoffs/"$id"-run.*/status.txt || { echo 'FAIL: quick check skip missing' >&2; exit 1; }
[[ "$(wc -c < "$QUICK_COUNT" | tr -d ' ')" == 2 ]] || { echo 'FAIL: skipped quick check ran' >&2; exit 1; }
rm -f "$quick/work.txt"
(cd "$quick" && FAKE_CHANGED_PATH=tracked.txt bash scripts/codex-delegate.sh "$id") > "$tmp/quick-tracked.txt"
grep -q 'tracked.txt (+1/-1)' "$tmp/quick-tracked.txt" || { echo 'FAIL: tracked numstat summary missing' >&2; exit 1; }
printf 'old line\n' > "$quick/tracked.txt"
if (cd "$quick" && QUICK_FAIL=1 FAKE_CODEX_EXIT=9 FAKE_CHANGED_PATH=work.txt bash scripts/codex-delegate.sh "$id") > "$tmp/quick-codex-fail.txt" 2>&1; then
  echo 'FAIL: Codex failure accepted with quick-check failure' >&2; exit 1
else [[ $? == 9 ]] || { echo 'FAIL: Codex exit did not take precedence over quick check' >&2; exit 1; }; fi
rm -f "$quick/work.txt"
if (cd "$quick" && QUICK_FAIL=1 FAKE_PROTECTED_PATH="$quick/CLAUDE.md" bash scripts/codex-delegate.sh "$id") > "$tmp/quick-protected.txt" 2>&1; then
  echo 'FAIL: protected change accepted with quick-check failure' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: protected exit did not take precedence over quick check' >&2; exit 1; }; fi
rm -f "$quick/CLAUDE.md"

# A task that edits the wrapper itself while it runs must not corrupt the post-run checks
# (Bash reads scripts incrementally). Isolated copy: the real wrapper is never modified.
self="$(cd "$tmp" && pwd -P)/self-repo"  # physical path: macOS /var is a symlink to /private/var
mkdir -p "$self/scripts" "$self/.workflow/handoffs"
cp scripts/codex-delegate.sh "$self/scripts/"
printf '# Fixture\n- Protected paths: NONE\n' > "$self/AGENTS.md"
printf '.workflow/\n' > "$self/.gitignore"
cp "$handoff" "$self/.workflow/handoffs/$id.md"
(cd "$self" && git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -q -m fixture)
if (cd "$self" && FAKE_SELF_EDIT=1 bash scripts/codex-delegate.sh "$id") > "$tmp/self-edit.txt" 2>&1; then
  echo 'FAIL: wrapper self-edit reported success' >&2; cat "$tmp/self-edit.txt" >&2; exit 1
else
  [[ $? == 4 ]] || { echo 'FAIL: wrapper self-edit exit code not 4' >&2; cat "$tmp/self-edit.txt" >&2; exit 1; }
fi
grep -q '^FINAL_EXIT_CODE=4$' "$self"/.workflow/handoffs/"$id"-run.*/status.txt || { echo 'FAIL: status not written after wrapper self-edit' >&2; exit 1; }
grep -qx 'scripts/codex-delegate.sh' "$self"/.workflow/handoffs/"$id"-run.*/protected-violations.txt || { echo 'FAIL: wrapper self-edit not reported as protected' >&2; exit 1; }

echo 'PASS: fake-Codex approval, legacy fallback, dry-run, traversal, clean tree, early exit, protected paths, wrapper self-edit, locking, timeout, network opt-in and exit-code tests'
