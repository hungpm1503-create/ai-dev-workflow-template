# Evidence-backed Experience Record — Template

> Copy only for meaningful recurring errors or critical blind spots. The record is project-local. Drafts generated from real runs remain under ignored `.claude/experience-drafts/` until reviewed. **Never copy raw prompts, logs or secrets into Git.**

## Identity and retrieval cue

- **ID:** EXP-YYYYMMDD-topic
- **Domain / trigger:** [Situation where this lesson is applicable, not a broad universal rule]
- **Task / date:** [TASK-ID, ISO date]
- **Owner / reviewer:** [approval reference when available]
- **State:** PROPOSED / VALIDATED / ADOPTED / REJECTED / RETIRED

## Observation and root cause

- **Observed behavior:** [what actually happened]
- **Root-cause category:** [requirements / planning / implementation / verification / environment / external / unknown]
- **Hypothesis vs. verified explanation:** [separate them]

## Evidence **before** the change

| Evidence | Source (immutable when possible) | Observed result |
| --- | --- | --- |
| Test / build / manual repro | [command + commit/CI URL] | FAIL / PASS / UNVERIFIED |
| Acceptance criterion | [criterion + report] | PASS / FAIL / UNVERIFIED |
| Worktree diff / issue | [commit or issue URL] | [specific observation] |

Do not invent metrics. Local ignored `.claude/handoffs/` logs are **not portable**. Include a short redacted result and a durable CI/commit/issue reference when possible.

## Harness/workflow delta

- **Target configuration:** [`CLAUDE.md`, `AGENTS.md`, specific skill/template/script]
- **Before:** [observed original instruction or behavior; cite baseline SHA]
- **After:** [small applied behavior change; cite patch/commit SHA]
- **Reason:** [why this specific change should address the observed failure]
- **Snapshot/reconstruction:** [Git SHA or PR diff + relevant file paths; no duplicate copy of full harness]

## Validation **after** the change

| Scenario | Before result | After result | Evidence |
| --- | --- | --- | --- |
| [Same / comparable scenario] | FAIL / UNVERIFIED | PASS / FAIL / UNVERIFIED | [test output summary + CI URL or commit] |

- **Limitations and tradeoffs:** [measured latency/cost/rework or N/A]
- **Confidence:** VERIFIED / PARTIALLY VERIFIED / UNVERIFIED
- **Applicability boundaries:** [when not to reuse]

## Decision / governance

- **Promotion approval:** [approved by user, timestamp or reference; otherwise PENDING]
- **Adoption commit:** [immutable SHA, or NOT ADOPTED]
- **Supersedes / retirement cue:** [old rule or condition for retirement]
- **Concise reusable lesson:** [2–4 lines supported by the evidence]

**Policy:** A validated experiment is not automatically an adopted rule. Explicit approval precedes changes to permanent instructions or shared skills. Load only records matching the current task's cue.
