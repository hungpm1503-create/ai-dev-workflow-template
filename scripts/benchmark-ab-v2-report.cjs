#!/usr/bin/env node
// Helper for benchmark-codex-ab-v2.sh. No model calls.
//   record <events.jsonl> <out.json> key=value ...   -> per-run metrics JSON
//   summary <run_dir>                                -> RESULTS.md on stdout
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const READ_TOOLS = /\b(cat|sed|nl|head|tail|rg|grep|less|awk|bat)\b/;

function readEvents(file) {
  const out = [];
  if (!fs.existsSync(file)) return out;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    try { out.push(JSON.parse(line)); } catch { /* ignore partial line */ }
  }
  return out;
}

function record(eventsFile, outFile, kv) {
  const meta = Object.fromEntries(kv.map((s) => { const i = s.indexOf('='); return [s.slice(0, i), s.slice(i + 1)]; }));
  const events = readEvents(eventsFile);
  const raw = fs.existsSync(eventsFile) ? fs.readFileSync(eventsFile, 'utf8') : '';
  let input = 0, cached = 0, output = 0, reasoning = 0, turns = 0;
  for (const ev of events) {
    if (ev?.type !== 'turn.completed' || !ev.usage) continue;
    const u = ev.usage;
    if (![u.input_tokens, u.output_tokens].every(Number.isFinite)) continue;
    input += u.input_tokens;
    cached += Number.isFinite(u.cached_input_tokens) ? u.cached_input_tokens : 0;
    output += u.output_tokens;
    reasoning += Number.isFinite(u.reasoning_output_tokens) ? u.reasoning_output_tokens : 0;
    turns++;
  }
  const files = (meta.files || '').split(',').filter(Boolean);
  const reads = Object.fromEntries(files.map((f) => [f, 0]));
  let cmds = 0;
  for (const ev of events) {
    if (ev?.type !== 'item.completed' || ev.item?.type !== 'command_execution') continue;
    cmds++;
    const c = String(ev.item.command || '');
    if (!READ_TOOLS.test(c) || /node\s+--test/.test(c)) continue;
    for (const f of files) if (c.includes(f)) reads[f]++;
  }
  const repeat = Object.values(reads).reduce((a, n) => a + Math.max(0, n - 1), 0);
  const num = (k) => (meta[k] === undefined || meta[k] === '' ? null : Number(meta[k]));
  const rec = {
    task: meta.task, arm: meta.arm, trial: num('trial'), position: num('position'),
    model_exit: num('model_exit'), wall_s: num('wall_s'),
    visible_pass: num('vis_pass'), visible_fail: num('vis_fail'),
    hidden_pass: num('hid_pass'), hidden_fail: num('hid_fail'),
    diff_sha: meta.diff_sha, diff_lines: num('diff_lines'), changed: meta.changed || '',
    usage_available: turns > 0,
    input: turns ? input : null, cached: turns ? cached : null,
    uncached: turns ? input - cached : null, output: turns ? output : null,
    reasoning: turns ? reasoning : null, turns, cmds, reads, repeat_reads: repeat,
    handoff_reads: reads['HANDOFF.md'] ?? 0,
    // Any trace of the user's global Superpowers plugin/skills loaded into the run.
    contaminated: /superpowers|using-superpowers|\.codex\/plugins/i.test(raw),
  };
  fs.writeFileSync(outFile, JSON.stringify(rec, null, 2));
}

const median = (a) => { if (!a.length) return null; const s = [...a].sort((x, y) => x - y); const m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
const fmt = (v) => (v === null || v === undefined ? 'N/A' : Number.isInteger(v) ? v.toLocaleString('en-US') : v.toFixed(1));
const agg = (a) => { const v = a.filter((x) => x !== null && x !== undefined); return v.length ? `${fmt(median(v))} [${fmt(Math.min(...v))}–${fmt(Math.max(...v))}]` : 'N/A'; };

function summary(runDir) {
  const dir = path.join(runDir, 'runs');
  const runs = fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')));
  const cfg = fs.existsSync(path.join(runDir, 'config.txt')) ? fs.readFileSync(path.join(runDir, 'config.txt'), 'utf8') : '';
  const L = [];
  L.push('# Codex A/B v2 results (measured data only; interpretation is labelled)', '', '```', cfg.trim(), '```', '');
  const tasks = [...new Set(runs.map((r) => r.task))].sort();
  for (const t of tasks) {
    const tr = runs.filter((r) => r.task === t);
    L.push(`## Task ${t}`, '', '### Per run', '',
      '| trial | arm | pos | uncached in | input | cached | output | cmds | repeat reads | handoff reads | wall s | visible | hidden | diff sha | contaminated |',
      '| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |');
    for (const r of tr.sort((a, b) => a.trial - b.trial || a.position - b.position)) {
      L.push(`| ${r.trial} | ${r.arm} | ${r.position} | ${fmt(r.uncached)} | ${fmt(r.input)} | ${fmt(r.cached)} | ${fmt(r.output)} | ${r.cmds} | ${r.repeat_reads} | ${r.handoff_reads} | ${fmt(r.wall_s)} | ${r.visible_pass}/${r.visible_pass + r.visible_fail} | ${r.hidden_pass}/${r.hidden_pass + r.hidden_fail} | ${String(r.diff_sha).slice(0, 8)} | ${r.contaminated ? 'YES' : 'no'} |`);
    }
    L.push('', '### Aggregate: median [min–max]', '', '| metric | baseline (v0.3 prose) | memory (v0.4 checkpoint) |', '| --- | --- | --- |');
    const by = (arm) => tr.filter((r) => r.arm === arm);
    for (const [name, key] of [['uncached input tokens (primary)', 'uncached'], ['input tokens (incl. cached)', 'input'], ['cached input', 'cached'], ['output tokens', 'output'], ['reasoning tokens', 'reasoning'], ['shell commands', 'cmds'], ['repeat reads', 'repeat_reads'], ['wall seconds (noisy: tracks ran concurrently)', 'wall_s'], ['visible tests passed', 'visible_pass'], ['hidden tests passed', 'hidden_pass']]) {
      L.push(`| ${name} | ${agg(by('baseline').map((r) => r[key]))} | ${agg(by('memory').map((r) => r[key]))} |`);
    }
    const trials = [...new Set(tr.map((r) => r.trial))];
    let fewer = 0, paired = 0;
    for (const n of trials) {
      const b = tr.find((r) => r.trial === n && r.arm === 'baseline'), m = tr.find((r) => r.trial === n && r.arm === 'memory');
      if (b?.uncached != null && m?.uncached != null) { paired++; if (m.uncached < b.uncached) fewer++; }
    }
    const shas = (arm) => [...new Set(by(arm).map((r) => r.diff_sha))].length;
    const full = (arm) => by(arm).filter((r) => r.visible_fail === 0 && r.hidden_fail === 0 && r.model_exit === 0).length;
    L.push('', `- Paired trials where memory used fewer uncached input tokens: **${fewer}/${paired}**`,
      `- Fully correct runs (CLI ok, visible+hidden all pass): baseline ${full('baseline')}/${by('baseline').length}, memory ${full('memory')}/${by('memory').length}`,
      `- Distinct diff hashes: baseline ${shas('baseline')}, memory ${shas('memory')}`,
      `- Contaminated runs (Superpowers/plugin trace): ${tr.filter((r) => r.contaminated).length}`,
      `- Runs with changes outside the allowed file set: ${tr.filter((r) => r.changed).length}`, '');
  }
  L.push('## Interpretation rules (fixed before measuring)', '',
    '- **Measured:** the tables above. **Not proven:** anything beyond them.',
    '- With N this small, no p-values or "significant" claims. Report direction and consistency only.',
    '- v0.4 is supported only if: correctness >= baseline in both tasks, no extra scope violations, and fewer uncached input tokens in most paired trials (>= 4 of 5) for the task(s) claimed.',
    '- Cache state, provider load and concurrency make wall time and cached tokens unreliable; uncached input and output tokens are the primary cost proxies.',
    '- Task B handoff is a hand-written fixture of a half-finished task, not a real model-to-model session transfer.',
    '- Passing tests (even hidden) is not a substitute for human diff review.');
  process.stdout.write(L.join('\n') + '\n');
}

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === 'record') record(rest[0], rest[1], rest.slice(2));
else if (cmd === 'summary') summary(rest[0]);
else { console.error('usage: record|summary'); process.exit(2); }
