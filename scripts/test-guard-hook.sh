#!/usr/bin/env bash
# Offline tests for the Claude Code PreToolUse protected-path hook. No model/API use.
# Runs every case with each available JSON parser (jq, python3, node).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
hook="$root/scripts/hooks/guard-protected-paths.sh"
fail() { echo "FAIL[$parser]: $*" >&2; exit 1; }
tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp" "$root/.hook-test-link-$$" "$root/.hook-test-filelink-$$.md"; }
trap cleanup EXIT

# Settings must be valid JSON and register the hook for file tools and Bash.
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' .claude/settings.json 2>/dev/null \
  || node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' .claude/settings.json \
  || { echo 'FAIL: settings.json is not valid JSON' >&2; exit 1; }
grep -Fq 'guard-protected-paths.sh' .claude/settings.json || { echo 'FAIL: hook not registered' >&2; exit 1; }
grep -Fq 'NotebookEdit|Bash' .claude/settings.json || { echo 'FAIL: hook matcher must include Bash' >&2; exit 1; }

# Symlink fixtures inside the repo (ignored names are removed on exit).
ln -s "$root/.claude" "$root/.hook-test-link-$$"
ln -s "$root/CLAUDE.md" "$root/.hook-test-filelink-$$.md"

json_edit() { # tool, path  → JSON with the path safely encoded
  python3 -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":{"file_path":sys.argv[2],"old_string":"a","new_string":"b"}}))' "$1" "$2" 2>/dev/null \
    || node -e 'console.log(JSON.stringify({tool_name:process.argv[1],tool_input:{file_path:process.argv[2],old_string:"a",new_string:"b"}}))' "$1" "$2"
}
json_bash() {
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" 2>/dev/null \
    || node -e 'console.log(JSON.stringify({tool_name:"Bash",tool_input:{command:process.argv[1]}}))' "$1"
}
run() { CLAUDE_PROJECT_DIR="$root" HOOK_JSON_PARSER="$parser" bash "$hook"; }
expect_ask()  { local out; out="$(run)"; grep -q '"permissionDecision":"ask"' <<<"$out" || fail "expected ask: $1"; }
expect_none() { local out; out="$(run)"; [[ -z "$out" ]] || fail "expected no decision: $1 -> $out"; }

parsers=()
for p in jq python3 node; do command -v "$p" >/dev/null 2>&1 && parsers+=("$p"); done
((${#parsers[@]})) || { echo 'FAIL: no JSON parser (jq/python3/node) available' >&2; exit 1; }

for parser in "${parsers[@]}"; do
  # --- Protected: direct, relative, normalised, case, symlinks ---
  for p in "$root/CLAUDE.md" 'AGENTS.md' './CLAUDE.md' "$root/src/../CLAUDE.md" 'src/../../'"$(basename "$root")"'/AGENTS.md' \
           "$root/.github/workflows/ci.yml" "$root/.claude/skills/vibe/SKILL.md" "$root/scripts/hooks/x.sh" \
           "$root/.claude/settings.json" "$root/claude.md" "$root/.GITHUB/workflows/a.yml" \
           "$root/.hook-test-link-$$/settings.json" "$root/.hook-test-filelink-$$.md" "$root//CLAUDE.md" "$root/./.claude/skills/"; do
    json_edit Edit "$p" | expect_ask "$p"
  done
  # Notebook edits use notebook_path.
  printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s/.claude/skills/a.ipynb"}}' "$root" | expect_ask notebook_path

  # --- Not protected ---
  for p in "$root/src/app.ts" '/tmp/elsewhere.txt' "$root/README.md" "$root/.github/workflows-old/a.yml" "$root/docs/CLAUDE.md.bak"; do
    json_edit Write "$p" | expect_none "$p"
  done
  # A protected-looking string inside content must not be mistaken for the target path.
  printf '{"tool_name":"Write","tool_input":{"content":"{\\"file_path\\":\\"CLAUDE.md\\"}","file_path":"%s/src/a.md"}}' "$root" | expect_none 'file_path inside content'
  # Escaped quotes in the real path are parsed correctly (path is not protected).
  json_edit Write "$root/src/we\"ird.md" | expect_none 'escaped quote path'

  # --- Bash best-effort heuristic ---
  for c in 'echo hi > CLAUDE.md' "sed -i 's/a/b/' AGENTS.md" 'cat x | tee .claude/settings.json' 'rm -rf .claude/skills' \
           'mv a .github/workflows/ci.yml' 'git checkout -- CLAUDE.md' 'printf x >> scripts/hooks/guard-protected-paths.sh'; do
    json_bash "$c" | expect_ask "bash: $c"
  done
  for c in 'cat CLAUDE.md' 'grep -n VIBE CLAUDE.md' 'bash scripts/test-guard-hook.sh 2>&1' 'echo hi > src/a.txt' 'git diff CLAUDE.md'; do
    json_bash "$c" | expect_none "bash: $c"
  done

  # --- Fail closed on unparseable input ---
  printf 'not json' | expect_ask 'malformed input'
done

# No parser at all → fail closed.
parser=none
json_edit Write "$root/src/a.ts" | expect_ask 'no parser available'

echo "PASS: protected-path hook (${parsers[*]}): normalised paths, symlinks, case, content decoys, Bash heuristic, fail-closed"
