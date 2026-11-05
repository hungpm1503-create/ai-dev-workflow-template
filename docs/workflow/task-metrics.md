# Low-cost task metrics (offline)

This optional reporter reads **existing local Codex wrapper artifacts**. It never calls a model, sends data off-machine, monitors Claude chats, or changes execution/approval rules. It does not assess code quality by itself.

## Setup and first report

Python 3 standard library is the only runtime requirement. From the root of a configured project using this template:

```bash
python3 scripts/task-metrics.py
```

Results are written to gitignored `.workflow/metrics/`:

- `SUMMARY.md`: compact per-task overview
- `tasks.csv`: aggregate per root task, grouping recognized Codex `--follow-up` runs
- `runs.csv`: one row per completed or incomplete Codex wrapper run

No files from `.workflow/handoffs/` are changed. If no local runs exist, reports contain 0 task groups, not fabricated measurements. Report only includes metadata; prompts, completions, code diffs and raw logs are not copied.

## Structured token usage — opt-in for future Codex runs

The current wrapper normally writes human-readable `codex.log` without structured token usage. To capture exact reported usage in future runs, opt in for **only the invocation you already intended to execute**:

```bash
CODEX_METRICS_JSON=1 bash scripts/codex-standard.sh TASK-EXAMPLE-001
# For an appropriately approved, non-standard handoff:
CODEX_METRICS_JSON=1 bash scripts/codex-delegate.sh TASK-EXAMPLE-002
```

This adds `--json` to the existing `codex exec` call without adding an agent, a second model call or changing sandbox/approval defaults. It changes the local `codex.log` format to JSONL; enable only when your installed Codex CLI supports `exec --json`. The reporter counts valid `turn.completed.usage` records (input, cached input, output). **Cached input is a subset of input tokens.** Old human-readable logs remain `N/A`; never assume 0 tokens. Neither token totals nor cached tokens directly equal billed cost; subscription usage and pricing vary.

## Record quality without another reviewer model

Quality needs evidence from real acceptance tests and code review. A passing `QUICK_CHECK_EXIT=0` is **not** proof that a feature was accepted. Optionally create `.workflow/metrics/reviews.csv` with one row per root task:

```csv
task_id,first_pass,accepted,human_interventions
TASK-EXAMPLE-001,FAIL,PASS,1
```

Only enter actual observations. Verdicts are `PASS`, `FAIL` or `UNVERIFIED`. Leave `human_interventions` empty when unknown. Re-run:

```bash
python3 scripts/task-metrics.py --reviews .workflow/metrics/reviews.csv
```

Without reviews, first-pass and accepted stay `UNVERIFIED`. `tracked_followups` counts wrapper follow-ups, not every human fix/retry. `run_seconds_proxy` is derived from local file modification times, starting with the pre-run status and ending with the final status; it excludes Claude planning, user approvals and subsequent human review. It is not full task wall time. No costs are calculated without trusted provider billing records.

## Compare changes responsibly

Collect a sample of real SMALL/MEDIUM/HIGH-risk tasks and compare **similar complexity and acceptance outcomes** over time. Compare tokens (when available), elapsed proxy, follow-up count and human intervention count. Do not claim the latest harness wins because one run consumed fewer tokens. For a genuine controlled A/B of context formats, use `docs/workflow/codex-ab-pilot.md` on identical fixtures with explicit model opt-in; two runs remain exploratory.

### Safety and limitations

- Reports remain local and gitignored. Review metadata before sharing; even task IDs and model details may be sensitive.
- No new hooks, background observers, telemetry services, or LLM calls.
- The tool is intentionally limited to Codex wrapper runs, not Claude Code usage. It cannot reconstruct token usage from missing historic logs.
- All missing, incomplete, or ambiguous measurements are reported `N/A` or `UNVERIFIED` rather than being presented as successful.
- Test offline without tokens: `python3 scripts/test-task-metrics.py`.
