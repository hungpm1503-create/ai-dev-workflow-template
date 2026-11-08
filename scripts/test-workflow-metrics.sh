#!/usr/bin/env bash
# Offline fixtures only; no model calls or personal transcript access.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
mkdir -p "$project/scripts" "$project/.workflow/handoffs" "$project/.claude"
cp "$root/scripts/workflow-metrics.sh" "$project/scripts/"
cp "$root/.claude/settings.json" "$project/.claude/"
printf 'first\n' > "$project/CLAUDE.md"
printf '.workflow/metrics/\n' > "$project/.gitignore"
(cd "$project" && git init -q)
metrics="$project/.workflow/metrics"
run() { (cd "$project" && bash scripts/workflow-metrics.sh "$@"); }
fail() { echo "FAIL: $*" >&2; exit 1; }

original="$(run fingerprint)"
[[ "$original" =~ ^[0-9a-f]{12}$ ]] || fail 'fingerprint format'
[[ "$(run fingerprint)" == "$original" ]] || fail 'fingerprint changed without file change'
printf 'second\n' > "$project/CLAUDE.md"
[[ "$(run fingerprint)" != "$original" ]] || fail 'fingerprint ignored CLAUDE.md'

# Execute the exact command configured in settings, in the temp project.
transcript="$tmp/transcript.jsonl"
task=TASK-METRICS-ONE
WORKFLOW_METRICS_TRANSCRIPT="$transcript" run start "$task"
hook="$(python3 - "$project/.claude/settings.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['hooks']['PermissionRequest'][0]['hooks'][0]['command'])
PY
)"
hook_output="$(CLAUDE_PROJECT_DIR="$project" WORKFLOW_METRICS=1 bash -c "$hook")"
[[ -z "$hook_output" ]] || fail 'permission hook printed stdout'
[[ "$(wc -l < "$metrics/permission-requests.log" | tr -d ' ')" == 1 ]] || fail 'permission hook line count'
grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$metrics/permission-requests.log" || fail 'permission timestamp'

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
yesterday="$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d yesterday +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "$yesterday" >> "$metrics/permission-requests.log"
python3 - "$transcript" "$now" "$yesterday" <<'PY'
import json,sys
path,now,old=sys.argv[1:]
def event(rid,when,input):
 return {'type':'assistant','requestId':rid,'timestamp':when,'message':{'usage':{'input_tokens':input,'cache_creation_input_tokens':2,'cache_read_input_tokens':3,'output_tokens':4}}}
with open(path,'w') as f:
 for item in [event('old',old,999),event('one',now,10),event('one',now,10),event('two',now,20)]: f.write(json.dumps(item)+'\n')
PY
cat > "$project/.workflow/handoffs/$task.md" <<'HANDOFF'
## Route
- Complexity: MEDIUM; Governance risk: HIGH
- Codex model: gpt-6-sol
- Codex reasoning effort: high
## Objective
Fixture
HANDOFF
parent="$project/.workflow/handoffs/$task-run.abc"
fix="$project/.workflow/handoffs/$task-fix-1-run.def"
mkdir -p "$parent" "$fix"
cat > "$parent/status.txt" <<'STATUS'
CODEX_INPUT_TOKENS=10
CODEX_CACHED_TOKENS=3
CODEX_OUTPUT_TOKENS=5
QUICK_CHECK_EXIT=0
FINAL_EXIT_CODE=0
STATUS
cat > "$fix/status.txt" <<'STATUS'
CODEX_INPUT_TOKENS=20
CODEX_CACHED_TOKENS=4
CODEX_OUTPUT_TOKENS=6
QUICK_CHECK_EXIT=SKIPPED_PROTECTED
FINAL_EXIT_CODE=4
STATUS
run finish "$task" --findings 2
run note "$task" escaped=1
python3 - "$metrics/tasks.tsv" "$task" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1]),delimiter='\t'))
assert len(rows)==1,rows
r=rows[0]
expected={'claude_input_tokens':'30','claude_cache_write_tokens':'4','claude_cache_read_tokens':'6','claude_output_tokens':'8','claude_requests':'2','codex_input_tokens':'30','codex_cached_tokens':'7','codex_output_tokens':'11','codex_runs':'2','fix_rounds':'1','first_quick_check':'0','any_exit_4':'1','permission_prompts':'1','findings':'2','complexity':'MEDIUM','risk':'HIGH','model':'gpt-6-sol','effort':'high','escaped_defects':'1'}
for key,value in expected.items(): assert r[key]==value,(key,r[key],value)
assert int(r['elapsed_seconds'])>=0
PY

# Three more rows in this group: n=4 stays insufficient. A changed fingerprint
# creates the second group, which gets five rows and no warning.
for n in 2 3 4; do
  id="TASK-METRICS-$n"
  run start "$id"
  run finish "$id" --class MEDIUM/HIGH
done
report="$(run report)"
printf '%s\n' "$report" | grep -Fq $'\t4\t' || fail 'four-row group missing'
printf '%s\n' "$report" | grep -Fq 'INSUFFICIENT (n<5)' || fail 'insufficient marker missing'
printf '%s\n' "$report" | grep -Fq 'MIXED MODEL/EFFORT' || fail 'mixed model/effort warning missing'
printf 'third\n' > "$project/CLAUDE.md"
for n in 5 6 7 8 9; do
  id="TASK-METRICS-$n"
  run start "$id"
  run finish "$id" --class MEDIUM/HIGH
done
report="$(run report)"
printf '%s\n' "$report" | grep -Fq $'\t5\t' || fail 'five-row group missing'
[[ "$(printf '%s\n' "$report" | grep -c 'INSUFFICIENT (n<5)')" == 1 ]] || fail 'five-row group marked insufficient'
printf '%s\n' "$report" | grep -Eq $'\t30(\\.0)?\t' || fail 'median token total missing'

# Exercise the Bash 3.2 path when Python is unavailable. jq remains optional.
shim="$tmp/path-without-python"
mkdir -p "$shim"
for tool in bash basename cut date dirname git grep head jq ls mkdir mktemp mv rm sed sort tr wc awk; do
  found="$(command -v "$tool" || :)"
  [[ -z "$found" ]] || ln -s "$found" "$shim/$tool"
done
without_python() { (cd "$project" && PATH="$shim" /bin/bash scripts/workflow-metrics.sh "$@"); }
id=TASK-METRICS-FALLBACK
WORKFLOW_METRICS_TRANSCRIPT="$transcript" without_python start "$id"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$transcript" "$now" <<'PY'
import json,sys
with open(sys.argv[1],'w') as f:
 for rid,value in [('a',10),('a',10),('b',20)]:
  f.write(json.dumps({'type':'assistant','requestId':rid,'timestamp':sys.argv[2],'message':{'usage':{'input_tokens':value,'cache_creation_input_tokens':2,'cache_read_input_tokens':3,'output_tokens':4}}})+'\n')
PY
without_python finish "$id" --class SMALL/LOW
events="$tmp/codex-events.jsonl"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":3,"output_tokens":2}}' '{"type":"turn.completed","usage":{"input_tokens":20,"cached_input_tokens":5,"output_tokens":4}}' > "$events"
[[ "$(without_python codex-usage "$events")" == '30 8 6' ]] || fail 'jq Codex usage fallback'
without_python note "$id" escaped=2
fallback_report="$(without_python report)"
printf '%s\n' "$fallback_report" | grep -Fq 'INSUFFICIENT (n<5)' || fail 'fallback report threshold'
python3 - "$metrics/tasks.tsv" "$id" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1]),delimiter='\t'))
row=next(r for r in rows if r['task_id']==sys.argv[2])
assert row['complexity']=='SMALL' and row['risk']=='LOW' and row['escaped_defects']=='2',row
assert row['claude_input_tokens']=='30' and row['claude_requests']=='2',row
PY
rm "$shim/jq"
[[ "$(without_python codex-usage "$events")" == 'N/A N/A N/A' ]] || fail 'no-parser Codex usage'
id=TASK-METRICS-NOPARSER
WORKFLOW_METRICS_TRANSCRIPT="$transcript" without_python start "$id"
without_python finish "$id" --class SMALL/LOW
python3 - "$metrics/tasks.tsv" "$id" <<'PY'
import csv,sys
row=next(r for r in csv.DictReader(open(sys.argv[1]),delimiter='\t') if r['task_id']==sys.argv[2])
assert row['claude_input_tokens']=='N/A' and row['claude_requests']=='N/A',row
PY
# Hooks run outside the model loop and write only when explicitly enabled.
auto="$tmp/auto-project"
mkdir -p "$auto/scripts/hooks" "$auto/.claude"
cp "$root/scripts/workflow-metrics.sh" "$auto/scripts/"
cp "$root/scripts/hooks/workflow-metrics.sh" "$auto/scripts/hooks/"
cp "$root/.claude/settings.json" "$auto/.claude/"
printf 'fixture\n' > "$auto/CLAUDE.md"
printf '.workflow/metrics/\n' > "$auto/.gitignore"
(cd "$auto" && git init -q)
hooks_json="$auto/.claude/settings.json"
hook_start="$(python3 - "$hooks_json" <<'PYHOOK'
import json,sys
d=json.load(open(sys.argv[1]))
print(next(x["command"] for h in d["hooks"]["UserPromptSubmit"] for x in h["hooks"] if "workflow-metrics.sh" in x["command"]))
PYHOOK
)"
hook_finish="$(python3 - "$hooks_json" <<'PYHOOK'
import json,sys
d=json.load(open(sys.argv[1]))
print(next(x["command"] for h in d["hooks"]["Stop"] for x in h["hooks"] if "workflow-metrics.sh" in x["command"]))
PYHOOK
)"
hook_permission="$(python3 - "$hooks_json" <<'PYHOOK'
import json,sys
print(json.load(open(sys.argv[1]))["hooks"]["PermissionRequest"][0]["hooks"][0]["command"])
PYHOOK
)"
payload='{"session_id":"fixture-session","transcript_path":"'"$transcript"'","hook_event_name":"UserPromptSubmit","prompt":"PRIVATE FIXTURE TEXT"}'
stop_payload='{"session_id":"fixture-session","transcript_path":"'"$transcript"'","hook_event_name":"Stop"}'
printf '%s\n' "$payload" | (CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=0 bash -c "$hook_start")
printf '%s\n' "$stop_payload" | (CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=0 bash -c "$hook_finish")
(CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=0 bash -c "$hook_permission")
[[ ! -e "$auto/.workflow/metrics" ]] || fail 'disabled hooks wrote metrics'
out="$(printf '%s\n' "$payload" | CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=1 bash -c "$hook_start")"
[[ -z "$out" ]] || fail 'metrics start hook leaked output to model context'
(CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=1 bash -c "$hook_permission")
out="$(printf '%s\n' "$stop_payload" | CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=1 bash -c "$hook_finish")"
[[ -z "$out" ]] || fail 'metrics Stop hook leaked output to model context'
tsv="$auto/.workflow/metrics/tasks.tsv"
[[ -f "$tsv" ]] || fail 'metrics hook did not finish'
[[ "$(wc -l < "$tsv" | tr -d ' ')" == 2 ]] || fail 'first hook turn row count'
grep -Eq '^TASK-HOOK-[0-9a-f]{16}-[0-9]+-[0-9]+[[:space:]]' "$tsv" || fail 'generated hook task ID invalid'
[[ "$(wc -l < "$auto/.workflow/metrics/permission-requests.log" | tr -d ' ')" == 1 ]] || fail 'permission count ignored opt-in'
if grep -Rq 'PRIVATE FIXTURE TEXT' "$auto/.workflow/metrics"; then fail 'hook persisted private prompt'; fi
printf '%s\n' "$stop_payload" | (CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=1 bash -c "$hook_finish")
[[ "$(wc -l < "$tsv" | tr -d ' ')" == 2 ]] || fail 'repeated Stop duplicated metric row'
printf '%s\n' "$payload" | (CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=1 bash -c "$hook_start")
printf '%s\n' "$stop_payload" | (CLAUDE_PROJECT_DIR="$auto" WORKFLOW_METRICS=1 bash -c "$hook_finish")
[[ "$(wc -l < "$tsv" | tr -d ' ')" == 3 ]] || fail 'second prompt was not measured separately'

echo 'PASS: opt-in metrics hooks, disabled-by-default, transcript deduplication, run aggregation, permissions and report'

