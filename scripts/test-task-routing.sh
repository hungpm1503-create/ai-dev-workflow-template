#!/usr/bin/env bash
# Offline routing guardrail; never calls Claude or Codex.
# This is a documentation-contract test: it proves the rules are written down consistently,
# NOT that a model classifies tasks correctly. Use docs/workflow/pilot-checklist.md for that.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
fail() { echo "FAIL: $*" >&2; exit 1; }
need() { grep -Fq -- "$2" "$1" || fail "$3"; }
doc='docs/workflow/task-routing.md'
need "$doc" 'three independent dimensions' 'classification requires complexity, risk and traceability'
need "$doc" '| SMALL | LOW | LOW | **NONE**' 'small no-framework route missing'
need "$doc" '| LARGE | LOW | LOW | **SUPERPOWERS preferred**' 'Superpowers planning missing'
need "$doc" '| ANY | LOW | HIGH | **SPEC KIT preferred**' 'traceability-based Spec Kit missing'
need "$doc" '| ANY | HIGH | ANY | **FULL GOVERNANCE + one project-allowed planning path**' 'High-risk safeguards missing'
need "$doc" 'An author cannot self-certify an independent review.' 'independent review is not genuine'
need "$doc" '**Never run Spec Kit planning and Superpowers brainstorming/writing-plans for the same task.**' 'duplicate planning prevention missing'
need "$doc" 'Do not run Superpowers subagent-driven development' 'Codex implementation ownership missing'
need "$doc" 'No new benchmark' 'benchmark scope creep'
need "$doc" 'VIBE never applies to HIGH risk.' 'VIBE mode must exclude HIGH risk'
need "$doc" 'Real verification (tests/lint/build with exit codes, PASS/FAIL/UNVERIFIED) is still mandatory.' 'VIBE mode must keep verification'
need 'CLAUDE.md' '**Leave VIBE mode immediately**' 'Claude VIBE exit triggers missing'
need '.claude/skills/vibe/SKILL.md' '## 3. Verify (never skipped)' 'vibe skill must verify'
need '.claude/skills/vibe/SKILL.md' 'Never push, merge or deploy.' 'vibe skill must not push'
# The implementer rule must be byte-identical wherever it appears, so the model gets one answer.
rule="$(grep -o '\*\*Implementer rule:\*\*.*overrides (1)–(2)\.' .claude/skills/vibe/SKILL.md)" || fail 'vibe skill implementer rule missing'
for f in CLAUDE.md "$doc"; do grep -Fq -- "$rule" "$f" || fail "implementer rule in $f differs from the vibe skill"; done
need '.claude/skills/vibe/SKILL.md' 'Never stash silently.' 'dirty-tree handling missing'
need '.claude/skills/vibe/SKILL.md' 'Do not ask about checkpoints by default.' 'checkpoint prompts must be opt-in'
need 'CLAUDE.md' 'prefer **Superpowers**' 'Claude cannot choose Superpowers'
need 'CLAUDE.md' 'prefer **Spec Kit**' 'Claude cannot choose Spec Kit'
need 'CLAUDE.md' 'FULL GOVERNANCE' 'Claude High-risk override missing'
need 'AGENTS.md' 'Codex must not redo planning' 'Codex ownership missing'
need 'docs/workflow/handoff-template.md' '- Traceability: LOW / HIGH' 'handoff traceability missing'
need 'docs/workflow/handoff-template.md' '- Selected planning path: NONE / CLAUDE / SUPERPOWERS / SPEC KIT' 'handoff planning choice missing'
need 'docs/workflow/handoff-template.md' '- Governance: STANDARD / FULL GOVERNANCE' 'handoff governance missing'
need 'docs/workflow/project-setup.md' 'Project-required approvals' 'setup missing project overrides'
need '.claude/skills/plan-quality/SKILL.md' '**ANY/HIGH risk:**' 'quality skill missing governance'
need '.claude/skills/codex-delegate/SKILL.md' 'one approved planning source' 'Codex handoff source missing'
echo 'PASS (doc-contract only; see docs/workflow/pilot-checklist.md for live checks): VIBE mode guardrails, single implementer rule, framework selection, risk gates, traceability and Codex ownership'
