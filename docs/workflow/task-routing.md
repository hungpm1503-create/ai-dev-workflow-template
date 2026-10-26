# Adaptive AI Development Workflow — complexity × risk × traceability

**Aim:** the smallest effective process. Claude Lead owns task classification, planning, handoff and independent review; Codex owns implementation. No automatic extra agent or planning ceremony.

## Classification

For each task, assess these **three independent dimensions**:

- **Complexity:** SMALL (localized), MEDIUM (multi-step, established architecture), LARGE (new design or coordinated slices).
- **Governance risk:** LOW or HIGH. HIGH may apply to even a one-line change. Examples: financial methodology, point-in-time rules, sensitive data and access controls, destructive migration, irreversible infrastructure or autonomous execution. Downstream project-specific HIGH-risk definitions and mandatory gates override this template.
- **Traceability:** LOW or HIGH. HIGH is appropriate when requirements, accepted decisions/ADRs, interfaces, versioned behavior and acceptance tests must remain linked across many changes. Large size alone does not imply HIGH traceability.

## Planning decision matrix

| Complexity | Risk | Traceability | Selected planning path | Required execution |
| --- | --- | --- | --- | --- |
| SMALL | LOW | LOW | **NONE** | Concise handoff → Codex → tests → brief Claude review |
| MEDIUM | LOW | LOW | **CLAUDE**, optionally **SUPERPOWERS** for meaningful ambiguity | One short plan → Codex → proportionate review |
| LARGE | LOW | LOW | **SUPERPOWERS preferred** (or one Claude plan when unavailable/not useful) | One canonical design/plan → Codex slices → independent review |
| ANY | LOW | HIGH | **SPEC KIT preferred** for durable traceable artifacts | One canonical spec/plan/decision trail → Codex → review |
| ANY | HIGH | ANY | **FULL GOVERNANCE + one project-allowed planning path** | Required independent reviews, explicit human gates, evidence-based tests/review and human acceptance when required |

**Risk determines mandatory safeguards; complexity and traceability determine planning.** High-risk does **not** universally mandate Spec Kit: choose Spec Kit for significant traceability, Superpowers/Claude planning otherwise **only when the project's already-approved rules allow**. If a downstream project requires formal Spec Kit for HIGH risk (e.g., InvestmentAgent), continue to follow it. Never silently replace a required gate with a lighter process.

## Claude chooses exactly one planning source

- **NONE:** no planning framework for a clear Small/Low task.
- **CLAUDE / SUPERPOWERS:** Claude produces one plan. If the relevant skills exist and add value, it may use `superpowers:brainstorming` and/or `superpowers:writing-plans` for Medium or Large work, then treats the output as the **one canonical artifact**. No compulsory multi-skill chain.
- **SPEC KIT:** use relevant specification/plan/tasks/consistency stages when a persistent requirements-to-decisions-to-tests chain is needed. No automatic full Spec Kit sequence just because a feature is LARGE.
- **FULL GOVERNANCE:** an **overlay, not a planning framework**. It still requires independent requirements/security/architecture review where applicable, real approvals, risk and rollback/verification evidence, and required acceptance regardless of planning tool.

**Never run Spec Kit planning and Superpowers brainstorming/writing-plans for the same task.** Only Claude Lead selects the planning framework. Codex consumes the approved handoff and approved single plan; it must not repeat planning. Do not run Superpowers subagent-driven development or `executing-plans` as a second implementation engine. Do not invoke `/speckit-implement` or `/speckit.implement`: Codex is the implementation owner. Superpowers TDD, systematic debugging and verification skills may assist Codex regardless of planning source.

For Medium/Low, one focused `plan-quality` review is generally enough. For Large/Low, review the one canonical design/spec proportionately. In a HIGH-risk project route, fulfill independent project gates but don't add another equivalent planning review without a specific uncovered risk.

## Mandatory FULL GOVERNANCE for HIGH-risk work

1. Identify the governing constitution/policies, accepted ADRs, approved specs/decisions and affected invariants. Never change an authority through a lower-priority handoff.
2. Record consequential requirements, exclusions, impacted data/contracts, risks, acceptance criteria, rollback/migration steps if relevant, and traceability needed for independent assessment.
3. **Obtain genuine human authorization** at the project's defined gates **before** protected execution, security/policy changes, migration, irreversible actions and acceptance. Editable `Status: APPROVED` text alone is not authentication.
4. Obtain required **independent requirements, security and architecture review** (a separate reviewer/context where project rules require it). An author cannot self-certify an independent review.
5. Delegate only the approved scope to Codex. Independently inspect diff and actual test/build evidence, with targeted and expanded checks appropriate to the impact. Report each criterion PASS, FAIL or UNVERIFIED.
6. Preserve explicit human acceptance where required. No automatic push, merge or deploy outside approval.
7. If a required review, skill or tool is unavailable, **stop that protected action and escalate**, seeking an explicitly approved equivalent if project rules permit. Never fake tool usage or silently downgrade.

## Examples

| Scenario | Classification | Planning | Governance |
| --- | --- | --- | --- |
| Small formatter bug | SMALL / LOW / LOW | NONE | Focused regression tests |
| Ordinary settings feature | MEDIUM / LOW / LOW | Claude plan, optional Superpowers | Normal review |
| New read-only dashboard across modules | LARGE / LOW / LOW | Superpowers design/planning preferred | One canonical plan and independent code review |
| Versioned shared API and many linked requirement decisions | LARGE / LOW / HIGH | Spec Kit preferred | Durable requirements ↔ ADRs ↔ tests |
| Point-in-time financial rule change | Any / HIGH / HIGH | Existing project-required Spec Kit | Existing independent/human HIGH-risk gates mandatory |
| Privacy access boundary or destructive migration | Any / HIGH / risk-assessed traceability | Spec Kit **or** Superpowers/Claude only if allowed by project | FULL GOVERNANCE always |

## Shared harness rules

Claude → one approved plan source → Codex → independent Claude Review → Human approval when needed. Keep v0.4 Working Memory, risk-based Verification and adopted Experience Library; checkpoints and instinct candidates are never approval or authoritative specs. Skip duplicate docs and unnecessary model calls. No new benchmark or background agent.

**Scope:** this template cannot override downstream project governance; sync to applications only through a separately reviewed project-specific change.
