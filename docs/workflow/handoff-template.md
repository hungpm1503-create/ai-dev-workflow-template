# Claude → Codex Task Handoff Template

For Medium/Large tasks; Small tasks can use a concise version. Save an approved instance at `.claude/handoffs/TASK-<id>.md`, which is gitignored. Use unique IDs rather than `latest.md`. Link to Spec Kit artifacts rather than duplicating their content.

## Task ID
TASK-<unique>

## Objective
[Single observable outcome]

## Approval status
[Approved scope / pending decision; do not invoke Codex for a blocked task]

## Verified context
[Actual paths/symbols, relevant project docs, and explicitly labeled assumptions]

## Scope
- In scope: [modules/outcomes]
- Out of scope: [exclusions if applicable]
- Constraints: [architecture/security/backward compatibility]

## Acceptance criteria and verification
| ID | Observable outcome | Verification method |
| --- | --- | --- |
| AC-01 | [Outcome] | [Test/build/manual check] |

## Implementation steps
1. [Actionable step]

## Verification commands
```bash
# Verified commands from actual project; otherwise mark UNVERIFIED
```

## Escalation triggers
[Missing requirements, material scope expansion, architecture/security changes, data loss risk]

## Codex completion contract
Return changed files, implementation summary, status of each AC (PASS/FAIL/UNVERIFIED), commands and exit codes, failure excerpts, skipped checks and risks. Never claim unrun checks passed.
