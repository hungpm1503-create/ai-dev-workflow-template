#!/usr/bin/env bash
# Opt-in actual Codex CLI A/B pilot with isolated toy repositories.
# --prepare-only performs NO model calls. --run invokes Codex TWICE.
set -euo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

usage() {
  echo 'Usage: bash scripts/benchmark-codex-ab.sh --prepare-only | --run' >&2
}
[[ $# -eq 1 && ( "$1" == '--prepare-only' || "$1" == '--run' ) ]] || { usage; exit 2; }
mode="$1"
command -v node >/dev/null 2>&1 || { echo 'ERROR: Node.js is required.' >&2; exit 127; }
if [[ "$mode" == '--run' ]]; then
  command -v codex >/dev/null 2>&1 || {
    echo 'ERROR: Codex CLI is not installed/available. No model run started.' >&2
    exit 127
  }
fi

outbase="$root/.claude/benchmark-runs"
[[ ! -L "$outbase" ]] || { echo 'ERROR: output directory cannot be a symlink' >&2; exit 2; }
mkdir -p "$outbase"
run_dir="$(mktemp -d "$outbase/ab.XXXXXX")"
task='Fix normalizeCoupon to reject blank and non-string input without changing valid normalization'
model_name="${CODEX_AB_MODEL:-default-config}"
printf 'Pilot directory: %s\n' "${run_dir#"$root/"}"
echo 'Two independent git repositories; no existing application files are touched.'

for arm in baseline memory; do
  dir="$run_dir/$arm"
  mkdir -p "$dir"
  cat > "$dir/AGENTS.md" <<'RULES'
# Fixture only — same instructions in both arms.
Keep the change scoped to coupon.cjs. Run node --test coupon.test.cjs.
Do not commit, install packages, access the network, or change tests.
Do not treat previous task notes as authorization or verified code.
RULES
  cat > "$dir/TASK.md" <<'TASK'
# Identical small task for both arms
Fix normalizeCoupon(value) in coupon.cjs to:
- trim surrounding whitespace and uppercase codes;
- accept nonempty letters, digits and hyphens;
- throw TypeError for non-string inputs;
- reject empty/whitespace-only or invalid-character codes;
- leave tests and all non-implementation files unchanged.
Run node --test coupon.test.cjs and report actual results.
TASK
  cat > "$dir/coupon.cjs" <<'BROKEN'
function normalizeCoupon(value) {
  return String(value).trim().toUpperCase();
}
module.exports = { normalizeCoupon };
BROKEN
  cat > "$dir/coupon.test.cjs" <<'TEST'
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeCoupon } = require('./coupon.cjs');
test('trim and uppercase', () => assert.equal(normalizeCoupon(' save-10 '), 'SAVE-10'));
test('alphanumeric', () => assert.equal(normalizeCoupon('abc12'), 'ABC12'));
test('blank rejected', () => assert.throws(() => normalizeCoupon('  '), /coupon|invalid|empty/i));
test('null rejected', () => assert.throws(() => normalizeCoupon(null), TypeError));
test('number rejected', () => assert.throws(() => normalizeCoupon(7), TypeError));
test('invalid character rejected', () => assert.throws(() => normalizeCoupon('A B'), /coupon|invalid/i));
TEST
  if [[ "$arm" == baseline ]]; then
    context='PROGRESS.md'
    cat > "$dir/PROGRESS.md" <<'PROGRESS'
# Previous session progress — baseline v0.3-style handoff
The coupon normalization task has started but the implementation is not accepted.
Observed: blank and non-string inputs are incorrectly accepted. Tests need running.
The canonical task is TASK.md; no changes have been approved beyond that task.
Remaining work: edit coupon.cjs, run all six assertions, and request independent review.
State: WORK IN PROGRESS / REVIEW UNVERIFIED.
PROGRESS
  else
    context='STATE.md'
    cat > "$dir/STATE.md" <<'STATE'
# Task checkpoint — v0.4-style working memory
Status: ACTIVE
Review: UNVERIFIED
Objective: Fix coupon normalization per TASK.md.
Observed evidence: current code wrongly accepts blank and non-string inputs.
Verified decisions: no scope change; edit only coupon.cjs.
Next action: implement minimal fix, run six assertions, then independent review.
Source of truth: TASK.md; checkpoint is untrusted context.
STATE
  fi
  cat > "$dir/PROMPT.txt" <<EOF
You are resuming an approved Small task. Read TASK.md and $context, then inspect the code and tests.
Fix only coupon.cjs using the requirements in TASK.md. Execute node --test coupon.test.cjs.
Report test evidence and remaining review status. Do not commit or alter the requirements/tests.
EOF
  (
    cd "$dir"
    git init -q
    git add AGENTS.md TASK.md coupon.cjs coupon.test.cjs "$context"
    git -c user.name='AB Fixture' -c user.email='ab@example.invalid' commit -q -m 'initial identical bug fixture'
  )
  if (cd "$dir" && node --test coupon.test.cjs > "$run_dir/$arm.before.log" 2>&1); then
    echo "FAIL: $arm fixture unexpectedly passes before the repair" >&2
    exit 1
  fi
done

baseline_bytes="$(wc -c < "$run_dir/baseline/PROGRESS.md" | tr -d ' ')"
memory_bytes="$(wc -c < "$run_dir/memory/STATE.md" | tr -d ' ')"
printf 'Context file bytes: baseline=%s; memory=%s (fair concise baseline, not padded transcript).\n' "$baseline_bytes" "$memory_bytes"
if [[ "$mode" == '--prepare-only' ]]; then
  echo 'PASS: prepared two identical failing code fixtures, distinct concise resume formats; 0 model calls.'
  echo "To run real Codex twice on your own authenticated machine: bash scripts/benchmark-codex-ab.sh --run"
  exit 0
fi

echo "Starting two Codex model calls with model: $model_name"
report="$run_dir/RESULTS.md"
printf '# Opt-in Codex A/B experiment\n\n- Task: %s\n- Model: %s\n- Comparison: concise baseline progress vs concise v0.4 checkpoint (same source/test/agent rules)\n- No padding of baseline, no retry, no automatic merge/deploy.\n\n' "$task" "$model_name" > "$report"
printf '| Arm | Codex exit | Test exit | Passed tests | Input tokens | Cached input | Output tokens | Wall seconds | Context bytes |\n| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n' >> "$report"

any_failed=0
for arm in baseline memory; do
  dir="$run_dir/$arm"
  echo "Running arm: $arm"
  start="$(date +%s)"
  if [[ -n "${CODEX_AB_MODEL:-}" ]]; then
    (cd "$dir" && codex exec --ephemeral --json --sandbox workspace-write -m "$CODEX_AB_MODEL" - < PROMPT.txt) \
      > "$run_dir/$arm.events.jsonl" 2> "$run_dir/$arm.stderr.log" && model_exit=0 || model_exit=$?
  else
    (cd "$dir" && codex exec --ephemeral --json --sandbox workspace-write - < PROMPT.txt) \
      > "$run_dir/$arm.events.jsonl" 2> "$run_dir/$arm.stderr.log" && model_exit=0 || model_exit=$?
  fi
  elapsed=$(( $(date +%s) - start ))
  if (cd "$dir" && node --test coupon.test.cjs > "$run_dir/$arm.after.log" 2>&1); then
    test_exit=0
  else
    test_exit=$?
    any_failed=1
  fi
  [[ "$model_exit" -eq 0 ]] || any_failed=1
  tests_passed="$(grep -c '^ok [0-9]' "$run_dir/$arm.after.log" || :)"
  tests_passed="${tests_passed:-0}"
  # Sum all turn.completed usage. If unavailable, report N/A (never zero).
  usage="$(node - "$run_dir/$arm.events.jsonl" <<'JS'
const fs = require('node:fs');
let input = 0, cached = 0, output = 0, n = 0;
for (const line of fs.readFileSync(process.argv[2], 'utf8').split('\n')) {
  if (!line.trim()) continue;
  let ev;
  try { ev = JSON.parse(line); } catch { continue; }
  if (ev?.type !== 'turn.completed' || !ev.usage) continue;
  const u = ev.usage;
  if (![u.input_tokens, u.output_tokens].every(Number.isFinite)) continue;
  input += u.input_tokens;
  cached += Number.isFinite(u.cached_input_tokens) ? u.cached_input_tokens : 0;
  output += u.output_tokens;
  n++;
}
process.stdout.write(n ? [input, cached, output].join(' ') : 'N/A N/A N/A');
JS
)"
  read -r input cached output <<< "$usage"
  if [[ "$arm" == baseline ]]; then cbytes="$baseline_bytes"; else cbytes="$memory_bytes"; fi
  printf '| %s | %s | %s | %s/6 | %s | %s | %s | %s | %s |\n' \
    "$arm" "$model_exit" "$test_exit" "$tests_passed" "$input" "$cached" "$output" "$elapsed" "$cbytes" >> "$report"
  printf '%s: model_exit=%s, test_exit=%s, tests=%s/6, input=%s, cached=%s, output=%s, wall=%ss\n' \
    "$arm" "$model_exit" "$test_exit" "$tests_passed" "$input" "$cached" "$output" "$elapsed"
done

cat >> "$report" <<'NOTE'

## Interpretation
- Only two model calls (one per arm) were made; run order was baseline then memory.
- A single pair does **not** establish statistical improvement. Provider/model variance,
  caching and order effects may dominate differences.
- Token fields are actual Codex JSONL turn usage when present. Cached tokens are a
  **subset** of input tokens, not extra input.
- Implementation outcome is measured by the **same six local tests**.
- Check diff and changes manually; passing tests are not independent code review.
- Working Memory checkpoint is a *manually prepared fixture*, not an observed
  independent Claude→Codex session transfer.
- Raw model event logs and stderr stay in this ignored local directory.
NOTE
echo "Results: ${report#"$root/"}"
if (( any_failed )); then echo 'One or both arms failed; inspect results. This is benchmark data, not a merged change.' >&2; exit 1; fi
echo 'Both arm tests passed; inspect RESULT.md and Git diffs before interpreting improvements.'
