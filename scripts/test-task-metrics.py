#!/usr/bin/env python3
"""Offline fixture tests for metadata-only task metrics; never invoke Codex."""
import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "task-metrics.py"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


class MetricsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.runs = self.root / "handoffs"
        self.runs.mkdir()
        self.output = self.root / "metrics"

    def run_report(self, *args, success=True):
        p = subprocess.run([sys.executable, str(SCRIPT), "--runs-dir", str(self.runs),
                            "--output-dir", str(self.output), *args],
                           text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if success:
            self.assertEqual(p.returncode, 0, p.stderr)
        else:
            self.assertNotEqual(p.returncode, 0)
        return p

    def fixture(self, task, suffix, *, status, jsonl="", complete=True):
        d = self.runs / f"{task}-run.{suffix}"
        d.mkdir()
        (d / "status-before.txt").write_text("", encoding="utf-8")
        (d / "model.txt").write_text("gpt-test\n", encoding="utf-8")
        (d / "effort.txt").write_text("medium\n", encoding="utf-8")
        (d / "changed-paths.txt").write_text("src/a.cs\nsrc/b.cs\n", encoding="utf-8")
        (d / "codex.log").write_text(jsonl, encoding="utf-8")
        if complete:
            (d / "status.txt").write_text(status, encoding="utf-8")
        return d

    def test_no_runs_makes_valid_empty_reports(self):
        self.run_report()
        self.assertEqual(read_csv(self.output / "runs.csv"), [])
        self.assertEqual(read_csv(self.output / "tasks.csv"), [])
        self.assertIn("Codex task groups: **0**", (self.output / "SUMMARY.md").read_text())

    def test_usage_followups_and_manual_review(self):
        j = json.dumps({"type": "turn.completed", "usage": {
            "input_tokens": 110, "cached_input_tokens": 40, "output_tokens": 15}})
        k = json.dumps({"type": "turn.completed", "usage": {
            "input_tokens": 50, "cached_input_tokens": 20, "output_tokens": 10}})
        self.fixture("TASK-001", "abc123", status="CODEX_EXIT_CODE=0\nQUICK_CHECK_EXIT=0\nFINAL_EXIT_CODE=0\n", jsonl=j + "\n" + k + "\n")
        self.fixture("TASK-001-FIX", "def123", status="FOLLOW_UP_OF=TASK-001\nCODEX_EXIT_CODE=0\nQUICK_CHECK_EXIT=0\nFINAL_EXIT_CODE=0\n", jsonl=j + "\n")
        review = self.root / "review.csv"
        review.write_text("task_id,first_pass,accepted,human_interventions\nTASK-001,FAIL,PASS,2\n", encoding="utf-8")
        self.run_report("--reviews", str(review))
        runs = read_csv(self.output / "runs.csv")
        tasks = read_csv(self.output / "tasks.csv")
        self.assertEqual(len(runs), 2)
        self.assertEqual(len(tasks), 1)
        self.assertEqual(tasks[0]["runs"], "2")
        self.assertEqual(tasks[0]["tracked_followups"], "1")
        self.assertEqual(tasks[0]["quick_checks_passed"], "2")
        self.assertEqual(tasks[0]["input_tokens"], "270")
        self.assertEqual(tasks[0]["cached_input_tokens"], "100")
        self.assertEqual(tasks[0]["output_tokens"], "40")
        self.assertEqual(tasks[0]["first_pass"], "FAIL")
        self.assertEqual(tasks[0]["accepted"], "PASS")
        self.assertEqual(tasks[0]["human_interventions"], "2")
        self.assertEqual(runs[0]["changed_files"], "2")
        self.assertNotIn("source code", (self.output / "SUMMARY.md").read_text())

    def test_unknown_tokens_are_not_reported_as_zero(self):
        self.fixture("TASK-BETA", "a1", status="CODEX_EXIT_CODE=0\nQUICK_CHECK_EXIT=SKIPPED_UNVERIFIED\nFINAL_EXIT_CODE=0\n", jsonl="tokens used: 12345\n")
        self.fixture("TASK-BETA-FIX", "b1", status="FOLLOW_UP_OF=TASK-BETA\nFINAL_EXIT_CODE=7\n", jsonl=json.dumps({"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":2}}) + "\n")
        self.run_report()
        task = read_csv(self.output / "tasks.csv")[0]
        self.assertEqual(task["input_tokens"], "N/A")
        self.assertEqual(task["quick_checks_passed"], "0")
        self.assertEqual(task["accepted"], "UNVERIFIED")

    def test_partial_turn_usage_is_unknown(self):
        good = json.dumps({"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":3}})
        bad = json.dumps({"type":"turn.completed","usage":{"input_tokens":-1,"output_tokens":3}})
        self.fixture("TASK-PARTIAL", "m1", status="FINAL_EXIT_CODE=0\n", jsonl=good + "\n" + bad + "\n")
        self.run_report()
        self.assertEqual(read_csv(self.output / "tasks.csv")[0]["input_tokens"], "N/A")

    def test_incomplete_and_bad_usage_fail_closed(self):
        d = self.fixture("TASK-INCOMPLETE", "run1", status="", complete=False,
                         jsonl=json.dumps({"type":"turn.completed","usage":{"input_tokens":-1,"output_tokens":4}}))
        (d / "status-before.txt").unlink()
        self.run_report()
        row = read_csv(self.output / "runs.csv")[0]
        self.assertEqual(row["final_exit"], "UNVERIFIED")
        self.assertEqual(row["input_tokens"], "N/A")
        self.assertEqual(row["run_seconds_proxy"], "N/A")

    def test_review_validation(self):
        review = self.root / "reviews.csv"
        review.write_text("task_id,first_pass,accepted,human_interventions\nTASK-1,MAYBE,PASS,2\n", encoding="utf-8")
        self.assertIn("verdict", self.run_report("--reviews", str(review), success=False).stderr)

    def test_symlinked_run_skipped(self):
        d = self.fixture("TASK-REAL", "ok1", status="FINAL_EXIT_CODE=0\n")
        (self.runs / "TASK-FAKE-run.bad").symlink_to(d, target_is_directory=True)
        self.run_report()
        self.assertEqual(len(read_csv(self.output / "runs.csv")), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
