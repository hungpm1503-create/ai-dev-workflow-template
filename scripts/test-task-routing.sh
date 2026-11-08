#!/usr/bin/env bash
# Offline routing guardrail; never calls Claude or Codex.
# This is a documentation-contract test: it proves the rules are written down consistently,
# NOT that a model classifies tasks correctly. Use docs/workflow/pilot-checklist.md for that.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
fail() { echo "FAIL: $*" >&2; exit 1; }
need() { grep -Fq -- "$2" "$1" || fail "$3"; }
forbid() { ! grep -Fq -- "$2" "$1" || fail "$3"; }
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
need 'CLAUDE.md' '**Classify first:** assess complexity (SMALL/MEDIUM/LARGE), governance risk (LOW/HIGH) and traceability (LOW/HIGH) independently' 'Claude must classify three dimensions before VIBE'
need 'CLAUDE.md' '**Any HIGH risk goes to FULL GOVERNANCE, never VIBE.**' 'HIGH risk must override VIBE'
need 'CLAUDE.md' 'If the classification is uncertain, read `docs/workflow/task-routing.md`' 'uncertain classification must read routing'
# Detailed exit triggers belong in CLAUDE.md; skills and docs refer to it.
for t in 'financial methodology or point-in-time rules' 'autonomous execution' "project's own rules"; do
  grep -Fq -- "$t" CLAUDE.md || fail "VIBE exit trigger '$t' missing from CLAUDE.md"
done
need '.claude/skills/vibe/SKILL.md' 'CLAUDE.md §1' 'VIBE skill must link authoritative routing'
need "$doc" 'CLAUDE.md §1' 'Routing doc must link authoritative exit triggers'
need '.claude/skills/vibe/SKILL.md' '## 3. Verify (never skipped)' 'vibe skill must verify'
need '.claude/skills/vibe/SKILL.md' 'CLAUDE.md §4' 'VIBE skill must reference push/merge restrictions'
# One authoritative implementer rule in CLAUDE.md, referenced by consumers.
[[ "$(grep -c '^\\*\\*Implementer rule:\\*\\*' CLAUDE.md)" == 1 ]] || fail 'CLAUDE.md must define one implementer rule'
for f in .claude/skills/vibe/SKILL.md "$doc"; do
  grep -Fq 'CLAUDE.md §2' "$f" || fail "$f must reference CLAUDE.md §2"
  if grep -Fq '**Implementer rule:**' "$f"; then fail "$f duplicates implementer rule"; fi
done
need '.claude/skills/codex-delegate/SKILL.md' 'CLAUDE.md §1' 'Codex skill must reference central approval rules'
need '.claude/skills/codex-delegate/SKILL.md' 'CLAUDE.md §4' 'Codex skill must reference central authorization boundaries'
need '.claude/skills/vibe/SKILL.md' 'Never stash silently.' 'dirty-tree handling missing'
need '.claude/skills/vibe/SKILL.md' 'Do not ask about checkpoints by default.' 'checkpoint prompts must be opt-in'
need 'CLAUDE.md' 'prefer **Superpowers**' 'Claude cannot choose Superpowers'
need 'CLAUDE.md' 'prefer **Spec Kit**' 'Claude cannot choose Spec Kit'
need 'CLAUDE.md' 'FULL GOVERNANCE' 'Claude High-risk override missing'
need 'docs/workflow/codex-rules.md' 'Codex must not redo planning' 'Codex ownership missing'
need '.claude/skills/codex-delegate/SKILL.md' '**HIGH-risk task:** Follow `CLAUDE.md §2`' 'HIGH-risk review fixes must follow Claude ownership rule'
need '.claude/skills/codex-delegate/SKILL.md' 'bash scripts/codex-delegate.sh --follow-up' 'fix rounds must use --follow-up'
need 'CLAUDE.md' 'send every code fix back to Codex' 'CLAUDE.md must route HIGH-risk review fixes to Codex'
need 'docs/workflow/handoff-template.md' '- Traceability: LOW / HIGH' 'handoff traceability missing'
# The inline FULL GOVERNANCE skeleton in the skill must not drop a section of the full form.
full_sections="$(sed -n '/^## Full form/,$p' docs/workflow/handoff-template.md | grep '^## ' | grep -v '^## Full form' | sed 's/ (keep concise)//' | sort -u)"
while IFS= read -r sec; do
  [[ -z "$sec" ]] && continue
  grep -Fq -- "$sec" .claude/skills/codex-delegate/SKILL.md || fail "codex-delegate skeleton is missing full-form section: $sec"
done <<< "$full_sections"
need '.claude/skills/codex-delegate/SKILL.md' '- Required independent reviews and human approval evidence:' 'codex-delegate skeleton is missing independent review evidence'
need 'docs/workflow/handoff-template.md' '- Selected planning path: NONE / CLAUDE / SUPERPOWERS / SPEC KIT' 'handoff planning choice missing'
need 'docs/workflow/handoff-template.md' '- Governance: STANDARD / FULL GOVERNANCE' 'handoff governance missing'
need 'docs/workflow/project-setup.md' 'Project-required approvals' 'setup missing project overrides'
need '.claude/skills/plan-quality/SKILL.md' '**ANY/HIGH risk:**' 'quality skill missing governance'
need '.claude/skills/codex-delegate/SKILL.md' 'one approved planning source' 'Codex handoff source missing'
skeleton="$(sed -n '/^\*\*Handoff skeleton\*\*/,/^\*\*FULL GOVERNANCE additions\*\*/p' .claude/skills/codex-delegate/SKILL.md)"
printf '%s\n' "$skeleton" | grep -Fqx -- '- Traceability: LOW / HIGH' || fail 'skill short handoff must include traceability'
need '.claude/skills/codex-delegate/SKILL.md' '- Codex model:' 'skill handoff must carry model'
forbid '.claude/skills/codex-delegate/SKILL.md' 'gpt-' 'skill must read model IDs from AGENTS.md'
need 'AGENTS.md' '- Codex model (hard / review): gpt-6-sol' 'hard / review model missing from AGENTS.md'
need 'AGENTS.md' '- Codex model (standard / small fix): gpt-6-luna' 'standard / small fix model missing from AGENTS.md'
need '.claude/skills/codex-delegate/SKILL.md' 'if either line is missing or `[NOT CONFIGURED]`, ask the user rather than guessing' 'skill must ask about missing model configuration'
need '.claude/skills/vibe/SKILL.md' '- Codex reasoning effort:' 'vibe handoff must carry effort'
need 'scripts/codex-standard.sh' 'export CODEX_MODEL="$model" CODEX_REASONING_EFFORT="$effort"' 'auto-runner must forward skill-selected model'
need 'CLAUDE.md' 'Reuse that approval instead of asking again' 'do not redundantly ask already approved HIGH-risk scope'

echo 'PASS (doc-contract only; see docs/workflow/pilot-checklist.md for live checks): VIBE mode guardrails, single implementer rule, framework selection, risk gates, traceability and Codex ownership'
