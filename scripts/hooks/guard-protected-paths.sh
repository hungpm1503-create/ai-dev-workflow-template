#!/usr/bin/env bash
# Claude Code PreToolUse hook: ask the user before Claude modifies a protected path.
#
# What it is: an intent-confirmation layer for Claude's own tool calls.
# What it is NOT: a sandbox or security boundary. The user can approve the prompt, and
# writes from other processes (scripts, Python, Codex, editors) are not intercepted.
#
# - Edit/Write/MultiEdit/NotebookEdit: the target path is parsed with a real JSON parser,
#   normalised (".", "..", symlinked parents/files, case) and compared with protected paths.
# - Bash: best-effort heuristic. Asks when the command mentions a protected path AND looks
#   like a write (redirection, tee, mv/cp/rm, sed -i, git checkout/restore/apply, ...).
# - If the input cannot be parsed, the hook fails closed with "ask".
#
# Protected paths = workflow defaults + AGENTS.md > Protected paths (literal repo-relative,
# directories end with "/"). Parser: jq, python3 or node (override: HOOK_JSON_PARSER).
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
input="$(cat)"

ask() {
  local reason="${1//\\/\\\\}"; reason="${reason//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

# ---------- JSON field extraction (real parser, fail closed) ----------
parser="${HOOK_JSON_PARSER:-}"
if [[ -z "$parser" ]]; then
  for candidate in jq python3 node; do
    if command -v "$candidate" >/dev/null 2>&1; then parser="$candidate"; break; fi
  done
fi
# Prints the first non-empty value among the given dotted keys; exit 1 on invalid JSON.
field() {
  case "$parser" in
    jq)
      local expr='' k
      for k in "$@"; do expr+="(.${k} // empty | strings), "; done
      printf '%s' "$input" | jq -er "first(${expr%, }) // \"\"" 2>/dev/null \
        || { printf '%s' "$input" | jq -e . >/dev/null 2>&1 || return 1; }
      ;;
    python3)
      printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for key in sys.argv[1:]:
    v = d
    for part in key.split("."):
        v = v.get(part) if isinstance(v, dict) else None
    if isinstance(v, str) and v:
        sys.stdout.write(v); break
' "$@"
      ;;
    node)
      printf '%s' "$input" | node -e '
let s = ""; process.stdin.on("data", c => s += c).on("end", () => {
  let d; try { d = JSON.parse(s); } catch { process.exit(1); }
  for (const key of process.argv.slice(1)) {
    let v = d; for (const p of key.split(".")) v = (v && typeof v === "object") ? v[p] : undefined;
    if (typeof v === "string" && v) { process.stdout.write(v); break; }
  }
});' "$@"
      ;;
    *) return 1 ;;
  esac
}

tool="$(field tool_name)" || ask 'Protected-path hook could not parse the tool input (need jq, python3 or node); confirm this edit manually.'

# ---------- Protected path list ----------
protected_list() {
  printf '%s\n' 'CLAUDE.md' 'AGENTS.md' 'scripts/codex-delegate.sh' 'scripts/codex-standard.sh' 'scripts/workflow-memory.sh' 'scripts/hooks/' '.claude/settings.json' '.claude/skills/' '.github/workflows/'
  if [[ -f "$root/AGENTS.md" ]]; then
    sed -n 's/^[[:space:]]*-[[:space:]]*Protected paths:[[:space:]]*//p' "$root/AGENTS.md" | head -n 1 | tr ',' '\n'
  fi
}
protected=()
while IFS= read -r p; do
  p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "$p" || "$p" == '[NOT CONFIGURED]' ]] && continue
  case "$p" in /*|*'..'*|*'*'*|*'?'*) continue ;; esac
  protected+=("$p")
done < <(protected_list)

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Lexically collapse "." and ".." in an absolute path.
lexical() {
  local IFS=/ part out=()
  read -ra parts <<<"$1"
  for part in ${parts[@]+"${parts[@]}"}; do
    case "$part" in
      ''|.) ;;
      ..) ((${#out[@]})) && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  if ((${#out[@]})); then printf '/%s' "${out[@]}"; else printf '/'; fi   # bash 3.2-safe
}

# Physical path: resolve the longest existing ancestor with cd -P, then follow file symlinks.
physical() {
  local p="$1" d rest hops=0 target
  while :; do
    d="$(dirname "$p")"; rest="$(basename "$p")"
    while [[ ! -d "$d" ]]; do rest="$(basename "$d")/$rest"; d="$(dirname "$d")"; done
    p="$(lexical "$(cd -P "$d" 2>/dev/null && pwd -P)/$rest")"
    if [[ -L "$p" && $hops -lt 8 ]]; then
      target="$(readlink "$p")"; hops=$((hops + 1))
      [[ "$target" == /* ]] || target="$(dirname "$p")/$target"
      p="$target"; continue
    fi
    printf '%s' "$p"; return
  done
}

root_lex="$(lexical "$root")"
root_phys="$(cd -P "$root" 2>/dev/null && pwd -P || printf '%s' "$root_lex")"

# Prints the matching protected entry (relative path) if $1 (repo-relative) is protected.
match_rel() {
  local rel; rel="$(lower "$1")"
  local p lp
  for p in "${protected[@]}"; do
    lp="$(lower "$p")"
    if [[ "$rel" == "$lp" || ( "$lp" == */ && "$rel" == "$lp"* ) || "$rel/" == "$lp" ]]; then
      printf '%s' "$p"; return 0
    fi
  done
  return 1
}

check_path() {
  local raw="$1" abs cand base rel hit
  [[ "$raw" == /* ]] && abs="$raw" || abs="$root/$raw"
  for cand in "$(lexical "$abs")" "$(physical "$abs")"; do
    for base in "$root_lex" "$root_phys"; do
      if [[ "$(lower "$cand")" == "$(lower "$base")/"* ]]; then
        rel="${cand:${#base}+1}"
        if hit="$(match_rel "$rel")"; then
          ask "$rel is a protected path ($hit). Confirm this edit is intended."
        fi
      fi
    done
  done
}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(field tool_input.file_path tool_input.notebook_path)" || ask 'Protected-path hook could not parse the tool input; confirm this edit manually.'
    [[ -n "$path" ]] || exit 0
    check_path "$path"
    ;;
  Bash)
    cmd="$(field tool_input.command)" || ask 'Protected-path hook could not parse the Bash command; confirm it manually.'
    [[ -n "$cmd" ]] || exit 0
    write_re='(^|[^<0-9&>])>{1,2}[^&]|(^|[[:space:];|&(])(tee|mv|cp|rm|truncate|install|ln|dd|chmod|chown)([[:space:]]|$)|sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|perl[[:space:]]+-[a-zA-Z]*i|git[[:space:]]+(checkout|restore|apply|am|reset|stash|rm|mv|clean)'
    if printf '%s' "$cmd" | grep -Eq -- "$write_re"; then
      lcmd="$(lower "$cmd")"
      for p in "${protected[@]}"; do
        needle="$(lower "${p%/}")"
        if [[ "$lcmd" == *"$needle"* ]]; then
          ask "This command may modify protected path $p (best-effort Bash check). Confirm it is intended."
        fi
      done
    fi
    ;;
esac
exit 0
