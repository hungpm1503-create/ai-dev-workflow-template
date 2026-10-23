#!/usr/bin/env bash
# Local/CI tests: fake codex executable, NEVER call a real model.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
tmp="$(mktemp -d)"
id="TASK-SMOKE-$$"
handoffs="$root/.claude/handoffs"
handoff="$handoffs/$id.md"
mkdir -p "$handoffs"
cleanup() {
  rm -f "$handoff"
  # Only remove directories generated for this uniquely named smoke-test task.
  find "$handoffs" -maxdepth 1 -type d -name "$id-run.*" -exec rm -rf {} +
  rm -rf "$tmp"
}
trap cleanup EXIT

printf '## Objective\nSimulated no-op task\n\n## Acceptance criteria\nAC-01: No real CLI called\n' > "$handoff"

cat > "$tmp/codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "exec" ]] || exit 41
shift
out=""
sandbox=""
stdin_flag=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sandbox) sandbox="$2"; shift 2;;
    --output-last-message) out="$2"; shift 2;;
    -) stdin_flag="-"; shift;;
    *) echo "Unexpected argument: $1" >&2; exit 42;;
  esac
done
[[ "$sandbox" == "workspace-write" && "$stdin_flag" == "-" && -n "$out" ]] || exit 43
cat > "${FAKE_PROMPT_FILE:?}"
printf 'AC-01: PASS (simulated; not a real Codex result)\n' > "$out"
exit "${FAKE_CODEX_EXIT:-0}"
FAKE
chmod +x "$tmp/codex"

if ! bash scripts/codex-delegate.sh --dry-run "$id" > "$tmp/dry.txt"; then
  echo "FAIL: dry-run" >&2; exit 1
fi
if [[ -e "$tmp/prompt.txt" ]]; then
  echo "FAIL: dry-run invoked Codex" >&2; exit 1
fi
if bash scripts/codex-delegate.sh "../escape" > /dev/null 2>&1; then
  echo "FAIL: path traversal was accepted" >&2; exit 1
fi
PATH="$tmp:$PATH" FAKE_PROMPT_FILE="$tmp/prompt.txt" \
  bash scripts/codex-delegate.sh "$id" > "$tmp/success.txt"
grep -q -- 'BEGIN APPROVED HANDOFF' "$tmp/prompt.txt"
grep -q 'Codex exit code: 0' "$tmp/success.txt"
grep -q 'AC-01: PASS' "$handoffs"/"$id"-run.*/completion.md
if PATH="$tmp:$PATH" FAKE_PROMPT_FILE="$tmp/prompt.txt" FAKE_CODEX_EXIT=9 \
  bash scripts/codex-delegate.sh "$id" > "$tmp/failure.txt" 2>&1; then
  echo "FAIL: nonzero Codex exit code not propagated" >&2; exit 1
else
  code=$?
  [[ "$code" == "9" ]] || { echo "FAIL: unexpected failure exit code $code" >&2; exit 1; }
fi
grep -q 'Codex exit code: 9' "$tmp/failure.txt"
echo "PASS: delegation dry-run, invocation, sandbox flags, report capture, failure propagation, and path safety (fake Codex only)"
