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

## Codex implementation difficulty (independent fourth dimension)

Classify implementation difficulty **only for delegated Codex work**, without a second model or classifier call:

| Difficulty | Signals | Default Codex |
| --- | --- | --- |
| EASY | Mechanical edits, simple local changes with known tests, straightforward data wiring | `gpt-6-luna`, medium reasoning |
| STANDARD | Multi-file changes, moderate integration, well-understood .NET/API logic and moderate debugging | `gpt-6-sol`, medium reasoning |
| HARD | Complex concurrency/PIT/revisions, difficult root cause, architectural dependencies, large cross-module constraints | `gpt-6-sol`, high reasoning |

Claude writes `- Codex difficulty: EASY / STANDARD / HARD` in the handoff's `## Route`. The wrapper uses deterministic mapping (no additional LLM). HIGH governance risk requires **at least STANDARD difficulty**, even for a short diff; HIGH does not automatically force HARD. If evidence reveals complexity beyond the chosen tier, stop and re-delegate using the appropriate tier rather than looping many times on an underpowered model. Verify exact model IDs available in your Codex account; use documented environment overrides for local alternatives.

## Permission and approval economy

A user's explicit instruction to implement a clearly scoped task is already authorization for its routine LOW-risk steps. For FULL GOVERNANCE, an explicit user decision covering consequential scope also counts as approval; cite it rather than asking again. If a material decision or HIGH-risk scope **has not** been authorized, gather related decisions into **one** approval request. Never infer approval from a handoff's editable `Status: APPROVED` marker.

Run low-risk/low-traceability first Codex delegations via `scripts/codex-standard.sh` under a narrow pre-approved permission rule. It rejects HIGH risk, disables network and enforces Quick check. For HIGH-risk use `scripts/codex-delegate.sh` with explicit authorization and independent review. `acceptEdits` removes routine editor prompts while protected path hooks and sensitive Bash operations retain permission requirements. No blanket bypass or unrestricted Codex-wrapper allowlist.

## VIBE mode

For SMALL or clear-path MEDIUM, LOW risk, LOW traceability. No formal plan or approval artifact is required; a Codex delegation uses the short handoff. Real verification (tests/lint/build with exit codes, PASS/FAIL/UNVERIFIED) is still mandatory.

**Implementer rule:** (1) Claude implements directly SMALL, LOW-risk changes — text/copy, styles, config values, or a local fix or small feature with simple logic in at most 3 source files (plus their tests), with no new module, schema, API or dependency. (2) Codex implements MEDIUM or larger work, anything beyond (1), and every HIGH-risk change, when Codex is installed. (3) If Codex is unavailable, Claude implements and says so. (4) Claude always reviews the diff and runs verification. An explicit user choice overrides (1)–(2).

**Exit triggers:** auth/permissions, payments or money, financial methodology or point-in-time rules, personal or sensitive data, destructive migrations or data deletion, infrastructure/deploy, secrets, autonomous execution, or anything the project's own rules (`AGENTS.md`, downstream governance) mark as HIGH risk; LARGE scope or HIGH traceability; or the same failure surviving three fix attempts. VIBE never applies to HIGH risk.

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
