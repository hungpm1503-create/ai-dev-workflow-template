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
mkdir -p "$handoffs"
cleanup() {
  rm -f "$handoff" "$legacy_handoff"
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
    -m) printf '%s\n' "$2" >> "${FAKE_MODEL_FILE:-/dev/null}"; shift 2;;
    -) stdin_flag='-'; shift;;
    *) exit 42;;
  esac
done
[[ "$sandbox" == workspace-write && "$stdin_flag" == '-' && -n "$out" ]] || exit 43
if [[ -n "${FAKE_PROTECTED_PATH:-}" ]]; then
  printf 'unauthorized\n' > "$FAKE_PROTECTED_PATH"
fi
if [[ "${FAKE_AGENTS_CANARY:-0}" == 1 ]]; then
  printf '%s\n' '# Fixture' '- Quick check command: printf x > "$CANARY"' '- Protected paths: NONE' > AGENTS.md
fi
if [[ "${FAKE_HOOK_CANARY:-0}" == 1 ]]; then
  printf '%s\n' '#!/usr/bin/env bash' 'printf x > "$CANARY"' > scripts/hooks/auto-verify.sh
fi
if [[ "${FAKE_MEMORY_CANARY:-0}" == 1 ]]; then
  printf '%s\n' '#!/usr/bin/env bash' 'printf x > "$CANARY"' > scripts/workflow-memory.sh
fi
if [[ -n "${FAKE_CHANGED_PATH:-}" ]]; then
  printf 'new line\n' > "$FAKE_CHANGED_PATH"
  if [[ -n "${FAKE_TOUCH_TIME:-}" ]]; then touch -t "$FAKE_TOUCH_TIME" "$FAKE_CHANGED_PATH"; fi
fi
if [[ -n "${FAKE_UNREADABLE_PATH:-}" ]]; then
  printf 'unreadable\n' > "$FAKE_UNREADABLE_PATH"
  chmod 000 "$FAKE_UNREADABLE_PATH"
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
# The pre-approved runner must not execute HIGH-risk work.
gate_id="TASK-GATE-${id##*-}"
cat > "$handoffs/$gate_id.md" <<'GATE'
## Task ID
TASK-GATE
## Route
- Complexity: MEDIUM
- Governance risk: HIGH
- Traceability: LOW
## Approval status
Status: APPROVED
GATE
if bash scripts/codex-standard.sh "$gate_id" > "$tmp/gate.txt" 2>&1; then
  echo 'FAIL: auto-runner accepted HIGH-risk task' >&2; exit 1
else [[ $? == 3 ]] || { echo 'FAIL: wrong high-risk refusal code' >&2; exit 1; }; fi
rm -f "$handoffs/$gate_id.md"

# Skill-provided model and effort are validated and passed through unchanged.
CODEX_MODEL=gpt-6-luna CODEX_REASONING_EFFORT=medium bash scripts/codex-delegate.sh --dry-run "$id" > "$tmp/model-dry.txt"
grep -Fq 'Model: gpt-6-luna' "$tmp/model-dry.txt" || { echo 'FAIL: dry-run does not report selected model' >&2; exit 1; }
grep -Fq 'Reasoning effort: medium' "$tmp/model-dry.txt" || { echo 'FAIL: dry-run does not report selected effort' >&2; exit 1; }
if CODEX_MODEL='bad model' bash scripts/codex-delegate.sh --dry-run "$id" >/dev/null 2>&1; then
 echo 'FAIL: invalid model identifier accepted' >&2; exit 1
else [[ $? == 2 ]] || exit 1; fi
echo 'PASS: skill-provided model and effort validated'
 
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
grep -qx 'CLI default' "$handoffs"/"$id"-run.*/model.txt || { echo 'FAIL: default model record missing' >&2; exit 1; }
CODEX_MODEL=gpt-6-luna CODEX_REASONING_EFFORT=medium FAKE_MODEL_FILE="$tmp/forwarded-model.txt" bash scripts/codex-delegate.sh "$id" > /dev/null
grep -qx 'gpt-6-luna' "$tmp/forwarded-model.txt" || { echo 'FAIL: skill-selected model not forwarded via -m' >&2; exit 1; }
grep -qx 'gpt-6-luna' "$handoffs"/"$id"-run.*/model.txt || { echo 'FAIL: model not recorded' >&2; exit 1; }

# Network is explicitly false by default (overrides ~/.codex/config.toml); CODEX_NETWORK=1 opts in.
FAKE_CONFIG_FILE="$tmp/config-default.txt" bash scripts/codex-delegate.sh "$id" > /dev/null
grep -qx 'sandbox_workspace_write.network_access=false' "$tmp/config-default.txt" || { echo 'FAIL: network not explicitly disabled by default' >&2; exit 1; }
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
timeout_run="$(ls -dt "$handoffs/$id"-run.* | head -n 1)"
[[ ! -e "$timeout_run/tree-after.txt" ]] || { echo 'FAIL: timed-out run recorded an unfinished tree' >&2; exit 1; }

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
cp scripts/codex-standard.sh "$quick/scripts/"
cp scripts/hooks/auto-verify.sh "$quick/scripts/hooks/"
cp scripts/workflow-memory.sh "$quick/scripts/"
cp docs/workflow/codex-rules.md "$quick/docs/workflow/"
cp "$handoff" "$quick/.workflow/handoffs/$id.md"
printf '.workflow/\n' > "$quick/.gitignore"
printf '# Fixture\n- Quick check command: bash scripts/check.sh\n- Protected paths: NONE\n' > "$quick/AGENTS.md"
printf 'old line\n' > "$quick/tracked.txt"
touch -t 202001010000 "$quick/tracked.txt"
cat > "$quick/scripts/check.sh" <<'CHECK'
#!/usr/bin/env bash
printf 'x' >> "$QUICK_COUNT"
if [[ "${QUICK_FAIL:-0}" == 1 ]]; then
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22; do echo "failure-$i"; done
  exit 7
fi
CHECK
(cd "$quick" && git init -q && git config core.trustctime false && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -q -m fixture)
export QUICK_COUNT="$tmp/quick-count"
# Real LOW/LOW wrapper executed in the isolated fake-Codex fixture.
standard_id="TASK-STANDARD-${id##*-}"
cat > "$quick/.workflow/handoffs/$standard_id.md" <<'STANDARD'
## Task ID
TASK-STANDARD
## Route
- Complexity: MEDIUM
- Governance risk: LOW
- Traceability: LOW
- Codex model: gpt-6-luna
- Codex reasoning effort: high
## Approval status
Status: APPROVED
## Objective
Small test fixture
STANDARD
if (cd "$quick" && CODEX_NETWORK=1 CODEX_QUICK_CHECK=0 AUTO_VERIFY_DISABLE=1 CODEX_MODEL=invalid-override CODEX_REASONING_EFFORT=xhigh FAKE_CONFIG_FILE="$tmp/standard-network.txt" FAKE_MODEL_FILE="$tmp/standard-model.txt" bash scripts/codex-standard.sh "$standard_id") > "$tmp/standard-run.txt" 2>&1; then
  grep -Fq 'Final exit code: 0' "$tmp/standard-run.txt" || exit 1
else
  echo 'FAIL: approved LOW/LOW auto-run failed' >&2
  cat "$tmp/standard-run.txt" >&2; exit 1
fi
grep -qx 'sandbox_workspace_write.network_access=false' "$tmp/standard-network.txt" || { echo 'FAIL: auto-run enabled network' >&2; exit 1; }
[[ -s "$QUICK_COUNT" ]] || { echo 'FAIL: Quick check skipped during auto-run' >&2; exit 1; }
grep -qx 'gpt-6-luna' "$tmp/standard-model.txt" || { echo 'FAIL: auto-runner did not forward the skill-selected model' >&2; exit 1; }
grep -qx 'model_reasoning_effort="high"' "$tmp/standard-network.txt" || { echo 'FAIL: auto-runner did not forward effort' >&2; exit 1; }
standard_run="$(ls -dt "$quick/.workflow/handoffs/$standard_id"-run.* | head -n 1)"
grep -qx 'QUICK_CHECK_EXIT=0' "$standard_run/status.txt" || { echo 'FAIL: auto-runner did not suppress AUTO_VERIFY_DISABLE' >&2; exit 1; }
cp "$quick/.workflow/handoffs/$standard_id.md" "$tmp/standard-good.md"
sed '/^- Codex model:/d' "$tmp/standard-good.md" > "$quick/.workflow/handoffs/$standard_id.md"
if (cd "$quick" && bash scripts/codex-standard.sh "$standard_id") > "$tmp/standard-missing-model.txt" 2>&1; then
 echo 'FAIL: auto-runner accepted handoff without model' >&2; exit 1
else [[ $? == 3 ]] || { echo 'FAIL: missing model exit status' >&2; exit 1; }; fi
sed 's/^- Codex reasoning effort: high/- Codex reasoning effort: unsupported/' "$tmp/standard-good.md" > "$quick/.workflow/handoffs/$standard_id.md"
if (cd "$quick" && bash scripts/codex-standard.sh "$standard_id") > "$tmp/standard-bad-effort.txt" 2>&1; then
 echo 'FAIL: auto-runner accepted invalid reasoning effort' >&2; exit 1
else [[ $? == 3 ]] || { echo 'FAIL: invalid effort exit status' >&2; exit 1; }; fi
cp "$tmp/standard-good.md" "$quick/.workflow/handoffs/$standard_id.md"

: > "$QUICK_COUNT"

# Missing Quick check must fail closed even with an approved LOW/LOW handoff.
sed 's/Quick check command: bash scripts\/check.sh/Quick check command: [NOT CONFIGURED]/' "$quick/AGENTS.md" > "$tmp/missing-check-AGENTS"
cp "$quick/AGENTS.md" "$tmp/valid-check-AGENTS"
cp "$tmp/missing-check-AGENTS" "$quick/AGENTS.md"
(cd "$quick" && git add AGENTS.md && git -c user.name=t -c user.email=t"@"example.invalid commit -q -m unset-quick)
if (cd "$quick" && bash scripts/codex-standard.sh "$standard_id") > "$tmp/missing-quick.txt" 2>&1; then
  echo 'FAIL: auto-run accepted unconfigured Quick check' >&2; exit 1
else [[ $? == 3 ]] || { echo 'FAIL: wrong missing-quick exit' >&2; exit 1; }; fi
cp "$tmp/valid-check-AGENTS" "$quick/AGENTS.md"
(cd "$quick" && git add AGENTS.md && git -c user.name=t -c user.email=t"@"example.invalid commit -q -m restore-quick)

# A modified delegated script must never be launched by the auto-allowed runner.
printf '\n# unauthorized edit\n' >> "$quick/scripts/codex-delegate.sh"
if (cd "$quick" && bash scripts/codex-standard.sh "$standard_id") > "$tmp/tampered-delegate.txt" 2>&1; then
  echo 'FAIL: auto-run executed altered delegate' >&2; exit 1
else [[ $? == 3 ]] || { echo 'FAIL: wrong integrity error code' >&2; exit 1; }; fi
git -C "$quick" checkout -- scripts/codex-delegate.sh

stale_id="TASK-STALE-STAT-$$"
cp "$handoff" "$quick/.workflow/handoffs/$stale_id.md"
cp "$quick/.git/index" "$tmp/stale-index-before"
(cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_CHANGED_PATH=tracked.txt FAKE_TOUCH_TIME=202001010000 bash scripts/codex-delegate.sh "$stale_id") > "$tmp/stale-parent.txt"
stale_run="$(ls -dt "$quick/.workflow/handoffs/$stale_id"-run.* | head -n 1)"
[[ "$(cd "$quick" && git show "$(cat "$stale_run/tree-after.txt"):tracked.txt")" == 'new line' ]] || { echo 'FAIL: stale-stat tree retained old tracked content' >&2; exit 1; }
grep -q '^+new line$' "$stale_run/diff.patch" || { echo 'FAIL: stale-stat snapshot omitted new tracked content' >&2; exit 1; }
cmp -s "$tmp/stale-index-before" "$quick/.git/index" || { echo 'FAIL: stale-stat snapshot changed real index' >&2; exit 1; }
(cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --dry-run --follow-up "$stale_id" "$id") > "$tmp/stale-follow.txt"
grep -q "Follow-up of: $stale_id" "$tmp/stale-follow.txt" || { echo 'FAIL: stale-stat follow-up not accepted' >&2; exit 1; }
printf 'old line\n' > "$quick/tracked.txt"
touch -t 202001010000 "$quick/tracked.txt"
(cd "$quick" && FAKE_CHANGED_PATH=new-file.txt bash scripts/codex-delegate.sh "$id") > "$tmp/quick-pass.txt"
quick_run="$(ls -dt "$quick/.workflow/handoffs/$id"-run.* | head -n 1)"
[[ -f "$quick/.workflow/work-memory/$id/RUN-$(basename "$quick_run").md" ]] || { echo 'FAIL: unchanged workflow-memory.sh did not record checkpoint' >&2; exit 1; }
grep -q 'Checkpoint recorded:' "$quick_run/codex.log" || { echo 'FAIL: normal run log omitted checkpoint' >&2; exit 1; }
grep -Fq 'diff --git a/new-file.txt b/new-file.txt' "$quick_run/diff.patch" || { echo 'FAIL: new-file patch omitted new-file.txt' >&2; exit 1; }
grep -q '^+new line$' "$quick_run/diff.patch" || { echo 'FAIL: new-file patch omitted known content' >&2; exit 1; }
grep -qx 'DIFF_COMPLETE=1' "$quick_run/status.txt" || { echo 'FAIL: complete patch status missing' >&2; exit 1; }
grep -q 'new-file.txt (new)' "$tmp/quick-pass.txt" || { echo 'FAIL: new-file summary missing' >&2; exit 1; }
grep -q 'AC-01: PASS' "$tmp/quick-pass.txt" || { echo 'FAIL: acceptance summary missing' >&2; exit 1; }
[[ "$(wc -c < "$QUICK_COUNT" | tr -d ' ')" == 1 ]] || { echo 'FAIL: quick check not run' >&2; exit 1; }
grep -q '^QUICK_CHECK_EXIT=0$' "$quick"/.workflow/handoffs/"$id"-run.*/status.txt || { echo 'FAIL: quick check pass status missing' >&2; exit 1; }
rm -f "$quick/new-file.txt"
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
# A disabled verification hook must never be recorded as PASS merely because it
# returned exit code 0.
(cd "$quick" && AUTO_VERIFY_DISABLE=1 FAKE_CHANGED_PATH=disabled-test.txt bash scripts/codex-delegate.sh "$id") > "$tmp/auto-disabled.txt"
disabled_run="$(ls -dt "$quick/.workflow/handoffs/$id"-run.* | head -n 1)"
grep -qx 'QUICK_CHECK_EXIT=SKIPPED_UNVERIFIED' "$disabled_run/status.txt" || { echo 'FAIL: disabled auto-verify was misreported as PASS' >&2; exit 1; }
grep -Fq 'Quick check: SKIPPED_UNVERIFIED' "$tmp/auto-disabled.txt" || { echo 'FAIL: skipped verification was hidden' >&2; exit 1; }
rm -f "$quick/disabled-test.txt"

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

# A changed command source or hook must not execute on the host after protected-path review.
cp "$quick/AGENTS.md" "$tmp/quick-agents-before"
if (cd "$quick" && CANARY="$tmp/agents-canary" FAKE_AGENTS_CANARY=1 bash scripts/codex-delegate.sh "$id") > "$tmp/agents-protected.txt" 2>&1; then
  echo 'FAIL: changed AGENTS.md accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: changed AGENTS.md exit code' >&2; exit 1; }; fi
agents_run="$(ls -dt "$quick/.workflow/handoffs/$id"-run.* | head -n 1)"
[[ ! -e "$tmp/agents-canary" ]] || { echo 'FAIL: changed AGENTS.md command ran' >&2; exit 1; }
grep -qx 'QUICK_CHECK_EXIT=SKIPPED_PROTECTED' "$agents_run/status.txt" || { echo 'FAIL: AGENTS.md quick check not marked protected' >&2; exit 1; }
grep -qx 'Quick check skipped: protected paths changed; review them before running any check.' "$agents_run/quick-check.log" || { echo 'FAIL: AGENTS.md skip reason missing' >&2; exit 1; }
grep -q 'Quick check: SKIPPED_PROTECTED' "$tmp/agents-protected.txt" || { echo 'FAIL: AGENTS.md summary missing skip status' >&2; exit 1; }
cp "$tmp/quick-agents-before" "$quick/AGENTS.md"

cp "$quick/scripts/hooks/auto-verify.sh" "$tmp/quick-hook-before"
if (cd "$quick" && CANARY="$tmp/hook-canary" FAKE_HOOK_CANARY=1 bash scripts/codex-delegate.sh "$id") > "$tmp/hook-protected.txt" 2>&1; then
  echo 'FAIL: changed hook accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: changed hook exit code' >&2; exit 1; }; fi
hook_run="$(ls -dt "$quick/.workflow/handoffs/$id"-run.* | head -n 1)"
[[ ! -e "$tmp/hook-canary" ]] || { echo 'FAIL: changed hook ran' >&2; exit 1; }
grep -qx 'QUICK_CHECK_EXIT=SKIPPED_PROTECTED' "$hook_run/status.txt" || { echo 'FAIL: hook quick check not marked protected' >&2; exit 1; }
cp "$tmp/quick-hook-before" "$quick/scripts/hooks/auto-verify.sh"

cp "$quick/scripts/workflow-memory.sh" "$tmp/quick-memory-before"
if (cd "$quick" && CANARY="$tmp/memory-canary" FAKE_MEMORY_CANARY=1 bash scripts/codex-delegate.sh "$id") > "$tmp/memory-protected.txt" 2>&1; then
  echo 'FAIL: changed workflow-memory.sh accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: changed workflow-memory.sh exit code' >&2; exit 1; }; fi
memory_run="$(ls -dt "$quick/.workflow/handoffs/$id"-run.* | head -n 1)"
grep -qx 'scripts/workflow-memory.sh' "$memory_run/protected-violations.txt" || { echo 'FAIL: workflow-memory.sh not reported as protected' >&2; exit 1; }
[[ ! -e "$tmp/memory-canary" ]] || { echo 'FAIL: changed workflow-memory.sh ran on host' >&2; exit 1; }
grep -qx 'Working-memory checkpoint skipped: protected paths changed.' "$memory_run/codex.log" || { echo 'FAIL: protected checkpoint skip missing from run log' >&2; exit 1; }
[[ ! -e "$quick/.workflow/work-memory/$id/RUN-$(basename "$memory_run").md" ]] || { echo 'FAIL: protected run recorded checkpoint' >&2; exit 1; }
cp "$tmp/quick-memory-before" "$quick/scripts/workflow-memory.sh"

# A changed prompt rule must be reported before any quick check runs.
cp "$quick/docs/workflow/codex-rules.md" "$tmp/quick-rules-before"
if (cd "$quick" && FAKE_PROTECTED_PATH="$quick/docs/workflow/codex-rules.md" bash scripts/codex-delegate.sh "$id") > "$tmp/rules-protected.txt" 2>&1; then
  echo 'FAIL: changed Codex rules accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: changed Codex rules exit code' >&2; exit 1; }; fi
rules_run="$(ls -dt "$quick/.workflow/handoffs/$id"-run.* | head -n 1)"
grep -qx 'docs/workflow/codex-rules.md' "$rules_run/protected-violations.txt" || { echo 'FAIL: Codex rules not reported as protected' >&2; exit 1; }
grep -qx 'QUICK_CHECK_EXIT=SKIPPED_PROTECTED' "$rules_run/status.txt" || { echo 'FAIL: quick check ran after Codex rules changed' >&2; exit 1; }
cp "$tmp/quick-rules-before" "$quick/docs/workflow/codex-rules.md"

# A failed post-run tree snapshot must not bypass protected-path review or status.
snapshot_protected_id="TASK-SNAPSHOT-PROTECTED-$$"
snapshot_plain_id="TASK-SNAPSHOT-PLAIN-$$"
cp "$handoff" "$quick/.workflow/handoffs/$snapshot_protected_id.md"
cp "$handoff" "$quick/.workflow/handoffs/$snapshot_plain_id.md"
if (cd "$quick" && FAKE_UNREADABLE_PATH=unreadable.txt FAKE_PROTECTED_PATH="$quick/CLAUDE.md" bash scripts/codex-delegate.sh "$snapshot_protected_id") > "$tmp/snapshot-protected.txt" 2>&1; then
  echo 'FAIL: protected change accepted after snapshot failure' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: snapshot failure bypassed protected-path exit 4' >&2; exit 1; }; fi
snapshot_protected_run="$(ls -dt "$quick/.workflow/handoffs/$snapshot_protected_id"-run.* | head -n 1)"
chmod 600 "$quick/unreadable.txt"
[[ -f "$snapshot_protected_run/status.txt" ]] || { echo 'FAIL: snapshot failure omitted status' >&2; exit 1; }
grep -qx 'CLAUDE.md' "$snapshot_protected_run/protected-violations.txt" || { echo 'FAIL: snapshot failure bypassed protected-path report' >&2; exit 1; }
[[ ! -e "$snapshot_protected_run/tree-after.txt" ]] || { echo 'FAIL: failed snapshot left tree-after.txt' >&2; exit 1; }
grep -qx 'TREE_AFTER=UNAVAILABLE' "$snapshot_protected_run/status.txt" || { echo 'FAIL: protected snapshot failure status missing' >&2; exit 1; }
grep -qx 'QUICK_CHECK_EXIT=SKIPPED_PROTECTED' "$snapshot_protected_run/status.txt" || { echo 'FAIL: quick check skipped after protected snapshot failure' >&2; exit 1; }
grep -q 'Final exit code: 4' "$tmp/snapshot-protected.txt" || { echo 'FAIL: protected snapshot failure omitted summary' >&2; exit 1; }
rm -f "$quick/CLAUDE.md" "$quick/unreadable.txt"

if (cd "$quick" && FAKE_UNREADABLE_PATH=unreadable.txt bash scripts/codex-delegate.sh "$snapshot_plain_id") > "$tmp/snapshot-plain.txt" 2>&1; then
  echo 'FAIL: snapshot failure returned success' >&2; exit 1
else [[ $? == 1 ]] || { echo 'FAIL: snapshot failure did not return exit 1' >&2; exit 1; }; fi
snapshot_plain_run="$(ls -dt "$quick/.workflow/handoffs/$snapshot_plain_id"-run.* | head -n 1)"
chmod 600 "$quick/unreadable.txt"
grep -q '^WARNING:.*snapshot' "$tmp/snapshot-plain.txt" || { echo 'FAIL: snapshot warning missing' >&2; exit 1; }
grep -qx 'TREE_AFTER=UNAVAILABLE' "$snapshot_plain_run/status.txt" || { echo 'FAIL: snapshot availability status missing' >&2; exit 1; }
grep -qx 'DIFF_COMPLETE=0' "$snapshot_plain_run/status.txt" || { echo 'FAIL: incomplete patch status missing' >&2; exit 1; }
[[ "$(head -n 1 "$snapshot_plain_run/diff.patch")" == '# INCOMPLETE: untracked files are not included; read them from changed-paths.txt' ]] || { echo 'FAIL: incomplete patch marker missing' >&2; exit 1; }
grep -q 'Diff for review (one read):.*INCOMPLETE' "$tmp/snapshot-plain.txt" || { echo 'FAIL: incomplete patch summary missing' >&2; exit 1; }
grep -qx 'FINAL_EXIT_CODE=1' "$snapshot_plain_run/status.txt" || { echo 'FAIL: snapshot failure final status missing' >&2; exit 1; }
grep -qx 'QUICK_CHECK_EXIT=0' "$snapshot_plain_run/status.txt" || { echo 'FAIL: quick check skipped after snapshot failure' >&2; exit 1; }
[[ ! -e "$snapshot_plain_run/tree-after.txt" ]] || { echo 'FAIL: failed snapshot left tree-after.txt' >&2; exit 1; }
grep -q 'Final exit code: 1' "$tmp/snapshot-plain.txt" || { echo 'FAIL: snapshot failure omitted summary' >&2; exit 1; }
rm -f "$quick/unreadable.txt"
if (cd "$quick" && bash scripts/codex-delegate.sh --follow-up "$snapshot_plain_id" "$snapshot_protected_id") > "$tmp/snapshot-follow.txt" 2>&1; then
  echo 'FAIL: follow-up accepted a parent with no snapshot' >&2; exit 1
else [[ $? == 2 ]] || { echo 'FAIL: follow-up without parent snapshot exit code' >&2; exit 1; }; fi
echo 'PASS: failed tree snapshot preserves protected review, quick check, status, warning and nonzero exit'

# Follow-ups accept only the exact worktree left by the newest parent run.
parent_id="TASK-FOLLOW-PARENT-$$"
fix_id="TASK-FOLLOW-FIX-$$"
cp "$handoff" "$quick/.workflow/handoffs/$parent_id.md"
cp "$handoff" "$quick/.workflow/handoffs/$fix_id.md"
cp "$quick/.git/index" "$tmp/index-before"
(cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_CHANGED_PATH=tracked.txt bash scripts/codex-delegate.sh "$parent_id") > "$tmp/follow-parent.txt"
parent_run="$(ls -dt "$quick/.workflow/handoffs/$parent_id"-run.* | head -n 1)"
[[ -s "$parent_run/tree-after.txt" ]] || { echo 'FAIL: parent tree snapshot missing' >&2; exit 1; }
cmp -s "$tmp/index-before" "$quick/.git/index" || { echo 'FAIL: real Git index changed' >&2; exit 1; }
mkdir "$quick/.workflow/handoffs/$parent_id-run.incomplete"
printf 'HEAD_BEFORE=ignored\n' > "$quick/.workflow/handoffs/$parent_id-run.incomplete/status.txt"

invocations_before="$(wc -l < "$FAKE_INVOKED" | tr -d ' ')"
printf 'intruder\n' > "$quick/tracked.txt"
if (cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --dry-run --follow-up "$parent_id" "$fix_id") > "$tmp/follow-dry-mismatch.txt" 2>&1; then
  echo 'FAIL: dry-run accepted an intervening tracked edit' >&2; exit 1
else [[ $? == 6 ]] || { echo 'FAIL: dry-run mismatch exit code' >&2; exit 1; }; fi
if (cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --follow-up "$parent_id" "$fix_id") > "$tmp/follow-tracked.txt" 2>&1; then
  echo 'FAIL: follow-up accepted an intervening tracked edit' >&2; exit 1
else [[ $? == 6 ]] || { echo 'FAIL: tracked mismatch exit code' >&2; exit 1; }; fi
grep -q 'tracked.txt' "$tmp/follow-tracked.txt" || { echo 'FAIL: tracked mismatch path omitted' >&2; exit 1; }
grep -Fq "tree: expected $(cat "$parent_run/tree-after.txt"), found " "$tmp/follow-tracked.txt" || { echo 'FAIL: mismatch omitted parent tree SHA' >&2; exit 1; }
grep -Eq 'tree: expected [0-9a-f]+, found [0-9a-f]+' "$tmp/follow-tracked.txt" || { echo 'FAIL: mismatch omitted current tree SHA' >&2; exit 1; }
grep -Eq 'HEAD: expected [0-9a-f]+, found [0-9a-f]+' "$tmp/follow-tracked.txt" || { echo 'FAIL: mismatch omitted HEAD SHAs' >&2; exit 1; }
grep -Eq 'tracked.txt[[:space:]]+\|' "$tmp/follow-tracked.txt" || { echo 'FAIL: mismatch omitted diff stat' >&2; exit 1; }
printf 'new line\n' > "$quick/tracked.txt"
printf 'intruder\n' > "$quick/intruder.txt"
if (cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --follow-up "$parent_id" "$fix_id") > "$tmp/follow-untracked.txt" 2>&1; then
  echo 'FAIL: follow-up accepted an intervening untracked file' >&2; exit 1
else [[ $? == 6 ]] || { echo 'FAIL: untracked mismatch exit code' >&2; exit 1; }; fi
grep -q 'intruder.txt' "$tmp/follow-untracked.txt" || { echo 'FAIL: untracked mismatch path omitted' >&2; exit 1; }
rm -f "$quick/intruder.txt"
(cd "$quick" && git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m intervening)
if (cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --follow-up "$parent_id" "$fix_id") > "$tmp/follow-head.txt" 2>&1; then
  echo 'FAIL: follow-up accepted a HEAD change' >&2; exit 1
else [[ $? == 6 ]] || { echo 'FAIL: HEAD mismatch exit code' >&2; exit 1; }; fi
(cd "$quick" && git reset -q --soft HEAD^)
[[ "$(wc -l < "$FAKE_INVOKED" | tr -d ' ')" == "$invocations_before" ]] || { echo 'FAIL: mismatch invoked Codex' >&2; exit 1; }
grep -q '^RESULT=BLOCKED_FOLLOW_UP_MISMATCH$' "$quick"/.workflow/handoffs/"$fix_id"-run.*/status.txt || { echo 'FAIL: mismatch status missing' >&2; exit 1; }

if (cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --follow-up TASK-UNKNOWN "$fix_id") > "$tmp/follow-unknown.txt" 2>&1; then
  echo 'FAIL: unknown follow-up parent accepted' >&2; exit 1
else [[ $? == 2 ]] || { echo 'FAIL: unknown parent exit code' >&2; exit 1; }; fi
if (cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --follow-up ../escape "$fix_id") > /dev/null 2>&1; then
  echo 'FAIL: invalid follow-up parent accepted' >&2; exit 1
else [[ $? == 2 ]] || { echo 'FAIL: invalid parent exit code' >&2; exit 1; }; fi
(cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --dry-run --follow-up "$parent_id" "$fix_id") > "$tmp/follow-dry.txt"
grep -q "Follow-up of: $parent_id" "$tmp/follow-dry.txt" || { echo 'FAIL: dry-run follow-up not reported' >&2; exit 1; }
(cd "$quick" && CODEX_QUICK_CHECK=0 bash scripts/codex-delegate.sh --follow-up "$parent_id" --dry-run "$fix_id") > "$tmp/follow-dry-reverse.txt"
grep -q "Follow-up of: $parent_id" "$tmp/follow-dry-reverse.txt" || { echo 'FAIL: reverse flag order not accepted' >&2; exit 1; }
if (cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_CHANGED_PATH=work.txt FAKE_UNREADABLE_PATH=unreadable.txt bash scripts/codex-delegate.sh --follow-up "$parent_id" "$fix_id") > "$tmp/follow-snapshot-fail.txt" 2>&1; then
  echo 'FAIL: follow-up snapshot failure accepted' >&2; exit 1
else [[ $? == 1 ]] || { echo 'FAIL: follow-up snapshot failure exit code' >&2; exit 1; }; fi
follow_snapshot_run="$(ls -dt "$quick/.workflow/handoffs/$fix_id"-run.* | head -n 1)"
chmod 600 "$quick/unreadable.txt"
grep -qx 'TREE_AFTER=UNAVAILABLE' "$follow_snapshot_run/status.txt" || { echo 'FAIL: follow-up snapshot failure status missing' >&2; exit 1; }
grep -q 'tracked.txt' "$follow_snapshot_run/diff.patch" || { echo 'FAIL: follow-up snapshot failure omitted cumulative diff' >&2; exit 1; }
grep -q 'tracked.txt' "$tmp/follow-snapshot-fail.txt" || { echo 'FAIL: follow-up snapshot failure omitted cumulative summary' >&2; exit 1; }
[[ ! -e "$follow_snapshot_run/delta-paths.txt" ]] || { echo 'FAIL: follow-up snapshot failure wrote delta paths' >&2; exit 1; }
rm -f "$quick/work.txt" "$quick/unreadable.txt"
(cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_CHANGED_PATH=work.txt bash scripts/codex-delegate.sh --follow-up "$parent_id" "$fix_id") > "$tmp/follow-pass.txt"
fix_run="$(ls -dt "$quick/.workflow/handoffs/$fix_id"-run.* | head -n 1)"
grep -q 'work.txt' "$fix_run/diff.patch" || { echo 'FAIL: follow-up diff omitted fix' >&2; exit 1; }
! grep -q 'tracked.txt' "$fix_run/diff.patch" || { echo 'FAIL: follow-up diff includes earlier change' >&2; exit 1; }
grep -qx 'work.txt' "$fix_run/delta-paths.txt" || { echo 'FAIL: fix delta path missing' >&2; exit 1; }
[[ "$(wc -l < "$fix_run/delta-paths.txt" | tr -d ' ')" == 1 ]] || { echo 'FAIL: delta includes earlier change' >&2; exit 1; }
grep -qx 'tracked.txt' "$fix_run/changed-paths.txt" || { echo 'FAIL: cumulative tracked path missing' >&2; exit 1; }
grep -qx 'work.txt' "$fix_run/changed-paths.txt" || { echo 'FAIL: cumulative new path missing' >&2; exit 1; }
grep -q 'work.txt (+1/-0)' "$tmp/follow-pass.txt" || { echo 'FAIL: summary omitted fix' >&2; exit 1; }
! grep -q 'tracked.txt' "$tmp/follow-pass.txt" || { echo 'FAIL: summary includes earlier change' >&2; exit 1; }
grep -q 'earlier changes' "$FAKE_PROMPT_FILE" || { echo 'FAIL: follow-up prompt guidance missing' >&2; exit 1; }
grep -q "^FOLLOW_UP_OF=$parent_id$" "$fix_run/status.txt" || { echo 'FAIL: follow-up status missing parent' >&2; exit 1; }
grep -q '^TREE_BEFORE=' "$fix_run/status.txt" || { echo 'FAIL: follow-up status missing tree' >&2; exit 1; }
cmp -s "$tmp/index-before" "$quick/.git/index" || { echo 'FAIL: real Git index changed after follow-up' >&2; exit 1; }
rm -f "$quick/work.txt"
printf 'old line\n' > "$quick/tracked.txt"

# A protected change from round one remains a violation in round two.
protected_id="TASK-FOLLOW-PROTECTED-$$"
cp "$handoff" "$quick/.workflow/handoffs/$protected_id.md"
if (cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_PROTECTED_PATH="$quick/CLAUDE.md" bash scripts/codex-delegate.sh "$protected_id") > "$tmp/follow-protected-parent.txt" 2>&1; then
  echo 'FAIL: protected parent accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: protected parent exit code' >&2; exit 1; }; fi
if (cd "$quick" && CODEX_QUICK_CHECK=0 FAKE_CHANGED_PATH=work.txt bash scripts/codex-delegate.sh --follow-up "$protected_id" "$fix_id") > "$tmp/follow-protected-fix.txt" 2>&1; then
  echo 'FAIL: protected follow-up accepted' >&2; exit 1
else [[ $? == 4 ]] || { echo 'FAIL: protected follow-up exit code' >&2; exit 1; }; fi
rm -f "$quick/CLAUDE.md" "$quick/work.txt"
echo 'PASS: follow-up tree continuity, delta review, cumulative protection and index isolation'

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
