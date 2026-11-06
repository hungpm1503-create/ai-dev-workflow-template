#!/usr/bin/env bash
# Local task measurements. No prompts, code, or message bodies are stored here.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
metrics="$root/.workflow/metrics"

fingerprint() {
  local path
  {
    printf '%s\n' CLAUDE.md AGENTS.md .claude/settings.json scripts/codex-delegate.sh scripts/codex-standard.sh docs/workflow/codex-rules.md docs/workflow/task-routing.md scripts/workflow-metrics.sh
    for path in .claude/skills/*/SKILL.md scripts/hooks/*.sh; do
      if [[ -f "$path" ]]; then printf '%s\n' "$path"; fi
    done
  } | LC_ALL=C sort -u | while IFS= read -r path; do
    if [[ -f "$path" && ! -L "$path" ]]; then
      printf '%s\t%s\n' "$path" "$(git hash-object --no-filters "$path")"
    fi
  done | git hash-object --stdin | cut -c 1-12
}

codex_usage() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import json, sys
totals = [0, 0, 0]
count = 0
try:
    with open(sys.argv[1], encoding='utf-8') as stream:
        for line in stream:
            try: event = json.loads(line)
            except ValueError: continue
            if event.get('type') != 'turn.completed': continue
            usage = event.get('usage') or {}
            if not all(isinstance(usage.get(k), (int, float)) for k in ('input_tokens', 'output_tokens')): continue
            for i, key in enumerate(('input_tokens', 'cached_input_tokens', 'output_tokens')):
                value = usage.get(key, 0)
                totals[i] += value if isinstance(value, (int, float)) else 0
            count += 1
except OSError: pass
print(' '.join(map(lambda x: str(int(x)), totals)) if count else 'N/A N/A N/A')
PY
  elif command -v jq >/dev/null 2>&1; then
    jq -rs '[.[] | select(.type == "turn.completed" and (.usage.input_tokens | type) == "number" and (.usage.output_tokens | type) == "number") | .usage] | if length == 0 then "N/A N/A N/A" else [(map(.input_tokens) | add), (map(.cached_input_tokens // 0) | add), (map(.output_tokens) | add)] | join(" ") end' "$1" 2>/dev/null || printf 'N/A N/A N/A\n'
  else
    printf 'N/A N/A N/A\n'
  fi
}

usage() { echo 'Usage: workflow-metrics.sh start|finish|note TASK-ID [options], report, or fingerprint' >&2; exit 2; }
status_value() { sed -n "s/^$2=//p" "$1/status.txt" | head -n 1; }
finish_without_python() {
  local state start stamp transcript end end_stamp fp cvals prompts parent first all_runs=() run key value code_totals=(0 0 0) valid=1
  local quick='N/A' exit_four=0 fix_count=0 complexity='N/A' risk='N/A' model='N/A' effort='N/A' handoff route old_escaped row tmp
  state="$metrics/$task_id.start"
  start="$(sed -n '1p' "$state")"; fp="$(sed -n '2p' "$state")"
  transcript="$(sed -n '3p' "$state")"; stamp="$(sed -n '4p' "$state")"
  end="$(date +%s)"; end_stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cvals='N/A N/A N/A N/A N/A'
  if [[ -n "$transcript" && -f "$transcript" ]] && command -v jq >/dev/null 2>&1; then
    cvals="$(jq -sr --arg start "$stamp" --arg end "$end_stamp" '
      [.[] | select(.type == "assistant" and (.requestId | type) == "string" and .timestamp >= $start and .timestamp <= $end and (.message.usage | type) == "object")]
      | unique_by(.requestId) | if length == 0 then "N/A N/A N/A N/A N/A"
        else [(map(.message.usage.input_tokens // 0) | add), (map(.message.usage.cache_creation_input_tokens // 0) | add),
              (map(.message.usage.cache_read_input_tokens // 0) | add), (map(.message.usage.output_tokens // 0) | add), length] | join(" ") end
    ' "$transcript" 2>/dev/null || printf 'N/A N/A N/A N/A N/A')"
  fi
  prompts=0
  if [[ -f "$metrics/permission-requests.log" ]]; then
    prompts="$(awk -v start="$stamp" -v end="$end_stamp" '$0 >= start && $0 <= end { n++ } END { print n+0 }' "$metrics/permission-requests.log")"
  fi
  for run in "$root/.workflow/handoffs/$task_id"-run.* "$root/.workflow/handoffs/$task_id"-fix-*-run.*; do
    [[ -f "$run/status.txt" ]] || continue
    all_runs+=("$run")
    case "$(basename "$run")" in "$task_id"-fix-*-run.*) fix_count=$((fix_count+1));; esac
    [[ "$(status_value "$run" FINAL_EXIT_CODE)" == 4 ]] && exit_four=1
    for key in CODEX_INPUT_TOKENS CODEX_CACHED_TOKENS CODEX_OUTPUT_TOKENS; do
      value="$(status_value "$run" "$key")"
      if [[ ! "$value" =~ ^[0-9]+$ ]]; then valid=0; fi
    done
    if (( valid )); then
      code_totals[0]=$((code_totals[0]+$(status_value "$run" CODEX_INPUT_TOKENS)))
      code_totals[1]=$((code_totals[1]+$(status_value "$run" CODEX_CACHED_TOKENS)))
      code_totals[2]=$((code_totals[2]+$(status_value "$run" CODEX_OUTPUT_TOKENS)))
    fi
  done
  first="$(ls -trd "$root/.workflow/handoffs/$task_id"-run.* 2>/dev/null | head -n 1 || :)"
  if [[ -n "$first" && -f "$first/status.txt" ]]; then
    quick="$(status_value "$first" QUICK_CHECK_EXIT)"
    model="$(status_value "$first" MODEL)"; effort="$(status_value "$first" EFFORT)"
  fi
  [[ -n "$model" ]] || model='N/A'; [[ -n "$effort" ]] || effort='N/A'
  if (( ${#all_runs[@]} == 0 || ! valid )); then code_totals=('N/A' 'N/A' 'N/A'); fi
  handoff="$root/.workflow/handoffs/$task_id.md"
  [[ -f "$handoff" ]] || handoff="$root/.claude/handoffs/$task_id.md"
  if [[ -f "$handoff" ]]; then
    route="$(awk '/^## Route[[:space:]]*$/ { inside=1; next } inside && /^## / { exit } inside { print }' "$handoff")"
    value="$(printf '%s\n' "$route" | sed -nE 's/.*Complexity:[[:space:]]*([^;[:space:]]+).*/\1/p' | head -n 1)"; [[ -z "$value" ]] || complexity="$value"
    value="$(printf '%s\n' "$route" | sed -nE 's/.*Governance risk:[[:space:]]*([^;[:space:]]+).*/\1/p' | head -n 1)"; [[ -z "$value" ]] || risk="$value"
    value="$(printf '%s\n' "$route" | sed -nE 's/.*Codex model:[[:space:]]*([^;[:space:]]+).*/\1/p' | head -n 1)"; [[ -z "$value" ]] || model="$value"
    value="$(printf '%s\n' "$route" | sed -nE 's/.*Codex reasoning effort:[[:space:]]*([^;[:space:]]+).*/\1/p' | head -n 1)"; [[ -z "$value" ]] || effort="$value"
  fi
  if [[ "$class" != N/A ]]; then
    [[ "$complexity" != N/A ]] || complexity="${class%/*}"
    [[ "$risk" != N/A ]] || risk="${class#*/}"
  fi
  old_escaped=0
  if [[ -f "$metrics/tasks.tsv" ]]; then
    value="$(awk -F '\t' -v id="$task_id" '$1==id { print $22; exit }' "$metrics/tasks.tsv")"
    [[ -z "$value" ]] || old_escaped="$value"
  fi
  read -r ci cw cr co cq <<< "$cvals"
  row="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$task_id" "${ci:-N/A}" "${cw:-N/A}" "${cr:-N/A}" "${co:-N/A}" "${cq:-N/A}" "${code_totals[0]}" "${code_totals[1]}" "${code_totals[2]}" \
    "${#all_runs[@]}" "$fix_count" "$quick" "$exit_four" "$((end-start))" "$prompts" "$findings" "$complexity" "$risk" "$model" "$effort" "$fp" "$old_escaped")"
  tmp="$metrics/tasks.tsv.tmp"
  if [[ -f "$metrics/tasks.tsv" ]]; then
    awk -F '\t' -v id="$task_id" 'NR==1 || $1!=id' "$metrics/tasks.tsv" > "$tmp"
  else
    printf '%b\n' 'task_id\tclaude_input_tokens\tclaude_cache_write_tokens\tclaude_cache_read_tokens\tclaude_output_tokens\tclaude_requests\tcodex_input_tokens\tcodex_cached_tokens\tcodex_output_tokens\tcodex_runs\tfix_rounds\tfirst_quick_check\tany_exit_4\telapsed_seconds\tpermission_prompts\tfindings\tcomplexity\trisk\tmodel\teffort\tfingerprint\tescaped_defects' > "$tmp"
  fi
  printf '%s\n' "$row" >> "$tmp"; mv "$tmp" "$metrics/tasks.tsv"
}
fallback_median() {
  awk -F '\t' -v col="$2" '$col ~ /^[0-9]+$/ { print $col }' "$1" | LC_ALL=C sort -n | awk '
    { values[NR]=$1 } END { if (!NR) print "N/A"; else if (NR%2) print values[(NR+1)/2]; else print (values[NR/2]+values[NR/2+1])/2 }
  '
}
report_without_python() {
  local fp complexity risk group_file n field first fixes escaped marker profiles
  printf '%b\n' 'fingerprint\tcomplexity\trisk\tn\tclaude_input\tclaude_cache_write\tclaude_cache_read\tclaude_output\tcodex_input\tcodex_cached\tcodex_output\telapsed\tprompts\tfirst_pass_rate\tmean_fix_rounds\tescaped_total\tstatus'
  [[ -f "$metrics/tasks.tsv" ]] || return 0
  while IFS=$'\t' read -r fp complexity risk; do
    group_file="$(mktemp "$metrics/report.XXXXXX")"
    awk -F '\t' -v f="$fp" -v c="$complexity" -v r="$risk" 'NR>1 && $21==f && $17==c && $18==r' "$metrics/tasks.tsv" > "$group_file"
    n="$(wc -l < "$group_file" | tr -d ' ')"
    printf '%s\t%s\t%s\t%s' "$fp" "$complexity" "$risk" "$n"
    for field in 2 3 4 5 7 8 9 14 15; do printf '\t%s' "$(fallback_median "$group_file" "$field")"; done
    first="$(awk -F '\t' '$12==0 { n++ } END { print n+0 }' "$group_file")"
    fixes="$(awk -F '\t' '{ n+=$11 } END { printf "%.2f", n/NR }' "$group_file")"
    escaped="$(awk -F '\t' '{ n+=$22 } END { print n+0 }' "$group_file")"
    marker=SUFFICIENT; if (( n < 5 )); then marker='INSUFFICIENT (n<5)'; fi
    profiles="$(awk -F '\t' '{ print $19 "\t" $20 }' "$group_file" | LC_ALL=C sort -u | wc -l | tr -d ' ')"
    if (( profiles > 1 )); then marker="$marker; MIXED MODEL/EFFORT"; fi
    printf '\t%s/%s\t%s\t%s\t%s\n' "$first" "$n" "$fixes" "$escaped" "$marker"
    rm -f "$group_file"
  done < <(awk -F '\t' 'NR>1 { print $21 "\t" $17 "\t" $18 }' "$metrics/tasks.tsv" | LC_ALL=C sort -u)
}
[[ $# -gt 0 ]] || usage
command="$1"; shift
case "$command" in
  fingerprint) [[ $# == 0 ]] || usage; fingerprint; exit ;;
  codex-usage) [[ $# == 1 ]] || usage; codex_usage "$1"; exit ;;
  start|finish|note)
    [[ $# -ge 1 && "$1" =~ ^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$ && ${#1} -le 72 ]] || usage
    task_id="$1"; shift ;;
  report) [[ $# == 0 ]] || usage ;;
  *) usage ;;
esac
mkdir -p "$metrics"
case "$command" in
  start)
    [[ $# == 0 ]] || usage
    state="$metrics/$task_id.start"
    transcript="${WORKFLOW_METRICS_TRANSCRIPT:-}"
    if [[ -z "$transcript" ]]; then
      slug="$(printf '%s' "$root" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')"
      for candidate in "$HOME/.claude/projects/$slug"/*.jsonl; do
        [[ -f "$candidate" ]] || continue
        if [[ -z "$transcript" || "$candidate" -nt "$transcript" ]]; then transcript="$candidate"; fi
      done
    fi
    { date +%s; fingerprint; printf '%s\n' "$transcript"; date -u +%Y-%m-%dT%H:%M:%SZ; } > "$state"
    ;;
  finish)
    findings='N/A'; class='N/A'
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --findings) [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || usage; findings="$2"; shift 2 ;;
        --class) [[ $# -ge 2 && "$2" =~ ^[A-Za-z]+/[A-Za-z]+$ ]] || usage; class="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ -f "$metrics/$task_id.start" ]] || { echo "ERROR: start missing for $task_id" >&2; exit 2; }
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$root" "$metrics" "$task_id" "$findings" "$class" <<'PY'
import csv, datetime, glob, json, os, re, statistics, sys, time
root, metrics, task, findings, fallback_class = sys.argv[1:]
columns = ['task_id','claude_input_tokens','claude_cache_write_tokens','claude_cache_read_tokens','claude_output_tokens','claude_requests','codex_input_tokens','codex_cached_tokens','codex_output_tokens','codex_runs','fix_rounds','first_quick_check','any_exit_4','elapsed_seconds','permission_prompts','findings','complexity','risk','model','effort','fingerprint','escaped_defects']
with open(os.path.join(metrics, task + '.start'), encoding='utf-8') as f:
    start = int(f.readline().strip()); fingerprint = f.readline().strip(); transcript = f.readline().rstrip('\n')
end = int(time.time())
def within(value):
    try: return start <= datetime.datetime.fromisoformat(value.replace('Z','+00:00')).timestamp() <= end
    except (ValueError, TypeError, AttributeError): return False
claude = [0]*5; seen = set(); available = False
if transcript and os.path.isfile(transcript):
    with open(transcript, encoding='utf-8') as f:
        for line in f:
            try: item = json.loads(line)
            except ValueError: continue
            rid = item.get('requestId'); usage = (item.get('message') or {}).get('usage') or {}
            if item.get('type') != 'assistant' or not rid or rid in seen or not within(item.get('timestamp')) or not usage: continue
            seen.add(rid)
            for i,key in enumerate(('input_tokens','cache_creation_input_tokens','cache_read_input_tokens','output_tokens')):
                claude[i] += usage.get(key,0) if isinstance(usage.get(key,0),int) else 0
            claude[4] += 1; available = True
prompt_log = os.path.join(metrics,'permission-requests.log')
prompts = sum(1 for line in open(prompt_log, encoding='utf-8') if within(line.strip())) if os.path.isfile(prompt_log) else 0
run_paths = glob.glob(os.path.join(root,'.workflow','handoffs',task+'-run.*'))
fix_paths = glob.glob(os.path.join(root,'.workflow','handoffs',task+'-fix-*-run.*'))
run_paths = [p for p in run_paths if os.path.isfile(os.path.join(p,'status.txt'))]
fix_paths = [p for p in fix_paths if os.path.isfile(os.path.join(p,'status.txt'))]
all_paths = sorted(run_paths+fix_paths, key=os.path.getmtime)
codex = [0,0,0]; codex_available = bool(all_paths); statuses=[]
for p in all_paths:
    status = dict(line.strip().split('=',1) for line in open(os.path.join(p,'status.txt'),encoding='utf-8') if '=' in line)
    statuses.append(status)
    keys = ('CODEX_INPUT_TOKENS','CODEX_CACHED_TOKENS','CODEX_OUTPUT_TOKENS')
    if all(status.get(k,'').isdigit() for k in keys):
        codex = [x+int(status[k]) for x,k in zip(codex,keys)]
    else: codex_available = False
first = min(run_paths,key=os.path.getmtime) if run_paths else None
first_status = dict(line.strip().split('=',1) for line in open(os.path.join(first,'status.txt'),encoding='utf-8') if '=' in line) if first else {}
handoff = os.path.join(root,'.workflow','handoffs',task+'.md')
if not os.path.isfile(handoff): handoff = os.path.join(root,'.claude','handoffs',task+'.md')
route = ''
if os.path.isfile(handoff):
    data = open(handoff,encoding='utf-8').read()
    match = re.search(r'^## Route\s*\n(.*?)(?=^## |\Z)',data,re.M|re.S)
    if match: route = match.group(1)
def route_value(label):
    match = re.search(r'(?:^|[;\n])\s*-?\s*'+re.escape(label)+r':\s*([^;\n]+)',route,re.M|re.I)
    return match.group(1).strip() if match else None
complexity = route_value('Complexity'); risk = route_value('Governance risk')
if not complexity or not risk:
    parts = fallback_class.split('/') if fallback_class != 'N/A' else ['N/A','N/A']
    complexity = complexity or parts[0]; risk = risk or parts[1]
model = route_value('Codex model') or first_status.get('MODEL','N/A')
effort = route_value('Codex reasoning effort') or first_status.get('EFFORT','N/A')
row = dict(zip(columns,[task,*([str(v) for v in claude] if available else ['N/A']*5),*([str(v) for v in codex] if codex_available else ['N/A']*3),str(len(all_paths)),str(len(fix_paths)),first_status.get('QUICK_CHECK_EXIT','N/A'),str(int(any(s.get('FINAL_EXIT_CODE')=='4' for s in statuses))),str(end-start),str(prompts),findings,complexity,risk,model,effort,fingerprint,'0']))
path = os.path.join(metrics,'tasks.tsv'); rows=[]
if os.path.isfile(path):
    with open(path,newline='',encoding='utf-8') as f: rows = list(csv.DictReader(f,delimiter='\t'))
for old in rows:
    if old['task_id']==task: row['escaped_defects'] = old.get('escaped_defects','0')
rows = [r for r in rows if r['task_id'] != task]+[row]
tmp = path+'.tmp'
with open(tmp,'w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=columns,delimiter='\t',extrasaction='ignore'); w.writeheader(); w.writerows(rows)
os.replace(tmp,path)
PY
    else
      finish_without_python
    fi
    ;;
  note)
    [[ $# == 1 && "$1" =~ ^escaped=[0-9]+$ ]] || usage
    if ! command -v python3 >/dev/null 2>&1; then
      [[ -f "$metrics/tasks.tsv" ]] || { echo 'ERROR: task row missing' >&2; exit 2; }
      awk -F '\t' -v OFS='\t' -v id="$task_id" -v escaped="${1#escaped=}" '
        $1==id { $22=escaped; found=1 } { print } END { if (!found) exit 2 }
      ' "$metrics/tasks.tsv" > "$metrics/tasks.tsv.tmp" || exit 2
      mv "$metrics/tasks.tsv.tmp" "$metrics/tasks.tsv"
      exit 0
    fi
    python3 - "$metrics/tasks.tsv" "$task_id" "${1#escaped=}" <<'PY'
import csv, os, sys
path, task, escaped = sys.argv[1:]
with open(path,newline='',encoding='utf-8') as f:
    reader=csv.DictReader(f,delimiter='\t'); columns=reader.fieldnames; rows=list(reader)
found=False
for row in rows:
    if row['task_id']==task: row['escaped_defects']=escaped; found=True
if not found: sys.exit('ERROR: task row missing')
tmp=path+'.tmp'
with open(tmp,'w',newline='',encoding='utf-8') as f:
    writer=csv.DictWriter(f,fieldnames=columns,delimiter='\t'); writer.writeheader(); writer.writerows(rows)
os.replace(tmp,path)
PY
    ;;
  report)
    if ! command -v python3 >/dev/null 2>&1; then report_without_python; exit 0; fi
    python3 - "$metrics/tasks.tsv" <<'PY'
import collections,csv,os,statistics,sys
path=sys.argv[1]
print('fingerprint\tcomplexity\trisk\tn\tclaude_input\tclaude_cache_write\tclaude_cache_read\tclaude_output\tcodex_input\tcodex_cached\tcodex_output\telapsed\tprompts\tfirst_pass_rate\tmean_fix_rounds\tescaped_total\tstatus')
if not os.path.isfile(path): sys.exit(0)
groups=collections.defaultdict(list)
for row in csv.DictReader(open(path,newline='',encoding='utf-8'),delimiter='\t'):
    groups[(row['fingerprint'],row['complexity'],row['risk'])].append(row)
def median(rows,key):
    values=[float(r[key]) for r in rows if r.get(key,'').isdigit()]
    return str(statistics.median(values)) if values else 'N/A'
for group,rows in sorted(groups.items()):
    n=len(rows)
    fields=[median(rows,k) for k in ('claude_input_tokens','claude_cache_write_tokens','claude_cache_read_tokens','claude_output_tokens','codex_input_tokens','codex_cached_tokens','codex_output_tokens','elapsed_seconds','permission_prompts')]
    first=f'{sum(r.get("first_quick_check")=="0" for r in rows)}/{n}'
    fixes=f'{statistics.mean(int(r.get("fix_rounds",0)) for r in rows):.2f}'
    escaped=str(sum(int(r.get('escaped_defects',0)) for r in rows))
    status='INSUFFICIENT (n<5)' if n<5 else 'SUFFICIENT'
    if len({(r.get('model'),r.get('effort')) for r in rows}) > 1: status += '; MIXED MODEL/EFFORT'
    print('\t'.join([*group,str(n),*fields,first,fixes,escaped,status]))
PY
    ;;
esac
