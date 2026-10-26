#!/usr/bin/env bash
# Opt-in Codex A/B v2: v0.3-style prose handoff vs v0.4-style checkpoint.
# Controls: isolated per-run CODEX_HOME (no user plugins/skills/memories), pinned model+effort,
# identical file name/prompt/source/tests (only HANDOFF.md content differs), hidden tests,
# counterbalanced order, N repeats, tasks A (single session) and B (resume half-done work).
# --prepare-only performs NO model calls. --run invokes Codex 2*N*2 times.
set -euo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

usage() { echo 'Usage: bash scripts/benchmark-codex-ab-v2.sh --prepare-only | --run [--n N] [--tasks "A B"]' >&2; }
mode="${1:-}"; shift || true
n=5
tasks='A B'
while [[ $# -gt 0 ]]; do
  case "$1" in --n) n="${2:-}"; shift 2 ;; --tasks) tasks="${2:-}"; shift 2 ;; *) usage; exit 2 ;; esac
done
[[ "$mode" == '--prepare-only' || "$mode" == '--run' ]] || { usage; exit 2; }
[[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo 'ERROR: --n must be a positive integer' >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo 'ERROR: Node.js is required.' >&2; exit 127; }
if [[ "$mode" == '--run' ]]; then
  command -v codex >/dev/null 2>&1 || { echo 'ERROR: Codex CLI not installed. No model run started.' >&2; exit 127; }
  command -v perl >/dev/null 2>&1 || { echo 'ERROR: perl required for the run watchdog.' >&2; exit 127; }
  auth_src="${CODEX_HOME:-$HOME/.codex}/auth.json"
  [[ -f "$auth_src" ]] || { echo "ERROR: $auth_src not found; run codex login." >&2; exit 1; }
fi

MODEL="${CODEX_AB_MODEL:-gpt-6-sol}"
EFFORT="${CODEX_AB_EFFORT:-high}"
TIMEOUT_S="${CODEX_AB_TIMEOUT:-900}"
report_js="$root/scripts/benchmark-ab-v2-report.cjs"

outbase="$root/.claude/benchmark-runs"
[[ ! -L "$outbase" ]] || { echo 'ERROR: output directory cannot be a symlink' >&2; exit 2; }
mkdir -p "$outbase"
run_dir="$(mktemp -d "$outbase/abv2.XXXXXX")"
homes="$(mktemp -d "${TMPDIR:-/tmp}/ab-homes.XXXXXX")"
trap 'rm -rf "$homes"' EXIT
mkdir -p "$run_dir/runs" "$run_dir/work" "$run_dir/hidden" "$run_dir/ref"
printf 'Run directory: %s\n' "${run_dir#"$root/"}"

# ---------------------------------------------------------------- fixtures
write_hidden_and_ref() {
  cat > "$run_dir/hidden/A.test.cjs" <<'T'
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeCoupon } = require('./coupon.cjs');
test('tabs and newlines trimmed', () => assert.equal(normalizeCoupon('\tab-1\n'), 'AB-1'));
test('empty string rejected', () => assert.throws(() => normalizeCoupon(''), /coupon|invalid|empty/i));
test('underscore rejected', () => assert.throws(() => normalizeCoupon('a_b'), /coupon|invalid/i));
test('inner tab rejected', () => assert.throws(() => normalizeCoupon('a\tb'), /coupon|invalid/i));
test('undefined TypeError', () => assert.throws(() => normalizeCoupon(undefined), TypeError));
test('object TypeError', () => assert.throws(() => normalizeCoupon({}), TypeError));
test('array TypeError', () => assert.throws(() => normalizeCoupon(['a']), TypeError));
test('hyphenated code', () => assert.equal(normalizeCoupon('a-b-1'), 'A-B-1'));
T
  cat > "$run_dir/ref/A.coupon.cjs" <<'T'
function normalizeCoupon(value) {
  if (typeof value !== 'string') throw new TypeError('Coupon code must be a string');
  const code = value.trim();
  if (!/^[A-Za-z0-9-]+$/.test(code)) throw new Error('Invalid coupon code');
  return code.toUpperCase();
}
module.exports = { normalizeCoupon };
T
  cat > "$run_dir/hidden/B.test.cjs" <<'T'
const test = require('node:test');
const assert = require('node:assert/strict');
const { parsePrice, formatPrice, applyDiscount } = require('./price.cjs');
const pct = (value) => ({ type: 'percent', value });
const fix = (value) => ({ type: 'fixed', value });
test('half-up .5 rounds the discount up', () => assert.equal(applyDiscount(5, pct(10)), 4));
test('half-up 1.5 -> 2', () => assert.equal(applyDiscount(15, pct(10)), 13));
test('1.4 -> 1', () => assert.equal(applyDiscount(14, pct(10)), 13));
test('502.5 -> 503', () => assert.equal(applyDiscount(1005, pct(50)), 502));
test('100 percent', () => assert.equal(applyDiscount(999, pct(100)), 0));
test('0 percent', () => assert.equal(applyDiscount(999, pct(0)), 999));
test('fixed clamps to zero', () => assert.equal(applyDiscount(100, fix(500)), 0));
test('percent > 100 RangeError', () => assert.throws(() => applyDiscount(100, pct(101)), RangeError));
test('percent < 0 RangeError', () => assert.throws(() => applyDiscount(100, pct(-1)), RangeError));
test('percent non-integer RangeError', () => assert.throws(() => applyDiscount(100, pct(10.5)), RangeError));
test('fixed negative RangeError', () => assert.throws(() => applyDiscount(100, fix(-5)), RangeError));
test('null rule RangeError', () => assert.throws(() => applyDiscount(100, null), RangeError));
test('negative cents TypeError', () => assert.throws(() => applyDiscount(-1, pct(10)), TypeError));
test('fractional cents TypeError', () => assert.throws(() => applyDiscount(1.5, pct(10)), TypeError));
test('string cents TypeError', () => assert.throws(() => applyDiscount('100', pct(10)), TypeError));
test('end to end', () => assert.equal(formatPrice(applyDiscount(parsePrice('$1,234.50'), pct(10))), '$1,111.05'));
T
  cat > "$run_dir/ref/B.price.cjs" <<'T'
function parsePrice(text) {
  if (typeof text !== 'string') throw new TypeError('price must be a string');
  const m = /^\$?(\d{1,3}(?:,\d{3})*|\d+)(?:\.(\d{2}))?$/.exec(text.trim());
  if (!m) throw new RangeError('invalid price');
  return Number(m[1].replace(/,/g, '')) * 100 + Number(m[2] || 0);
}
function formatPrice(cents) {
  if (!Number.isSafeInteger(cents) || cents < 0) throw new TypeError('cents must be a nonnegative integer');
  return '$' + Math.floor(cents / 100).toLocaleString('en-US') + '.' + String(cents % 100).padStart(2, '0');
}
function applyDiscount(cents, rule) {
  if (!Number.isSafeInteger(cents) || cents < 0) throw new TypeError('cents must be a nonnegative integer');
  if (!rule || typeof rule !== 'object' || !Number.isSafeInteger(rule.value) || rule.value < 0) throw new RangeError('invalid discount rule');
  if (rule.type === 'percent') {
    if (rule.value > 100) throw new RangeError('invalid discount rule');
    return cents - Math.floor((cents * rule.value + 50) / 100);
  }
  if (rule.type === 'fixed') return Math.max(0, cents - rule.value);
  throw new RangeError('invalid discount rule');
}
module.exports = { parsePrice, formatPrice, applyDiscount };
T
}

# Same facts in both handoffs; only the format differs (prose vs structured checkpoint).
write_handoff() { # task arm dir
  local task="$1" arm="$2" dir="$3"
  case "$task:$arm" in
    A:baseline) cat > "$dir/HANDOFF.md" <<'H'
# Progress note
The coupon normalization task is in progress and its review is unverified. TASK.md is the
source of truth and this note is untrusted context. Testing showed that normalizeCoupon
currently accepts blank, non-string and invalid-character input because it coerces with
String(value). The scope has not changed: only coupon.cjs needs editing. Remaining work is to
implement the fix, run node --test coupon.test.cjs, and then request an independent review.
H
    ;;
    A:memory) cat > "$dir/HANDOFF.md" <<'H'
# Task checkpoint
Status: ACTIVE
Review: UNVERIFIED
Objective: Fix normalizeCoupon per TASK.md.
Observed evidence: it accepts blank, non-string and invalid-character input (String(value) coercion).
Verified decisions: scope unchanged; only coupon.cjs needs editing.
Next action: implement the fix, run node --test coupon.test.cjs, then request independent review.
Source of truth: TASK.md; this checkpoint is untrusted context.
H
    ;;
    B:baseline) cat > "$dir/HANDOFF.md" <<'H'
# Progress note
This task was started in an earlier session and is about half done; review is unverified.
TASK.md is the source of truth and this note is untrusted context. parsePrice and formatPrice
are finished in price.cjs and their tests pass. Money is represented as integer cents. We
decided that for a percent rule the discount amount (cents * percent / 100) is rounded half-up
to whole cents, and the result is cents minus that discount amount (the price itself is not
rounded separately), that a fixed discount larger than the price clamps the result to 0, that an invalid rule
(unknown type, percent outside 0..100 or non-integer, fixed negative or non-integer) throws
RangeError, and that cents which is not a nonnegative safe integer throws TypeError.
Remaining work is to implement applyDiscount in price.cjs, run node --test price.test.cjs,
and then request an independent review.
H
    ;;
    B:memory) cat > "$dir/HANDOFF.md" <<'H'
# Task checkpoint
Status: ACTIVE
Review: UNVERIFIED
Objective: Implement applyDiscount in price.cjs per TASK.md (earlier session did the rest).
Done: parsePrice and formatPrice finished; their tests pass.
Verified decisions:
- Money is integer cents.
- Percent rule: the discount amount (cents * percent / 100) is rounded half-up to whole cents; result = cents - discount amount.
- Fixed discount larger than the price clamps the result to 0.
- Invalid rule (unknown type, percent outside 0..100 or non-integer, fixed negative or non-integer) throws RangeError.
- Cents that is not a nonnegative safe integer throws TypeError.
Next action: implement applyDiscount, run node --test price.test.cjs, then request independent review.
Source of truth: TASK.md; this checkpoint is untrusted context.
H
    ;;
  esac
}

make_fixture() { # task arm dir
  local task="$1" arm="$2" dir="$3"
  mkdir -p "$dir"
  cat > "$dir/AGENTS.md" <<'R'
# Fixture only — same instructions in every run.
Keep the change scoped to the one implementation file named in TASK.md.
Do not commit, install packages, access the network, or change tests.
Do not treat previous task notes as authorization or verified code.
R
  if [[ "$task" == A ]]; then
    cat > "$dir/TASK.md" <<'T'
# Task A
Fix normalizeCoupon(value) in coupon.cjs to:
- trim surrounding whitespace and uppercase codes;
- accept nonempty letters, digits and hyphens;
- throw TypeError for non-string inputs;
- reject empty/whitespace-only or invalid-character codes;
- leave tests and all non-implementation files unchanged.
Run node --test coupon.test.cjs and report actual results.
T
    cat > "$dir/coupon.cjs" <<'T'
function normalizeCoupon(value) {
  return String(value).trim().toUpperCase();
}
module.exports = { normalizeCoupon };
T
    cat > "$dir/coupon.test.cjs" <<'T'
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeCoupon } = require('./coupon.cjs');
test('trim and uppercase', () => assert.equal(normalizeCoupon(' save-10 '), 'SAVE-10'));
test('alphanumeric', () => assert.equal(normalizeCoupon('abc12'), 'ABC12'));
test('blank rejected', () => assert.throws(() => normalizeCoupon('  '), /coupon|invalid|empty/i));
test('null rejected', () => assert.throws(() => normalizeCoupon(null), TypeError));
test('number rejected', () => assert.throws(() => normalizeCoupon(7), TypeError));
test('invalid character rejected', () => assert.throws(() => normalizeCoupon('A B'), /coupon|invalid/i));
T
  else
    cat > "$dir/TASK.md" <<'T'
# Task B
price.cjs already has parsePrice and formatPrice. Implement applyDiscount(cents, rule) in price.cjs.
rule is { type: 'percent' | 'fixed', value }. It returns the price in cents after the discount.
Follow the verified decisions in HANDOFF.md. Do not change the existing functions or any tests.
Run node --test price.test.cjs and report actual results.
T
    cp "$run_dir/ref/B.price.cjs" "$dir/price.full.tmp"
    node -e '
const fs=require("fs");const s=fs.readFileSync(process.argv[1],"utf8");
const i=s.indexOf("function applyDiscount");const j=s.indexOf("module.exports");
fs.writeFileSync(process.argv[2],s.slice(0,i)+"module.exports = { parsePrice, formatPrice };\n");' \
      "$dir/price.full.tmp" "$dir/price.cjs"
    rm -f "$dir/price.full.tmp"
    cat > "$dir/price.test.cjs" <<'T'
const test = require('node:test');
const assert = require('node:assert/strict');
const { parsePrice, formatPrice, applyDiscount } = require('./price.cjs');
test('parsePrice', () => assert.equal(parsePrice('$1,234.50'), 123450));
test('formatPrice', () => assert.equal(formatPrice(123450), '$1,234.50'));
test('parsePrice rejects garbage', () => assert.throws(() => parsePrice('abc'), RangeError));
test('percent discount', () => assert.equal(applyDiscount(1000, { type: 'percent', value: 10 }), 900));
test('fixed discount', () => assert.equal(applyDiscount(1000, { type: 'fixed', value: 250 }), 750));
test('unknown type rejected', () => assert.throws(() => applyDiscount(1000, { type: 'bogus', value: 1 }), RangeError));
T
  fi
  write_handoff "$task" "$arm" "$dir"
  cat > "$dir/PROMPT.txt" <<'P'
You are resuming an approved Small task. Read TASK.md and HANDOFF.md, then inspect the code and tests.
Make the change described in TASK.md. Execute the test command named in TASK.md.
Report test evidence and remaining review status. Do not commit or alter the requirements/tests.
P
  (
    cd "$dir"
    git init -q
    git add -A
    git -c user.name='AB Fixture' -c user.email='ab@example.invalid' commit -q -m 'initial fixture'
  )
}

src_file() { [[ "$1" == A ]] && echo coupon.cjs || echo price.cjs; }
test_file() { [[ "$1" == A ]] && echo coupon.test.cjs || echo price.test.cjs; }
read_files() { echo "TASK.md,HANDOFF.md,$(src_file "$1"),$(test_file "$1")"; }

count() { # file label -> number after "ℹ <label> "
  grep -oE "ℹ $2 [0-9]+" "$1" | tail -1 | awk '{print $3}' || true
}

# ---------------------------------------------------------------- preflight (no model)
write_hidden_and_ref
echo '== Preflight (0 model calls) =='
for task in A B; do
  for arm in baseline memory; do make_fixture "$task" "$arm" "$run_dir/prep/$task-$arm"; done
  pb="$run_dir/prep/$task-baseline"; pm="$run_dir/prep/$task-memory"
  # Only HANDOFF.md may differ between arms.
  if ! diff -rq --exclude=.git --exclude=HANDOFF.md "$pb" "$pm" >/dev/null; then
    echo "FAIL: task $task arms differ beyond HANDOFF.md" >&2; exit 1
  fi
  src="$(src_file "$task")"; tst="$(test_file "$task")"
  # Visible tests must fail initially; hidden tests must fail initially.
  for arm in baseline memory; do
    d="$run_dir/prep/$task-$arm"
    if (cd "$d" && node --test "$tst" >/dev/null 2>&1); then echo "FAIL: $task visible tests pass before fix" >&2; exit 1; fi
    cp "$run_dir/hidden/$task.test.cjs" "$d/hidden.test.cjs"
    if (cd "$d" && node --test hidden.test.cjs >/dev/null 2>&1); then echo "FAIL: $task hidden tests pass before fix" >&2; exit 1; fi
  done
  # Reference solution must pass visible AND hidden tests (validates the tests themselves).
  ref="$run_dir/prep/$task-ref"; cp -R "$pb" "$ref"
  cp "$run_dir/ref/$task.$src" "$ref/$src"
  (cd "$ref" && node --test "$tst" >"$run_dir/prep/$task.ref.visible.log" 2>&1) || { echo "FAIL: reference fails visible $task" >&2; exit 1; }
  (cd "$ref" && node --test hidden.test.cjs >"$run_dir/prep/$task.ref.hidden.log" 2>&1) || { echo "FAIL: reference fails hidden $task" >&2; exit 1; }
  printf 'Task %s: arms identical except HANDOFF.md (baseline=%sB, memory=%sB); reference passes visible %s/%s + hidden %s/%s\n' "$task" \
    "$(wc -c < "$pb/HANDOFF.md" | tr -d ' ')" "$(wc -c < "$pm/HANDOFF.md" | tr -d ' ')" \
    "$(count "$run_dir/prep/$task.ref.visible.log" pass)" "$(( $(count "$run_dir/prep/$task.ref.visible.log" pass) + $(count "$run_dir/prep/$task.ref.visible.log" fail) ))" \
    "$(count "$run_dir/prep/$task.ref.hidden.log" pass)" "$(( $(count "$run_dir/prep/$task.ref.hidden.log" pass) + $(count "$run_dir/prep/$task.ref.hidden.log" fail) ))"
done
if [[ "$mode" == '--prepare-only' ]]; then
  echo 'PASS: fixtures valid, tests discriminate, reference solutions pass; 0 model calls.'
  exit 0
fi

# ---------------------------------------------------------------- run
cat > "$run_dir/config.txt" <<EOF
model=$MODEL reasoning_effort=$EFFORT trials_per_arm_per_task=$n timeout_s=$TIMEOUT_S
isolation: fresh CODEX_HOME per run (auth.json + minimal config only; no plugins/skills/memories)
order: counterbalanced per trial (odd: baseline first, even: memory first)
tasks: $tasks (several tasks = concurrent tracks); runs inside a track are sequential
codex: $(codex --version 2>&1 | head -1)
started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
echo "Config: model=$MODEL effort=$EFFORT n=$n tasks=$tasks (total $((n*2*$(wc -w <<< "$tasks"))) Codex runs)"

run_one() { # task arm trial position
  local task="$1" arm="$2" trial="$3" pos="$4" id="$1-$2-$3"
  local dir="$run_dir/work/$id" home="$homes/$id" ev="$run_dir/work/$id.events.jsonl"
  make_fixture "$task" "$arm" "$dir"
  mkdir -p "$home"; cp "$auth_src" "$home/auth.json"; chmod 600 "$home/auth.json"
  printf 'model = "%s"\nmodel_reasoning_effort = "%s"\n' "$MODEL" "$EFFORT" > "$home/config.toml"
  local start end model_exit
  start="$(date +%s)"
  ( cd "$dir" && CODEX_HOME="$home" perl -e 'alarm shift; exec @ARGV' "$TIMEOUT_S" \
      codex exec --ephemeral --json --sandbox workspace-write -m "$MODEL" -c "model_reasoning_effort=\"$EFFORT\"" - < PROMPT.txt ) \
      > "$ev" 2> "$run_dir/work/$id.stderr.log" && model_exit=0 || model_exit=$?
  end="$(date +%s)"
  rm -rf "$home"
  local src tst changed diff_sha diff_lines
  src="$(src_file "$task")"; tst="$(test_file "$task")"
  changed="$(cd "$dir" && git status --porcelain | awk '{print $2}' | grep -vE "^(PROMPT.txt|$src)$" | paste -sd, - || true)"
  diff_sha="$(cd "$dir" && git diff -- "$src" | shasum -a 256 | cut -d' ' -f1)"
  diff_lines="$(cd "$dir" && git diff --numstat -- "$src" | awk '{a+=$1+$2} END{print a+0}')"
  (cd "$dir" && node --test "$tst" > "$run_dir/work/$id.visible.log" 2>&1) || true
  cp "$run_dir/hidden/$task.test.cjs" "$dir/hidden.test.cjs"
  (cd "$dir" && node --test hidden.test.cjs > "$run_dir/work/$id.hidden.log" 2>&1) || true
  node "$report_js" record "$ev" "$run_dir/runs/$id.json" \
    "task=$task" "arm=$arm" "trial=$trial" "position=$pos" "model_exit=$model_exit" "wall_s=$((end-start))" \
    "vis_pass=$(count "$run_dir/work/$id.visible.log" pass)" "vis_fail=$(count "$run_dir/work/$id.visible.log" fail)" \
    "hid_pass=$(count "$run_dir/work/$id.hidden.log" pass)" "hid_fail=$(count "$run_dir/work/$id.hidden.log" fail)" \
    "diff_sha=$diff_sha" "diff_lines=$diff_lines" "changed=$changed" "files=$(read_files "$task")"
  echo "[$task trial $trial pos $pos] $arm done: exit=$model_exit wall=$((end-start))s"
}

run_track() {
  local task="$1" trial
  for ((trial=1; trial<=n; trial++)); do
    if (( trial % 2 )); then run_one "$task" baseline "$trial" 1; run_one "$task" memory "$trial" 2
    else run_one "$task" memory "$trial" 1; run_one "$task" baseline "$trial" 2; fi
  done
}

pids=()
for t in $tasks; do run_track "$t" > "$run_dir/track-$t.log" 2>&1 & pids+=($!); done
fail=0
for p in "${pids[@]}"; do wait "$p" || fail=1; done
node "$report_js" summary "$run_dir" > "$run_dir/RESULTS.md"
echo "Results: ${run_dir#"$root/"}/RESULTS.md"
(( fail == 0 )) || { echo 'A track failed; inspect track logs.' >&2; exit 1; }
echo 'Done. Review RESULTS.md and the git diffs under work/ before interpreting.'
