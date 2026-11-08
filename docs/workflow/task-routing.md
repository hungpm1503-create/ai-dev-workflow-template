# Adaptive AI Development Workflow — complexity × risk × traceability

## Classification

Assess **three independent dimensions**:

- **Complexity:** SMALL, MEDIUM, LARGE.
- **Governance risk:** LOW or HIGH. Project-specific HIGH-risk definitions and gates prevail.
- **Traceability:** LOW or HIGH. HIGH links requirements, decisions/ADRs, interfaces and tests; size alone does not determine it.

## Planning decision matrix

| Complexity | Risk | Traceability | Selected planning path | Required execution |
| --- | --- | --- | --- | --- |
| SMALL | LOW | LOW | **NONE** | **VIBE mode**: direct change or minimal Codex handoff → verification → report |
| MEDIUM | LOW | LOW | **CLAUDE**, optionally **SUPERPOWERS** | VIBE if clear; otherwise one plan → Codex → review |
| LARGE | LOW | LOW | **SUPERPOWERS preferred** | One canonical plan → Codex slices → review |
| ANY | LOW | HIGH | **SPEC KIT preferred** | Traceable plan → implementation → review |
| ANY | HIGH | ANY | **FULL GOVERNANCE + one project-allowed planning path** | Independent review, human gates, verification, acceptance |

## VIBE mode

For SMALL or clear-path MEDIUM, LOW risk, LOW traceability. No formal plan or approval artifact is required; a Codex delegation uses the short handoff. Real verification (tests/lint/build with exit codes, PASS/FAIL/UNVERIFIED) is still mandatory.

Implementation ownership is defined in `CLAUDE.md §2`; do not duplicate the rule in this routing reference.

**Exit triggers:** Follow `CLAUDE.md §1` for sensitive domains and project-specific HIGH-risk rules. LARGE scope, HIGH traceability or three failed fix attempts also leave VIBE; VIBE never applies to HIGH risk.

## One planning source

Choose NONE, CLAUDE, SUPERPOWERS or SPEC KIT based on the matrix; FULL GOVERNANCE is an overlay, not a planning framework. **Never run Spec Kit planning and Superpowers brainstorming/writing-plans for the same task.** Claude Lead selects the source. Codex consumes the approved handoff and plan; it does not repeat planning. Do not run Superpowers subagent-driven development or `executing-plans` as another implementation engine. Never use `/speckit-implement` or `/speckit.implement`.

## Mandatory FULL GOVERNANCE for HIGH risk

1. Identify governing policies, accepted decisions and affected invariants; a lower-priority handoff cannot change them.
2. Record requirements, exclusions, contracts, risks, acceptance criteria, traceability and rollback/migration steps where relevant.
3. Obtain genuine human authorization at required gates before protected execution, policy/security changes, migration, irreversible actions and acceptance. `Status: APPROVED` text alone is not authentication.
4. Obtain required independent requirements, security and architecture review. An author cannot self-certify an independent review.
5. Delegate only approved scope; independently inspect the diff and actual test/build evidence. Report PASS, FAIL or UNVERIFIED for each criterion.
6. Preserve required human acceptance. No automatic push, merge or deploy.
7. If a required review, skill or tool is unavailable, stop the protected action and escalate; never silently downgrade or fake tool use.

No new benchmark or background agent. Project governance takes precedence. See [routing notes and examples](task-routing-notes.md).
