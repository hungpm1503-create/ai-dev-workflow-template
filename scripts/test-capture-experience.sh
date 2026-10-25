#!/usr/bin/env bash
# Offline fixtures. No model calls or application-file modifications.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
task="TASK-EVIDENCE-$$"
handoffs="$root/.claude/handoffs"
mkdir -p "$handoffs"
run_dir="$(mktemp -d "$handoffs/$task-run.XXXXXX")"
name="$(basename "$run_dir")"
draft="$root/.claude/experience-drafts/EXP-$name.md"
clean() {
  rm -f "$draft"
  rm -rf "$run_dir"
  rmdir "$root/.claude/experience-drafts" 2>/dev/null || :
}
trap clean EXIT
printf '%040d\n' 0 > "$run_dir/head-before.txt"
printf 'CODEX_EXIT_CODE=9\nFINAL_EXIT_CODE=9\n' > "$run_dir/status.txt"
printf 'src/example.cs\n' > "$run_dir/changed-paths.txt"
printf 'SENSITIVE_SIMULATED_LOG_DO_NOT_COPY\n' > "$run_dir/codex.log"

bash scripts/capture-experience.sh "$task" "$name" >/dev/null
[[ -f "$draft" ]]
grep -F -q 'Status: DRAFT' "$draft"
grep -F -q 'Wrapper final exit code: 9' "$draft"
grep -F -q 'Changed paths reported: 1' "$draft"
grep -F -q 'Baseline HEAD: 0000000000000000000000000000000000000000' "$draft"
if grep -F -q 'SENSITIVE_SIMULATED_LOG_DO_NOT_COPY' "$draft"; then
  echo 'FAIL: copied raw Codex log into experience draft' >&2; exit 1
fi
if bash scripts/capture-experience.sh "$task" "$name" >/dev/null 2>&1; then
  echo 'FAIL: overwrote existing draft' >&2; exit 1
fi
if bash scripts/capture-experience.sh "$task" '../escape' >/dev/null 2>&1; then
  echo 'FAIL: accepted traversal path' >&2; exit 1
fi
if git check-ignore -q "$draft"; then :; else
  echo 'FAIL: experience draft must be gitignored' >&2; exit 1
fi
echo 'PASS: experience draft captures references, refuses overwrite/traversal, excludes raw logs and is ignored'
