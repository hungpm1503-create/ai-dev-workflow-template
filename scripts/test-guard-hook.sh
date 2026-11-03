#!/usr/bin/env bash
# Offline test for the Claude Code PreToolUse protected-path hook. No model/API use.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
hook="scripts/hooks/guard-protected-paths.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
run() { CLAUDE_PROJECT_DIR="$root" bash "$hook"; }

# Settings must be valid JSON and register the hook.
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' .claude/settings.json || fail 'settings.json is not valid JSON'
fi
grep -Fq 'guard-protected-paths.sh' .claude/settings.json || fail 'hook not registered in settings.json'

# Protected defaults (absolute and relative paths) → ask.
for p in "$root/CLAUDE.md" 'AGENTS.md' "$root/.github/workflows/ci.yml" "$root/.claude/skills/vibe/SKILL.md" "$root/scripts/hooks/x.sh"; do
  out="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"}}' "$p" | run)"
  grep -q '"permissionDecision":"ask"' <<<"$out" || fail "protected path not guarded: $p"
done

# Notebook edits are guarded too.
out="$(printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s/.claude/skills/a.ipynb"}}' "$root" | run)"
grep -q '"ask"' <<<"$out" || fail 'notebook_path not guarded'

# Ordinary source file and outside-project file → no decision (normal permissions apply).
for p in "$root/src/app.ts" '/tmp/elsewhere.txt' "$root/README.md"; do
  out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$p" | run)"
  [[ -z "$out" ]] || fail "unprotected path was guarded: $p"
done

# Prefix match must respect directory boundaries (".github/workflows-old" is not ".github/workflows/").
out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.github/workflows-old/a.yml"}}' "$root" | run)"
[[ -z "$out" ]] || fail 'directory prefix matched a sibling directory'

# Malformed / unrelated input never blocks.
out="$(printf 'not json' | run)"; [[ -z "$out" ]] || fail 'malformed input produced a decision'

echo 'PASS: protected-path hook asks for protected files, ignores others, handles malformed input'
