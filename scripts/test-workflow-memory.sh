#!/usr/bin/env bash
# Offline checkpoint tests; no Codex, API, or model calls.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
task="TASK-MEMORY-$$"
runs=".claude/handoffs"
mkdir -p "$runs"
run_dir="$(mktemp -d "$runs/$task-run.XXXXXX")"
run_name="$(basename "$run_dir")"
dir=".claude/work-memory/$task"
tmp="$(mktemp)"
cleanup() {
  rm -rf "$run_dir" "$dir"
  rm -f "$tmp"
}
trap cleanup EXIT
bash scripts/workflow-memory.sh init "$task" > "$tmp"
[[ -f "$dir/STATE.md" ]] || { echo 'FAIL: state missing' >&2; exit 1; }
printf '\nFixtureKeywordXYZ\n' >> "$dir/STATE.md"
bash scripts/workflow-memory.sh init "$task" >/dev/null
grep -q 'FixtureKeywordXYZ' "$dir/STATE.md" || { echo 'FAIL: state overwritten' >&2; exit 1; }
bash scripts/workflow-memory.sh search FixtureKeywordXYZ | grep -F -q "$dir/STATE.md"
printf '%040d\n' 0 > "$run_dir/head-before.txt"
printf 'CODEX_EXIT_CODE=9\nFINAL_EXIT_CODE=9\n' > "$run_dir/status.txt"
printf 'src/example.cs\n' > "$run_dir/changed-paths.txt"
printf 'PRIVATE_FAKE_LOG_DO_NOT_COPY\n' > "$run_dir/codex.log"
bash scripts/workflow-memory.sh record-run "$task" "$run_name" > "$tmp"
grep -F -q 'Reported final exit code: 9' "$dir/RUN-$run_name.md"
grep -F -q 'Review: UNVERIFIED' "$dir/LATEST.md"
if grep -F -q 'PRIVATE_FAKE_LOG_DO_NOT_COPY' "$dir/RUN-$run_name.md"; then
  echo 'FAIL: raw log copied into checkpoint' >&2; exit 1
fi
bash scripts/workflow-memory.sh show "$task" | grep -q FixtureKeywordXYZ
if bash scripts/workflow-memory.sh record-run "$task" "$run_name" >/dev/null 2>&1; then
  echo 'FAIL: run event overwritten' >&2; exit 1
fi
if bash scripts/workflow-memory.sh show "../escape" >/dev/null 2>&1; then
  echo 'FAIL: task ID traversal accepted' >&2; exit 1
fi
if bash scripts/workflow-memory.sh record-run "$task" '../escape' >/dev/null 2>&1; then
  echo 'FAIL: run path traversal accepted' >&2; exit 1
fi
git check-ignore -q "$dir/STATE.md" || { echo 'FAIL: working memory is not gitignored' >&2; exit 1; }
echo 'PASS: checkpoint init, search, run recording, review uncertainty, no overwrite/traversal, privacy and gitignore'
