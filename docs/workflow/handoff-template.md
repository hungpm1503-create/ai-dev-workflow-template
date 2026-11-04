# Claude → Codex Task Handoff Template

Use only the selected route's minimum plan details. Save a unique approved handoff at `.workflow/handoffs/TASK-<id>.md` (gitignored). Do not reuse `latest.md`. Reference the one approved plan; do not copy it.

## Lite form (STANDARD governance)

Use this form for STANDARD governance (about 30 lines maximum). FULL GOVERNANCE requires the full form below.

```markdown
## Task ID
TASK-<unique>
## Route
Complexity: SMALL/MEDIUM/LARGE; risk: LOW; traceability: LOW/HIGH; plan: NONE/CLAUDE/SUPERPOWERS/SPEC KIT (reference: <path>)
## Objective
<one observable result>
## Approval status
Status: APPROVED
## Files
- Read/change: <exact repository paths>
## Acceptance criteria and verification
- AC-01: <observable outcome> — <actual command or check>
## Constraints
- Out of scope: <explicit exclusions>
```

## Full form (FULL GOVERNANCE)

**Single source of truth:** reference only the one selected Claude plan, Superpowers design/plan, or Spec Kit artifact. HIGH risk additionally requires the project's FULL GOVERNANCE evidence and approvals. Claude may use Superpowers `brainstorming`/`writing-plans` for planning, but Codex never re-plans; Codex implements, potentially using Superpowers TDD/debugging/verification, not competing subagents or Spec Kit implementation.

## Task ID
TASK-<unique>

## Route (keep concise)
- Complexity: SMALL / MEDIUM / LARGE
- Governance risk: LOW / HIGH (project-specific overrides take precedence)
- Traceability: LOW / HIGH
- Selected planning path: NONE / CLAUDE / SUPERPOWERS / SPEC KIT
- Governance: STANDARD / FULL GOVERNANCE (HIGH risk overrides size)
- Single canonical source: [approved path or concise in-handoff plan]
- Required independent reviews and human approval evidence: [actual records or PENDING; never infer authorization]

## Objective
[One observable result]

## Approval status
Status: PENDING

Replace `PENDING` with the exact value `APPROVED` only after the relevant user/scope approval. The wrapper rejects anything other than `Status: APPROVED` in this section. This field is a process guard, **not authentication** or proof of a user's identity. Do not approve your own material decisions.

## Verified context
[Actual paths/symbols, relevant project docs and explicitly labeled assumptions]

## Files
[Exact paths to read or change]

## Scope
- In scope: [modules/outcomes]
- Out of scope: [exclusions]
- Constraints: [architecture/security/backward compatibility]

## Acceptance criteria and verification
| ID | Observable outcome | Verification method |
| --- | --- | --- |
| AC-01 | [Outcome] | [Test/build/manual check] |

## Implementation steps
1. [Actionable step]

## Verification commands
```bash
# Verified against the project or marked UNVERIFIED
```

## Escalation triggers
[Missing requirements, unexpected scope, architectural/security changes, data loss]

## Completion contract
Codex reports changed files, each acceptance criterion PASS/FAIL/UNVERIFIED, actual commands and exit codes, failure excerpts and remaining risk. A zero CLI exit code does not prove the task passed.
