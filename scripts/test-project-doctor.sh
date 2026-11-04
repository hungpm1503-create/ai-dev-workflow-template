#!/usr/bin/env bash
# Offline test in a disposable Git repo; no application commands or model calls.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/demo"
mkdir -p "$repo/scripts/hooks" "$repo/.claude"
cp "$root/scripts/project-doctor.sh" "$repo/scripts/"
cp "$root/scripts/codex-delegate.sh" "$repo/scripts/"
cp "$root/scripts/codex-standard.sh" "$repo/scripts/"
cp "$root/scripts/hooks/guard-protected-paths.sh" "$repo/scripts/hooks/"
cp "$root/scripts/hooks/auto-verify.sh" "$repo/scripts/hooks/"
cp "$root/.claude/settings.json" "$repo/.claude/"
cd "$repo"
git init -q
config() {
  cat > AGENTS.md <<'EOC'
## Project Configuration
- Stack: Node.js
- Build command: node --version
- Test command: node --test
- Lint / typecheck command: N/A
- Quick check command: node --test
- Protected paths: src/config/, infrastructure/
- Project-specific constraints: N/A
EOC
}
run() { bash scripts/project-doctor.sh > "$tmp/out" 2>&1; }
fail() { printf 'FAIL: %s\n' "$*" >&2; cat "$tmp/out" >&2; exit 1; }
config
run || fail 'valid project rejected'
grep -q 'PROJECT DOCTOR: PASS' "$tmp/out" || fail 'no PASS output'
config
sed -i.bak 's/Quick check command: node --test/Quick check command: [NOT CONFIGURED]/' AGENTS.md
rm -f AGENTS.md.bak
if run; then fail 'missing quick check accepted'; fi
grep -q 'Quick check command is not configured' "$tmp/out" || fail 'missing quick check not reported'
config
sed -i.bak 's|Protected paths: src/config/, infrastructure/|Protected paths: ../outside|' AGENTS.md
rm -f AGENTS.md.bak
if run; then fail 'unsafe protected path accepted'; fi
grep -q 'literal relative paths' "$tmp/out" || fail 'unsafe protected path not reported'
config
sed -i.bak 's/node --test/echo "unterminated/' AGENTS.md
rm -f AGENTS.md.bak
if run; then fail 'invalid command accepted'; fi
grep -q 'invalid Bash syntax' "$tmp/out" || fail 'invalid command not reported'
config
mv .claude/settings.json "$tmp/settings.json"
if run; then fail 'missing settings accepted'; fi
mv "$tmp/settings.json" .claude/settings.json
config
run || fail 'recovery after failures'
echo 'PASS: Project Doctor fixtures; config, command syntax, protected paths, hooks'
