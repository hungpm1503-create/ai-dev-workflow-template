#!/usr/bin/env bash
# Build a private, reviewable experience draft from an existing Codex run.
# Never calls a model, copies raw logs, or updates permanent instructions.
set -euo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

usage() {
  echo 'Usage: bash scripts/capture-experience.sh TASK-ID TASK-ID-run.XXXXXX' >&2
}
if [[ $# -ne 2 ]]; then usage; exit 2; fi
task_id="$1"
run_name="$2"
if [[ ! "$task_id" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || (( ${#task_id} > 72 )); then
  echo 'ERROR: invalid task ID.' >&2; exit 2
fi
if [[ ! "$run_name" =~ ^${task_id}-run\.[A-Za-z0-9]{6}$ ]]; then
  echo 'ERROR: run folder must be the exact basename TASK-ID-run.XXXXXX.' >&2; exit 2
fi
if [[ "$(git rev-parse --show-toplevel 2>/dev/null || :)" != "$root" ]]; then
  echo 'ERROR: run at the root of this Git repository.' >&2; exit 2
fi

handoffs="$root/.claude/handoffs"
run_dir="$handoffs/$run_name"
if [[ -L "$handoffs" || -L "$run_dir" || ! -d "$run_dir" ]]; then
  echo 'ERROR: run folder is missing or symlinked.' >&2; exit 2
fi
# Never read arbitrary paths outside the verified run directory.
read_metadata() {
  local path="$run_dir/$1"
  if [[ ! -f "$path" || -L "$path" ]]; then return 1; fi
  cat "$path"
}
head_sha="$(read_metadata head-before.txt 2>/dev/null || :)"
if [[ ! "$head_sha" =~ ^[[:xdigit:]]{40}$ && ! "$head_sha" =~ ^[[:xdigit:]]{64}$ ]]; then
  head_sha="UNVERIFIED"
fi
code="$(read_metadata status.txt 2>/dev/null | sed -n 's/^FINAL_EXIT_CODE=\([0-9][0-9]*\)$/\1/p' | head -n 1 || :)"
if [[ -z "$code" ]]; then code="UNVERIFIED"; fi
if [[ -f "$run_dir/changed-paths.txt" && ! -L "$run_dir/changed-paths.txt" ]]; then
  changed_count="$(awk 'END {print NR+0}' "$run_dir/changed-paths.txt")"
else
  changed_count="UNVERIFIED"
fi

drafts="$root/.claude/experience-drafts"
if [[ -L "$drafts" ]]; then echo 'ERROR: draft folder is symlinked.' >&2; exit 2; fi
mkdir -p "$drafts"
draft="$drafts/EXP-$run_name.md"
if [[ -e "$draft" || -L "$draft" ]]; then
  echo 'ERROR: draft already exists; will not overwrite user edits.' >&2; exit 4
fi

# Reserve the destination without overwriting existing data.
set -C
{
  printf '# Experience Draft — %s\n\n' "$task_id"
  printf 'Status: DRAFT (not validated or approved for promotion)\n'
  printf 'Date (UTC): %s\n' "$(date -u +%Y-%m-%d)"
  printf 'Task: %s\n' "$task_id"
  printf 'Run: .claude/handoffs/%s/\n' "$run_name"
  printf 'Baseline HEAD: %s\n' "$head_sha"
  printf 'Wrapper final exit code: %s\n' "$code"
  printf 'Changed paths reported: %s\n\n' "$changed_count"
  cat <<'EOF'
## Cue / when to reuse
[Describe the observable situation that would make this lesson relevant.]

## Observation and hypothesis
- Observed failure or rework: [evidence-backed statement]
- Root-cause category: [requirements / planning / implementation / verification / environment / external / unknown]
- Hypothesis (not yet confirmed): [causal explanation or N/A]

## Evidence before improvement
- Local, ignored evidence: see run folder above (status.txt, changed-paths.txt, completion.md, codex.log, status-before.txt)
- Reproducible command/test and result: [command, actual exit code, concise redacted output]
- Relevant issue, CI run, or commit URL: [reference or N/A]
- Note: a wrapper exit code of 0 does NOT prove task acceptance.

## Candidate workflow change
- Target instruction/skill/handoff path: [repo-relative path]
- Before behavior: [what failed or caused avoidable rework]
- Proposed behavior: [small specific change]
- Proposed Git commit or PR (immutable reference if available): [SHA/link or PENDING]

## Validation after improvement
- Comparable task / regression test: [exact command and scenario]
- Before result: [measured failure or UNVERIFIED]
- After result: [measured result or UNVERIFIED]
- Tradeoffs: [tokens, time, false positives, maintainability; N/A if unmeasured]
- Remaining limitations: [unverified claims and risks]

## Decision and lifecycle
- Current state: DRAFT
- Promotion decision: PENDING HUMAN APPROVAL
- When to reconsider / retire: [condition]
- Safe reusable summary: [a few lines with redacted, durable evidence]

## Privacy check before sharing or committing
- [ ] No API keys, personal information, raw model prompts or private logs
- [ ] Evidence is concise and independently checkable
- [ ] Root-cause hypotheses are identified as hypotheses
- [ ] Instruction change has explicit approval and relevant validation
EOF
} > "$draft"
printf 'Created ignored experience draft: %s\n' "${draft#"$root/"}"
echo 'Review/redact evidence before proposing a persistent project lesson; no permanent files changed.'
