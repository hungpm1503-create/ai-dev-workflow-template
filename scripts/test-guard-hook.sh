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
           "$root/.claude/settings.json" "$root/scripts/workflow-memory.sh" "$root/scripts/codex-standard.sh" "$root/claude.md" "$root/.GITHUB/workflows/a.yml" \
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

# Execute the exact registered PreToolUse command in isolated repositories.
pretool_command="$(python3 -c 'import json; d=json.load(open(".claude/settings.json")); print(d["hooks"]["PreToolUse"][0]["hooks"][0]["command"])')"
settings_repo="$tmp/settings-repo"
mkdir -p "$settings_repo/scripts/hooks"
cp "$hook" "$settings_repo/scripts/hooks/"
printf '# Fixture\n- Protected paths: NONE\n' > "$settings_repo/AGENTS.md"
(cd "$settings_repo" && git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -q -m fixture)
run_settings() { (cd "$settings_repo" && CLAUDE_PROJECT_DIR="$settings_repo" bash -c "$pretool_command"); }
json_edit Edit "$settings_repo/AGENTS.md" | run_settings > "$tmp/settings-protected.json"
grep -Fq '"permissionDecision":"ask"' "$tmp/settings-protected.json" || { echo 'FAIL: unchanged guard did not ask for protected edit' >&2; exit 1; }
json_edit Edit "$settings_repo/plain.txt" | run_settings > "$tmp/settings-plain.json"
[[ ! -s "$tmp/settings-plain.json" ]] || { echo 'FAIL: unchanged guard blocked ordinary edit' >&2; exit 1; }
printf '%s\n' '#!/usr/bin/env bash' 'printf x > "$CANARY"' > "$settings_repo/scripts/hooks/guard-protected-paths.sh"
json_edit Edit "$settings_repo/plain.txt" | CANARY="$tmp/settings-canary" run_settings > "$tmp/settings-changed.json"
grep -Fq '"permissionDecision":"ask"' "$tmp/settings-changed.json" || { echo 'FAIL: changed guard was not gated' >&2; exit 1; }
grep -Fq 'guard-protected-paths.sh differs from HEAD; review it before trusting it.' "$tmp/settings-changed.json" || { echo 'FAIL: changed guard review reason missing' >&2; exit 1; }
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp/settings-changed.json" || { echo 'FAIL: changed guard decision is invalid JSON' >&2; exit 1; }
[[ ! -e "$tmp/settings-canary" ]] || { echo 'FAIL: changed guard ran on host' >&2; exit 1; }

# Git comparison errors (e.g., exit 128) must also fail closed, not invoke the hook.
# Commit a canary hook as the fixture baseline so only the injected Git failure
# prevents execution. The Git shim delegates every other Git command unchanged.
(cd "$settings_repo" && git add scripts/hooks/guard-protected-paths.sh && git -c user.name=t -c user.email=t@example.invalid commit -q -m guard-canary)
mkdir -p "$tmp/git-diff-fail"
cat > "$tmp/git-diff-fail/git" <<'GIT_SHIM'
#!/usr/bin/env bash
if [[ " $* " == *" diff --quiet HEAD -- scripts/hooks/guard-protected-paths.sh "* ]]; then
  exit 128
fi
exec "${GIT_REAL:?}" "$@"
GIT_SHIM
chmod +x "$tmp/git-diff-fail/git"
git_real="$(command -v git)"
out="$(json_edit Edit "$settings_repo/plain.txt" | PATH="$tmp/git-diff-fail:$PATH" GIT_REAL="$git_real" CANARY="$tmp/git-error-canary" run_settings)"
grep -Fq '"permissionDecision":"ask"' <<< "$out" || { echo 'FAIL: Git comparison error did not ask' >&2; exit 1; }
grep -Fq 'guard-protected-paths.sh differs from HEAD' <<< "$out" || { echo 'FAIL: Git comparison error omitted warning' >&2; exit 1; }
printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' || { echo 'FAIL: Git-error decision is invalid JSON' >&2; exit 1; }
[[ ! -e "$tmp/git-error-canary" ]] || { echo 'FAIL: Git comparison error executed canary hook' >&2; exit 1; }

# The low-risk entrypoint has an allow rule: its content must match HEAD before use.
mkdir -p "$settings_repo/scripts"
cp "$root/scripts/codex-standard.sh" "$settings_repo/scripts/codex-standard.sh"
(cd "$settings_repo" && git add scripts/codex-standard.sh && git -c user.name=t -c user.email=t"@"example.invalid commit -q -m standard-runner)
json_bash 'bash scripts/codex-standard.sh TASK-SAFE' | run_settings > "$tmp/standard-trusted.json"
[[ ! -s "$tmp/standard-trusted.json" ]] || { echo 'FAIL: intact standard runner wrongly required approval' >&2; exit 1; }
printf '\n# unreviewed edit\n' >> "$settings_repo/scripts/codex-standard.sh"
json_bash 'bash scripts/codex-standard.sh TASK-SAFE' | run_settings > "$tmp/standard-tampered.json"
grep -Fq '"permissionDecision":"ask"' "$tmp/standard-tampered.json" || { echo 'FAIL: changed pre-approved runner executed without review' >&2; exit 1; }
grep -Fq 'codex-standard.sh differs from HEAD' "$tmp/standard-tampered.json" || { echo 'FAIL: missing standard-runner integrity reason' >&2; exit 1; }


no_head_repo="$tmp/no-head-repo"
mkdir -p "$no_head_repo/scripts/hooks"
cp "$hook" "$no_head_repo/scripts/hooks/"
printf '# Fixture\n- Protected paths: NONE\n' > "$no_head_repo/AGENTS.md"
(cd "$no_head_repo" && git init -q)
json_edit Edit "$no_head_repo/AGENTS.md" | (cd "$no_head_repo" && CLAUDE_PROJECT_DIR="$no_head_repo" bash -c "$pretool_command") > "$tmp/settings-no-head.json"
grep -Fq '"permissionDecision":"ask"' "$tmp/settings-no-head.json" || { echo 'FAIL: no-HEAD repository did not run guard' >&2; exit 1; }

non_git_dir="$tmp/non-git-dir"
mkdir -p "$non_git_dir/scripts/hooks"
cp "$hook" "$non_git_dir/scripts/hooks/"
printf '# Fixture\n- Protected paths: NONE\n' > "$non_git_dir/AGENTS.md"
json_edit Edit "$non_git_dir/AGENTS.md" | (cd "$non_git_dir" && CLAUDE_PROJECT_DIR="$non_git_dir" bash -c "$pretool_command") > "$tmp/settings-non-git.json"
grep -Fq '"permissionDecision":"ask"' "$tmp/settings-non-git.json" || { echo 'FAIL: non-Git directory did not run guard' >&2; exit 1; }

echo "PASS: protected-path hook (${parsers[*]}): normalised paths, symlinks, case, content decoys, Bash heuristic, fail-closed"
