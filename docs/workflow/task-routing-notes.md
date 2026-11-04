# Task routing notes and examples

**Risk determines mandatory safeguards; complexity and traceability determine planning.** High-risk does **not** universally mandate Spec Kit: choose Spec Kit for significant traceability, Superpowers/Claude planning otherwise **only when the project's already-approved rules allow**. If a downstream project requires formal Spec Kit for HIGH risk, continue to follow it. Never silently replace a required gate with a lighter process.

## VIBE mode (default for everyday LOW-risk work)

VIBE is an **execution mode, not a planning framework**: SMALL, or MEDIUM with an obvious path, with LOW risk and LOW traceability. No formal plan or approval artifact is required; the user's chat request is the scope. A Codex delegation uses the short handoff in `.claude/skills/vibe/SKILL.md`. Real verification (tests/lint/build with exit codes, PASS/FAIL/UNVERIFIED) is still mandatory.

## Claude chooses exactly one planning source

- **NONE:** no planning framework for a clear Small/Low task.
- **CLAUDE / SUPERPOWERS:** Claude produces one plan. If the relevant skills exist and add value, it may use `superpowers:brainstorming` and/or `superpowers:writing-plans` for Medium or Large work, then treats the output as the **one canonical artifact**. No compulsory multi-skill chain.
- **SPEC KIT:** use relevant specification/plan/tasks/consistency stages when a persistent requirements-to-decisions-to-tests chain is needed. No automatic full Spec Kit sequence just because a feature is LARGE.
- **FULL GOVERNANCE:** an **overlay, not a planning framework**. It still requires independent requirements/security/architecture review where applicable, real approvals, risk and rollback/verification evidence, and required acceptance regardless of planning tool.

**Never run Spec Kit planning and Superpowers brainstorming/writing-plans for the same task.** Only Claude Lead selects the planning framework. When Codex implements, it consumes the approved handoff and approved single plan; it must not repeat planning. Do not run Superpowers subagent-driven development or `executing-plans` as a second implementation engine. Do not invoke `/speckit-implement` or `/speckit.implement`: use the implementer rule above. Superpowers TDD, systematic debugging and verification skills may assist Codex regardless of planning source.

For Medium/Low, one focused `plan-quality` review is generally enough. For Large/Low, review the one canonical design/spec proportionately. In a HIGH-risk project route, fulfill independent project gates but don't add another equivalent planning review without a specific uncovered risk.

## Examples

| Scenario | Classification | Planning | Governance |
| --- | --- | --- | --- |
| Small formatter bug | SMALL / LOW / LOW | NONE | Focused regression tests |
| Ordinary settings feature | MEDIUM / LOW / LOW | Claude plan, optional Superpowers | Normal review |
| New read-only dashboard across modules | LARGE / LOW / LOW | Superpowers design/planning preferred | One canonical plan and independent code review |
| Versioned shared API and many linked requirement decisions | LARGE / LOW / HIGH | Spec Kit preferred | Durable requirements ↔ ADRs ↔ tests |
| Point-in-time financial rule change | Any / HIGH / HIGH | Project-required Spec Kit | Existing independent/human HIGH-risk gates mandatory |
| Privacy access boundary or destructive migration | Any / HIGH / risk-assessed traceability | Spec Kit **or** Superpowers/Claude only if allowed by project | FULL GOVERNANCE always |

## Shared harness rules

Claude → one approved plan source when needed → implementer under the rule above → Claude Review → Human approval when needed. Keep v0.4 Working Memory, risk-based Verification and adopted Experience Library; checkpoints and instinct candidates are never approval or authoritative specs. Skip duplicate docs and unnecessary model calls. No new benchmark or background agent.

**Scope:** this template cannot override downstream project governance; sync to applications only through a separately reviewed project-specific change.
