#!/usr/bin/env bash
# Validate a configured project without running application commands or models.
set -euo pipefail
root="$(cd -P "$(dirname "$0")/.." && pwd -P)"
cd "$root"
failures=0
warnings=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures+1)); }
warn() { printf 'WARN: %s\n' "$*"; warnings=$((warnings+1)); }
pass() { printf 'PASS: %s\n' "$*"; }
if [[ ! -f AGENTS.md ]]; then echo 'FAIL: AGENTS.md missing' >&2; exit 1; fi
[[ "$(git rev-parse --show-toplevel 2>/dev/null || :)" == "$root" ]] || fail 'Not the root of a Git worktree.'
field() {
  local name="$1"
  awk -v name="$name" '
    index($0, "- " name ":") == 1 || $0 ~ /^[[:space:]]+- / {
      line=$0; sub(/^[[:space:]]*/, "", line)
      prefix="- " name ":"
      if (index(line, prefix) == 1) {
        count++
        value=substr(line, length(prefix)+1)
        sub(/^[[:space:]]*/, "", value)
      }
    }
    END { if (count != 1) exit 1; print value }
  ' AGENTS.md
}
trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
check_field() {
  local name="$1" kind="$2" raw value p invalid=0
  if ! raw="$(field "$name")"; then fail "Expected exactly one $name field."; return; fi
  value="$(trim "$raw")"
  if [[ -z "$value" || "$value" == '[NOT CONFIGURED]' ]]; then fail "$name is not configured."; return; fi
  if [[ "$kind" == command ]]; then
    if [[ "$value" == N/A || "$value" == NONE ]]; then
      if [[ "$name" == 'Quick check command' ]]; then fail 'Quick check command must not be N/A.'; else pass "$name marked N/A."; fi
      return
    fi
    if bash -n -c "$value" >/dev/null 2>&1; then pass "$name syntax valid (not executed)."; else fail "$name contains invalid Bash syntax."; fi
  elif [[ "$kind" == paths ]]; then
    if [[ "$value" == NONE ]]; then pass 'No extra protected paths (workflow defaults remain).'; return; fi
    local IFS=,
    read -ra paths <<< "$value"
    for p in "${paths[@]}"; do
      p="$(trim "$p")"
      case "$p" in ''|/*|*..*|*'*'*|*'?'*|*'\'*|.|./*) invalid=1;; esac
    done
    if (( invalid )); then fail 'Protected paths must be literal relative paths (directories end with /) or NONE.'; else pass 'Protected paths valid.'; fi
  else
    pass "$name configured."
  fi
}
check_field 'Stack' text
check_field 'Build command' command
check_field 'Test command' command
check_field 'Lint / typecheck command' command
check_field 'Quick check command' command
check_field 'Protected paths' paths
if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1 && ! command -v node >/dev/null 2>&1; then
  warn 'No jq, python3 or node found: protected-path hook will ask on every tool edit.'
fi
if [[ -f .claude/settings.json ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json;json.load(open(".claude/settings.json"))' >/dev/null 2>&1 || fail 'Invalid JSON in .claude/settings.json.'
  elif command -v node >/dev/null 2>&1; then
    node -e 'JSON.parse(require("fs").readFileSync(".claude/settings.json","utf8"))' >/dev/null 2>&1 || fail 'Invalid JSON in .claude/settings.json.'
  else
    warn 'No python3/node: cannot validate settings.json JSON.'
  fi
  for hook in PreToolUse Stop UserPromptSubmit; do
    grep -Fq "\"$hook\"" .claude/settings.json || fail "Missing $hook hook."
  done
  for script in guard-protected-paths.sh auto-verify.sh --mark-turn-start; do
    grep -Fq -- "$script" .claude/settings.json || fail "Missing $script hook registration."
  done
else
  fail '.claude/settings.json missing.'
fi
for path in scripts/hooks/guard-protected-paths.sh scripts/hooks/auto-verify.sh scripts/codex-delegate.sh; do
  [[ -f "$path" ]] || fail "Required workflow script missing: $path"
done
command -v claude >/dev/null 2>&1 || warn 'Claude CLI missing: live behavior UNVERIFIED.'
command -v codex >/dev/null 2>&1 || warn 'Codex CLI missing: delegation unavailable until installed.'
if (( failures )); then
  printf 'PROJECT DOCTOR: FAIL (%s errors, %s warnings); project commands NOT executed.\n' "$failures" "$warnings" >&2
  exit 1
fi
printf 'PROJECT DOCTOR: PASS (%s warnings); command syntax only, live tests still needed.\n' "$warnings"
