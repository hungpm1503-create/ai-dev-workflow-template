#!/usr/bin/env bash
# Low-risk, low-traceability delegation entrypoint intended for a narrow Claude Code allow rule.
# Does NOT approve a HIGH-risk task or bypass the normal Codex wrapper.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"
if [[ $# -ne 1 || ! "$1" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$ || ${#1} -gt 72 ]]; then
  echo 'Usage: bash scripts/codex-standard.sh TASK-ID' >&2; exit 2
fi
id="$1"
handoff=".workflow/handoffs/$id.md"
if [[ ! -f "$handoff" || -L "$handoff" || -L ".workflow/handoffs" ]]; then
  echo 'ERROR: standard handoff is missing or symlinked.' >&2; exit 2
fi
route="$(awk '/^## Route[[:space:]]*$/ {on=1; next} on && /^## / {exit} on {print}' "$handoff")"
if ! printf '%s\n' "$route" | grep -Eiq '(^|[;[:space:]])(Governance risk|risk):[[:space:]]*LOW([;[:space:]]|$)' ||
   ! printf '%s\n' "$route" | grep -Eiq '(^|[;[:space:]])Traceability:[[:space:]]*LOW([;[:space:]]|$)' ||
   printf '%s\n' "$route" | grep -Eiq '(HIGH|FULL GOVERNANCE)' ; then
  echo 'ERROR: standard auto-delegation requires explicit LOW risk and LOW traceability; HIGH-risk must use the normal approved Codex path.' >&2
  exit 3
fi
# Neither network access nor a test-skip override can be smuggled into the
# pre-approved low-risk runner through the environment.
export CODEX_NETWORK=0 CODEX_QUICK_CHECK=1
exec bash "$root/scripts/codex-delegate.sh" "$id"
