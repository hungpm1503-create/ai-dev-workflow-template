# Adaptive Spec Kit Routing — complexity × governance risk

Goal: **minimum effective process**, not the maximum number of generated documents.
Classify **complexity and governance risk independently** before choosing tools. Project-specific rules override this template.

## Decision matrix

| Complexity | Risk | Route | Required planning and approval |
| --- | --- | --- | --- |
| SMALL | LOW | **Small** | Concise approved Codex handoff with acceptance checks; no formal spec/plan; proportionate review |
| MEDIUM | LOW | **Medium** | **One** concise Claude-owned plan (inline in handoff unless persistent notes genuinely help); one `plan-quality` pass; Codex + review |
| LARGE | LOW | **Spec Lite** | **One canonical lightweight requirements/design artifact** (existing spec/plan or a short new file), acceptance criteria and actionable slices; use only relevant Spec Kit commands **if they add value**; one proportionate planning review, Codex + independent review |
| ANY | HIGH | **Full Spec Kit / project's mandatory high-risk route** | Formal requirements and risk assessment, independent requirements review, human approval of consequential decisions before implementation, architecture/plan/tasks and consistency checks, Codex, independent verification and required human acceptance |

**HIGH risk always overrides complexity** (even a two-line change). A LARGE task is **not automatically HIGH**. When a project defines stricter high-risk gates, follow them unchanged.

Examples of potential HIGH risk: financial calculation/point-in-time policy, canonical data migration that could lose or reinterpret records, authentication/security or personal-data boundary changes, irreversible infrastructure operations, or autonomous actions. **These are prompts to inspect the project's definitions**, not authority to silently reclassify a protected operation as LOW. Ordinary UI styling, documentation and reversible refactors may remain LOW even when the task spans many files. If a classification is ambiguous, verify the affected boundaries and escalate until the risk is resolved; do not silently downgrade.

## Workflow details

### SMALL / LOW

Read only task-relevant context → concise handoff and acceptance checks → Codex implementation → targeted tests and brief review. **No Spec Kit, `plan-quality` artifact or mandatory Superpowers plan.** Apply `verify-change` proportionately when the diff has meaningful risk.

### MEDIUM / LOW

Claude writes a single short plan (objective, scope, constraints, steps, tests) in the handoff or in one existing planning file. Run `plan-quality` **once**, unless a real blocker needs revision. Delegate to Codex and independently review evidence. Do not create a separate Spec Kit spec, checklist and tasks document by default.

### LARGE / LOW — Spec Lite

Prefer an **existing canonical artifact**. If none exists, one short plan/spec suffices; it should cover problem, scope/exclusions, contracts and known decisions, key risks, testable acceptance criteria, implementation slices, and relevant verification. Add `tasks.md` only when many dependent handoffs require coordination. Do not reflexively run **specify → clarify → checklist → plan → tasks → analyze → converge**, independent requirements re-review or repeated approval ceremonies.

Spec Kit, if installed, is **optional here**: invoke only the specific stages that fill a genuine gap. A built-in `plan-quality` review or existing independently reviewed spec can satisfy the *single* planning quality gate; **do not repeat an equivalent check**. Codex remains the implementation owner.

### ANY / HIGH — Full Spec Kit / strict project route

Use the project's required formal sequence and human gates. Where a full route is defined, it typically includes specification → clarification as needed → independent requirements review/checklist → **human requirements approval before implementation planning or execution as required by the project** → architecture/plan/tasks → consistency analysis → Codex → independent verification → **human acceptance** before consequential changes/merge. Do not weaken existing HIGH-risk requirements in a downstream project merely because this template is lighter.

If Spec Kit is unavailable, **do not silently substitute Spec Lite or claim Spec Kit ran**. Stop the protected change and ask for an approved project-equivalent high-risk process and required human decisions. Avoid duplicate `plan-quality` if independent requirements/consistency gates already cover it; a separate review is useful only for a documented uncovered risk.

## Ownership and universal guardrails

- **Claude Lead:** classify, preserve a single approved source of truth, plan when appropriate, identify approval gates, delegate and independently review.
- **Codex:** implement **only** the approved handoff, run actual tests, report PASS/FAIL/UNVERIFIED. Do not invoke Spec Kit implementation commands.
- **Spec Kit:** optional planning/requirements tooling for Spec Lite, mandatory only when a project's selected HIGH-risk route requires it.
- **Superpowers:** optional relevant TDD/debugging/verification helpers, **not** a parallel planning system.
- **Working Memory:** ignored local task checkpoints, **never** approval or a competing spec; Experience Library candidates likewise remain untrusted until evidence and human adoption.
- **Approvals:** task handoff's `Status: APPROVED` is a process marker, **not proof of human authorization**. Consequential decisions and high-risk gates require real explicit human sign-off.
- **Quality:** actual diff, scope, acceptance criteria and risk-matched tests trump artifact count. Preserve project-specific financial, privacy, data, security and deployment boundaries.
- **Adaptation:** each downstream project defines its own HIGH-risk set and stricter gates. Template updates are not automatic syncs.

## Routing examples

| Task | Complexity | Risk | Route and why |
| --- | --- | --- | --- |
| Fix a local formatter with tests | SMALL | LOW | Small; no spec |
| Add a reversible settings page with several components | MEDIUM | LOW | Medium; concise plan |
| Build a new read-only dashboard using existing stable contracts | LARGE | LOW | Spec Lite; one canonical requirements/design artifact |
| Change a portfolio point-in-time selector | SMALL or MEDIUM | HIGH | Full project high-risk route despite size |
| Change credential authorization or migrate private transaction storage | Any | HIGH | Full project high-risk route; obtain necessary approvals |

## Lightweight evaluation

Record complexity **and** risk classification, chosen route, completed reviews, number of artifacts, actual test results, rework and time/tokens **only when data exists**. If a task uses more workflow stages than the matrix requires, document the uncovered risk justifying each extra stage. No new benchmark or background agent is required.
