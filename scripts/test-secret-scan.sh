#!/usr/bin/env bash
# Non-destructive test of the common-token scan, including an untracked src file.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mkdir -p src
probe="src/.secret-scan-probe-$$.sh"
tmp="$(mktemp)"
cleanup() { rm -f "$probe" "$tmp"; rmdir src 2>/dev/null || :; }
trap cleanup EXIT

for prefix in 'sk-ant-api03-' 'sk-proj-' 'github_pat_' 'ghp_' 'sk-'; do
  printf 'TEST_TOKEN="%s%s"\n' "$prefix" "$(printf '%040d' 0)" > "$probe"
  if bash scripts/validate-workflow.sh > "$tmp" 2>&1; then
    echo "FAIL: scanner missed $prefix" >&2; exit 1
  fi
  if ! grep -F -q "FAIL: possible plaintext secret in $probe" "$tmp"; then
    echo "FAIL: scanner did not identify the untracked file for $prefix" >&2; exit 1
  fi
done
rm -f "$probe"
if ! bash scripts/validate-workflow.sh > "$tmp" 2>&1; then
  echo 'FAIL: validator unexpectedly failed without injected token:' >&2
  cat "$tmp" >&2
  exit 1
fi
echo 'PASS: five common token formats detected in untracked src file; clean baseline passes'
