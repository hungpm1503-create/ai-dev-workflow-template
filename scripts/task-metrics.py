#!/usr/bin/env python3
"""Offline, metadata-only report for existing Codex delegation runs (no model calls).

Requires Python 3 standard library. Reads ignored local run artifacts and optionally a
small human-review CSV; never copies prompts, code diffs or raw Codex logs to output.
"""
import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path

TASK = re.compile(r"^TASK-[A-Za-z0-9][A-Za-z0-9_-]*$")
RUN = re.compile(r"^(TASK-[A-Za-z0-9][A-Za-z0-9_-]*)-run\.[A-Za-z0-9]+$")
REVIEW_FIELDS = ("task_id", "first_pass", "accepted", "human_interventions")
VERDICTS = {"PASS", "FAIL", "UNVERIFIED"}


def read_text(path):
    if path.is_symlink() or not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def read_status(path):
    result = {}
    for line in read_text(path).splitlines():
        key, sep, value = line.partition("=")
        if sep and key in {"CODEX_EXIT_CODE", "QUICK_CHECK_EXIT", "FINAL_EXIT_CODE", "FOLLOW_UP_OF"}:
            result[key] = value.strip()
    return result


def usage_from_jsonl(path):
    """Only count documented Codex turn.completed usage; never guess from text logs."""
    if path.is_symlink() or not path.is_file():
        return None
    total = [0, 0, 0]
    valid = 0
    try:
        with path.open(encoding="utf-8", errors="replace") as stream:
            for line in stream:
                try:
                    event = json.loads(line)
                except (ValueError, TypeError):
                    continue
                if not isinstance(event, dict) or event.get("type") != "turn.completed":
                    continue
                usage = event.get("usage")
                if not isinstance(usage, dict):
                    return None
                inp, out, cached = (usage.get("input_tokens"), usage.get("output_tokens"),
                                    usage.get("cached_input_tokens", 0))
                if not all(type(n) is int and n >= 0 for n in (inp, out, cached)) or cached > inp:
                    return None
                for i, n in enumerate((inp, cached, out)):
                    total[i] += n
                valid += 1
    except OSError:
        return None
    return tuple(total) if valid else None


def duration_seconds(folder):
    """Proxy from the before-status write to the final-status write, not task wall time."""
    before, after = folder / "status-before.txt", folder / "status.txt"
    if any(p.is_symlink() or not p.is_file() for p in (before, after)):
        return None
    try:
        delta = after.stat().st_mtime - before.stat().st_mtime
    except OSError:
        return None
    return round(delta, 1) if delta >= 0 else None


def load_reviews(path):
    reviews = {}
    if not path.exists():
        return reviews
    if path.is_symlink() or not path.is_file():
        raise ValueError("Review CSV must be a regular local file")
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or not set(REVIEW_FIELDS).issubset(reader.fieldnames):
            raise ValueError("Review CSV needs columns: " + ", ".join(REVIEW_FIELDS))
        for row in reader:
            task_id = (row.get("task_id") or "").strip()
            if not TASK.fullmatch(task_id) or task_id in reviews:
                raise ValueError("Review CSV has an invalid or duplicate task_id")
            first = (row.get("first_pass") or "UNVERIFIED").strip().upper()
            accepted = (row.get("accepted") or "UNVERIFIED").strip().upper()
            interventions = (row.get("human_interventions") or "").strip()
            if first not in VERDICTS or accepted not in VERDICTS:
                raise ValueError("Review CSV verdict must be PASS, FAIL or UNVERIFIED")
            if interventions and (not interventions.isdigit() or int(interventions) > 100000):
                raise ValueError("human_interventions must be a nonnegative integer or blank")
            reviews[task_id] = (first, accepted, interventions or "N/A")
    return reviews


def collect(runs_dir):
    rows = []
    if not runs_dir.exists():
        return rows
    if runs_dir.is_symlink() or not runs_dir.is_dir():
        raise ValueError("Runs directory must be a real local directory")
    for folder in sorted(runs_dir.iterdir()):
        match = RUN.fullmatch(folder.name)
        if not match or folder.is_symlink() or not folder.is_dir():
            continue
        status = read_status(folder / "status.txt")
        parent = status.get("FOLLOW_UP_OF", "")
        if parent and not TASK.fullmatch(parent):
            parent = ""
        usage = usage_from_jsonl(folder / "codex.log")
        changed = read_text(folder / "changed-paths.txt")
        rows.append({
            "task_id": match.group(1), "run_id": folder.name, "follow_up_of": parent,
            "model": read_text(folder / "model.txt").strip() or "N/A",
            "reasoning_effort": read_text(folder / "effort.txt").strip() or "N/A",
            "codex_exit": status.get("CODEX_EXIT_CODE", "N/A"),
            "quick_check_exit": status.get("QUICK_CHECK_EXIT", "UNVERIFIED"),
            "final_exit": status.get("FINAL_EXIT_CODE", "UNVERIFIED"),
            "changed_files": len([x for x in changed.splitlines() if x.strip()]) if changed else "N/A",
            "run_seconds_proxy": duration_seconds(folder),
            "input_tokens": usage[0] if usage else None,
            "cached_input_tokens": usage[1] if usage else None,
            "output_tokens": usage[2] if usage else None,
        })
    return rows


def root_of(task_id, parents):
    visited = set()
    current = task_id
    while current in parents and current not in visited and parents[current] != current:
        visited.add(current)
        current = parents[current]
    return current


def aggregate(rows, reviews):
    parents = {r["task_id"]: r["follow_up_of"] for r in rows if r["follow_up_of"]}
    grouped = defaultdict(list)
    for row in rows:
        grouped[root_of(row["task_id"], parents)].append(row)
    summary = []
    for task_id in sorted(grouped):
        rs = grouped[task_id]
        first, accepted, interventions = reviews.get(task_id, ("UNVERIFIED", "UNVERIFIED", "N/A"))
        seconds = [r["run_seconds_proxy"] for r in rs]
        usage_complete = all(r["input_tokens"] is not None for r in rs)
        summary.append({
            "task_id": task_id, "runs": len(rs),
            "tracked_followups": sum(bool(r["follow_up_of"]) for r in rs),
            "quick_checks_passed": sum(r["quick_check_exit"] == "0" for r in rs),
            "first_pass": first, "accepted": accepted, "human_interventions": interventions,
            "run_seconds_proxy": round(sum(seconds), 1) if all(s is not None for s in seconds) else None,
            "input_tokens": sum(r["input_tokens"] for r in rs) if usage_complete else None,
            "cached_input_tokens": sum(r["cached_input_tokens"] for r in rs) if usage_complete else None,
            "output_tokens": sum(r["output_tokens"] for r in rs) if usage_complete else None,
        })
    return summary


def fmt(value):
    return "N/A" if value is None else str(value)


def write_csv(path, rows, fields):
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            # Avoid spreadsheet formula execution when opened in external CSV clients.
            writer.writerow({k: ("'" + fmt(row.get(k)) if fmt(row.get(k)).startswith(("=", "+", "-", "@")) else fmt(row.get(k))) for k in fields})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parent.parent
    parser.add_argument("--runs-dir", type=Path, default=root / ".workflow/handoffs")
    parser.add_argument("--output-dir", type=Path, default=root / ".workflow/metrics")
    parser.add_argument("--reviews", type=Path, help="Optional human review CSV (task_id,first_pass,accepted,human_interventions)")
    args = parser.parse_args()
    reviews = load_reviews(args.reviews) if args.reviews else {}
    rows = collect(args.runs_dir)
    tasks = aggregate(rows, reviews)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_csv(args.output_dir / "runs.csv", rows, ("task_id", "run_id", "follow_up_of", "model", "reasoning_effort", "codex_exit", "quick_check_exit", "final_exit", "changed_files", "run_seconds_proxy", "input_tokens", "cached_input_tokens", "output_tokens"))
    write_csv(args.output_dir / "tasks.csv", tasks, ("task_id", "runs", "tracked_followups", "quick_checks_passed", "first_pass", "accepted", "human_interventions", "run_seconds_proxy", "input_tokens", "cached_input_tokens", "output_tokens"))
    lines = ["# Local task metrics (offline)", "", f"Codex task groups: **{len(tasks)}**; captured runs: **{len(rows)}**.", "", "| Task | Runs | Follow-ups | Quick-check PASS | First pass | Accepted | Input tokens | Output tokens | Duration proxy (s) |", "| --- | ---: | ---: | ---: | --- | --- | ---: | ---: | ---: |"]
    for t in tasks:
        lines.append("| " + " | ".join(map(str, (t["task_id"], t["runs"], t["tracked_followups"], t["quick_checks_passed"], t["first_pass"], t["accepted"], fmt(t["input_tokens"]), fmt(t["output_tokens"]), fmt(t["run_seconds_proxy"])))) + " |")
    if not tasks:
        lines.append("| No local runs found | 0 | 0 | 0 | UNVERIFIED | UNVERIFIED | N/A | N/A | N/A |")
    lines += ["", "**Interpretation:** Quick-check PASS is not task acceptance. First-pass and accepted verdicts require manual evidence in the optional review CSV; unknown is UNVERIFIED. Tracked follow-ups omit other possible rework.", "", "Token usage is read only from structured `turn.completed.usage` JSONL in `codex.log` (requires opt-in `CODEX_METRICS_JSON=1` for future runs); incomplete usage stays N/A. Cached input tokens are included within input tokens, not added to them. Model costs are not calculated.", "", "Duration is an approximate Codex-wrapper interval from `status-before.txt` to `status.txt`, not end-to-end task time or human review time. No prompts, source diffs or raw logs are exported. Keep this report local unless you review it for sensitive metadata.", ""]
    (args.output_dir / "SUMMARY.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Offline metrics: {len(rows)} runs / {len(tasks)} task groups. Report: {args.output_dir / 'SUMMARY.md'}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as e:
        raise SystemExit(f"ERROR: {e}")
