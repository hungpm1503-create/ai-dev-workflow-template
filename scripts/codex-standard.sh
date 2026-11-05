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
   printf '%s\n' "$route" | grep -Eiq '(^|[;[:space:]])(Governance risk|risk|Traceability):[[:space:]]*HIGH([;[:space:]]|$)|Governance:[[:space:]]*FULL[[:space:]]+GOVERNANCE' ; then
  echo 'ERROR: standard auto-delegation requires explicit LOW risk and LOW traceability; HIGH-risk must use the normal approved Codex path.' >&2
  exit 3
fi
# Auto-approved execution must use the exact committed versions of both runners.
git rev-parse --verify HEAD >/dev/null 2>&1 || {
  echo 'ERROR: cannot verify HEAD before auto-delegation.' >&2; exit 3;
}
for script in scripts/codex-standard.sh scripts/codex-delegate.sh; do
  if ! git ls-files --error-unmatch -- "$script" >/dev/null 2>&1 ||
     ! git diff --quiet HEAD -- "$script"; then
    echo "ERROR: $script differs from HEAD or cannot be verified; review before execution." >&2
    exit 3
  fi
done
# A missing quick-check command would make automatic verification ineffective.
[[ -f AGENTS.md && ! -L AGENTS.md ]] || {
  echo 'ERROR: AGENTS.md missing or symlinked; no trusted Quick check.' >&2; exit 3;
}
quick_check="$(sed -n 's/^[[:space:]]*-[[:space:]]*Quick check command:[[:space:]]*//p' AGENTS.md | head -n 1)"
quick_check="$(printf '%s' "$quick_check" | sed 's/[[:space:]]*$//')"
case "$quick_check" in
  ''|'[NOT CONFIGURED]'|N/A|NONE)
    echo 'ERROR: configure AGENTS.md Quick check command before auto-delegation.' >&2
    exit 3 ;;
esac
# The codex-delegate skill selects model and effort; this runner only reads,
# validates and forwards its explicit handoff fields (no model routing here).
model="$(printf '%s\n' "$route" | sed -n 's/^[[:space:]]*-[[:space:]]*Codex model:[[:space:]]*//p')"
effort="$(printf '%s\n' "$route" | sed -n 's/^[[:space:]]*-[[:space:]]*Codex reasoning effort:[[:space:]]*//p')"
if [[ ! "$model" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ || ${#model} -gt 100 ]]; then
  echo 'ERROR: LOW-risk handoff requires exactly one valid Codex model in ## Route.' >&2; exit 3
fi
case "$effort" in
  minimal|low|medium|high|xhigh) ;;
  *) echo 'ERROR: LOW-risk handoff requires exactly one valid Codex reasoning effort in ## Route.' >&2; exit 3 ;;
esac
# Neither network access nor a test-skip override can be smuggled into the
# pre-approved low-risk runner through the environment.
export CODEX_NETWORK=0 CODEX_QUICK_CHECK=1 AUTO_VERIFY_DISABLE=0
export CODEX_MODEL="$model" CODEX_REASONING_EFFORT="$effort"
exec bash "$root/scripts/codex-delegate.sh" "$id"
