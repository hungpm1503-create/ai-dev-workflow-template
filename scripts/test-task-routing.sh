#!/usr/bin/env bash
# Offline guardrails for adaptive routing docs. No model, no generated project files.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
fail() { echo "FAIL: $*" >&2; exit 1; }
docs='docs/workflow/task-routing.md'
[[ -s "$docs" ]] || fail 'routing decision source missing'
# Cover all four decision-matrix routes with independent size/risk classification.
grep -Fq '| SMALL | LOW | **Small** |' "$docs" || fail 'SMALL/LOW is not minimal'
grep -Fq '| MEDIUM | LOW | **Medium** |' "$docs" || fail 'MEDIUM/LOW not concise'
grep -Fq '| LARGE | LOW | **Spec Lite** |' "$docs" || fail 'LARGE/LOW missing Spec Lite'
grep -Fq '| ANY | HIGH | **Full Spec Kit /' "$docs" || fail 'HIGH-risk override missing'
grep -Fq '**HIGH risk always overrides complexity**' "$docs" || fail 'high-risk precedence missing'
grep -Fq 'do not silently substitute Spec Lite' "$docs" || fail 'no silent high-risk downgrade gate'
grep -Fq 'do not repeat an equivalent check' "$docs" || fail 'review deduplication missing'
grep -Fq 'No new benchmark' "$docs" || fail 'no benchmark guardrail missing'
# Surface consistent instructions to both agents and handoff.
grep -Fq '**LARGE / LOW:** **Spec Lite**' CLAUDE.md || fail 'Claude still forces full Spec Kit for Large/Low'
grep -Fq 'HIGH risk overrides size' CLAUDE.md || fail 'Claude missing HIGH override'
grep -Fq 'Spec Lite artifact (LARGE/LOW)' AGENTS.md || fail 'Codex not routed to Spec Lite'
grep -Fq 'Governance risk: LOW / HIGH' docs/workflow/handoff-template.md || fail 'handoff lacks risk classification'
grep -Fq 'ANY/HIGH' .claude/skills/plan-quality/SKILL.md || fail 'plan quality lacks High-risk handling'
grep -Fq 'LARGE/LOW' .claude/skills/codex-delegate/SKILL.md || fail 'Codex skill lacks route mapping'
echo 'PASS: adaptive routing matrix, high-risk override, deduplicated gates and handoff alignment'
