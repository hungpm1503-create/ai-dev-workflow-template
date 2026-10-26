#!/usr/bin/env bash
# Deterministic offline benchmark: one real tiny code fix, two resume-context formats.
# This does NOT invoke Claude or Codex, and is not a measured LLM-token benchmark.
set -euo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

command -v node >/dev/null 2>&1 || { echo 'ERROR: Node.js is required for this small coding fixture.' >&2; exit 127; }
task="TASK-BENCH-COUPON-$$"
tmp="$(mktemp -d)"
mkdir -p ".claude/handoffs"
run_dir="$(mktemp -d ".claude/handoffs/$task-run.XXXXXX")"
run_name="$(basename "$run_dir")"
handoff=".claude/handoffs/$task.md"
memory_dir=".claude/work-memory/$task"
cleanup() {
  rm -f "$handoff"
  rm -rf "$run_dir" "$memory_dir" "$tmp"
}
trap cleanup EXIT

# One concrete Small task. The first implementation contains a real bug.
cat > "$tmp/coupon.cjs" <<'BUG'
function normalizeCoupon(value) {
  return String(value).trim().toUpperCase();
}
module.exports = { normalizeCoupon };
BUG
cat > "$tmp/coupon.test.cjs" <<'TEST'
const assert = require('node:assert/strict');
const { normalizeCoupon } = require('./coupon.cjs');
assert.equal(normalizeCoupon(' save-10 '), 'SAVE-10');
assert.equal(normalizeCoupon('abc12'), 'ABC12');
assert.throws(() => normalizeCoupon('  '), /coupon/i);
assert.throws(() => normalizeCoupon(null), TypeError);
console.log('PASS: 4 coupon acceptance checks');
TEST

# Before-fix test should fail.
if node "$tmp/coupon.test.cjs" > "$tmp/before.log" 2>&1; then
  echo 'FAIL: benchmark starting bug was not reproduced' >&2; exit 1
else
  before_exit=$?
fi

# Deterministic fixture correction: deliberately NOT an AI implementation.
cat > "$tmp/coupon.cjs" <<'FIX'
function normalizeCoupon(value) {
  if (typeof value !== 'string') throw new TypeError('coupon must be a string');
  const code = value.trim().toUpperCase();
  if (!/^[A-Z0-9-]+$/.test(code)) throw new Error('coupon must contain letters, digits or hyphens');
  return code;
}
module.exports = { normalizeCoupon };
FIX
if node "$tmp/coupon.test.cjs" > "$tmp/after.log" 2>&1; then
  after_exit=0
else
  after_exit=$?
  cat "$tmp/after.log" >&2
  echo 'FAIL: fixed implementation did not pass acceptance checks' >&2
  exit 1
fi

cat > "$handoff" <<EOF
# $task — Coupon normalization

## Objective
Trim and uppercase coupon codes without accepting blank or non-string input.

## Approval status
Status: APPROVED

## Acceptance
AC-01: " save-10 " normalizes to SAVE-10.
AC-02: "abc12" normalizes to ABC12.
AC-03: whitespace-only code is rejected.
AC-04: null is rejected with TypeError.

## Evidence
Before implementation: test exit code $before_exit, some criteria FAIL.
After deterministic fixture correction: test exit code $after_exit, 4/4 PASS.
Implementation used here: scripted test fixture, NOT a Codex/Claude call.
## Outstanding
Human review of diff / security; NOT YET APPROVED for production.
EOF
printf '%040d\n' 0 > "$run_dir/head-before.txt"
printf 'CODEX_EXIT_CODE=0\nFINAL_EXIT_CODE=0\n' > "$run_dir/status.txt"
printf 'coupon.cjs\n' > "$run_dir/changed-paths.txt"
cat > "$run_dir/completion.md" <<'DONE'
Implementation fixture: coupon.cjs corrected to reject blank and non-string codes.
Tests: 4/4 passed after fix; initial buggy implementation failed.
Status: awaiting independent human review; no merge or deployment.
DONE

# Synthetic verbose historical context. This is intentionally redundant and
# is NOT a real Claude/Codex transcript. It is the baseline 'full replay' input.
{
  for i in $(seq 1 150); do
    printf 'Synthetic historical trace %03d: inspected existing implementation and acceptance criteria; no additional decision recorded.\n' "$i"
  done
  printf 'Outcome: corrected coupon normalization, 4/4 tests PASS, awaiting human review.\n'
} > "$run_dir/synthetic-history.log"
cat "$handoff" "$run_dir/synthetic-history.log" "$run_dir/completion.md" > "$tmp/baseline-context.txt"

# Memory-based continuation: concise state plus deterministic CLI metadata.
bash scripts/workflow-memory.sh init "$task" >/dev/null
cat > "$memory_dir/STATE.md" <<EOF
# Shared task state — $task

Status: IMPLEMENTED_PENDING_REVIEW
Review: UNVERIFIED
Source: deterministic synthetic coding fixture (not Codex/Claude)

## Objective / approved source
Normalize coupon code: trim and uppercase; reject whitespace-only and non-string inputs.
Canonical task: .claude/handoffs/$task.md

## Confirmed decisions and evidence
AC-01..AC-04: 4/4 checks PASS after fixture correction.
Before fix: test exit $before_exit (FAIL).
After fix: test exit $after_exit (PASS).
No production PR, merge or deployment was performed.

## Blockers / next action
Next action: independent human review of the code and acceptance evidence.
Do NOT infer human approval from test success.
EOF
bash scripts/workflow-memory.sh record-run "$task" "$run_name" >/dev/null
bash scripts/workflow-memory.sh show "$task" > "$tmp/with-memory-context.txt"

# Both contexts preserve key factual status, but they differ in input volume.
for f in "$tmp/baseline-context.txt" "$tmp/with-memory-context.txt"; do
  grep -Fqi 'coupon' "$f" || { echo 'FAIL: context lost objective' >&2; exit 1; }
  grep -Eq '4/4|AC-01' "$f" || { echo 'FAIL: context lost acceptance evidence' >&2; exit 1; }
  grep -Fqi 'review' "$f" || { echo 'FAIL: context lost next review action' >&2; exit 1; }
done
grep -Fq 'Review: UNVERIFIED' "$tmp/with-memory-context.txt" || {
  echo 'FAIL: working memory incorrectly certified review' >&2; exit 1;
}
grep -Fq 'Next action: independent human review' "$tmp/with-memory-context.txt" || {
  echo 'FAIL: checkpoint lost concrete next action' >&2; exit 1;
}

baseline_bytes="$(wc -c < "$tmp/baseline-context.txt" | tr -d ' ')"
memory_bytes="$(wc -c < "$tmp/with-memory-context.txt" | tr -d ' ')"
baseline_words="$(wc -w < "$tmp/baseline-context.txt" | tr -d ' ')"
memory_words="$(wc -w < "$tmp/with-memory-context.txt" | tr -d ' ')"
(( baseline_bytes > memory_bytes )) || { echo 'FAIL: checkpoint was not smaller than replay' >&2; exit 1; }
reduction="$(awk -v b="$baseline_bytes" -v m="$memory_bytes" 'BEGIN { printf "%.1f", 100*(b-m)/b }')"

printf 'BENCHMARK: tiny coupon normalization + session resume (offline, synthetic)\n'
printf 'Code test: before FAIL (exit %s); after PASS (exit %s; 4/4 checks)\n' "$before_exit" "$after_exit"
printf 'Full replay input: %s bytes; %s words\n' "$baseline_bytes" "$baseline_words"
printf 'Checkpoint input: %s bytes; %s words\n' "$memory_bytes" "$memory_words"
printf 'Input-byte reduction versus deliberately verbose full replay: %s%%\n' "$reduction"
printf 'State fidelity: objective, acceptance evidence, review status, next action present\n'
printf 'MODEL CALLS: 0. These are NOT actual model tokens, latency, quality or cost savings.\n'

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '## Offline benchmark: small coupon normalization task'
    echo
    echo '| Measurement | Full replay (synthetic) | Working Memory v0.4 |'
    echo '| --- | ---: | ---: |'
    printf '| Input bytes | %s | %s |\n' "$baseline_bytes" "$memory_bytes"
    printf '| Input words | %s | %s |\n' "$baseline_words" "$memory_words"
    echo
    printf '**Byte reduction versus verbose full replay:** %s%%.\n\n' "$reduction"
    echo 'Fixture code: FAIL before, PASS after (4/4 checks). Both contexts preserve objective, test evidence, review state and next action.'
    echo
    echo '**Limitations:** deterministic scripted correction, mocked verbose trace, no independent Claude/Codex model calls. Byte/word counts are not tokenizer counts and do not measure AI quality, latency or billed tokens.'
  } >> "$GITHUB_STEP_SUMMARY"
fi
