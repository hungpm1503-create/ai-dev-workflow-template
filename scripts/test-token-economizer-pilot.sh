#!/usr/bin/env bash
# Offline CLI contract test; fake TE only, no AI, network or plugin installation.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export TE_MOCK_LOG="$tmp/commands"
cat > "$tmp/te" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >> "$TE_MOCK_LOG"
MOCK
chmod +x "$tmp/te"
call() { TE_CLI="$tmp/te" bash scripts/token-economizer-pilot.sh "$@" >"$tmp/out"; }
expect() {
  [[ "$(tail -n 1 "$TE_MOCK_LOG")" == "$1" ]] || {
    echo "FAIL: expected: $1" >&2
    tail -n 1 "$TE_MOCK_LOG" >&2
    exit 1
  }
}
call configure
expect '--host claude config set microskills=envfacts toolprune=propose loopguard=off'
grep -Fq 'pruning proposals only' "$tmp/out"
call loopguard-on
expect '--host claude config set loopguard=on'
call loopguard-off
expect '--host claude config set loopguard=off'
TE_HOST=codex call status
expect '--host codex status'
call doctor
expect '--host claude doctor'
call restore-tools
expect '--host claude toolprune restore'
call disable
expect '--host claude config set microskills=off toolprune=off loopguard=off'
before="$(wc -l < "$TE_MOCK_LOG" | tr -d ' ')"
if TE_CLI="$tmp/te" bash scripts/token-economizer-pilot.sh unknown >/dev/null 2>&1; then
  echo 'FAIL: unknown command accepted' >&2; exit 1
fi
if TE_HOST=invalid TE_CLI="$tmp/te" bash scripts/token-economizer-pilot.sh status >/dev/null 2>&1; then
  echo 'FAIL: invalid host accepted' >&2; exit 1
fi
if TE_CLI="$tmp/missing" bash scripts/token-economizer-pilot.sh configure >/dev/null 2>&1; then
  echo 'FAIL: missing plugin accepted' >&2; exit 1
fi
after="$(wc -l < "$TE_MOCK_LOG" | tr -d ' ')"
[[ "$before" == "$after" ]] || { echo 'FAIL: invalid invocation reached launcher' >&2; exit 1; }
grep -Fq 'scripts/hooks/guard-protected-paths.sh' .claude/settings.json
grep -Fq 'scripts/hooks/auto-verify.sh' .claude/settings.json
echo 'PASS: safe profile, separate host, opt-in guard, restore, invalid args, existing safety hooks'
