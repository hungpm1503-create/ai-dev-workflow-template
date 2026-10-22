# Claude → Codex Task Handoff Template

Use for Medium and Large tasks. Small tasks use a concise inline version. Link to existing Spec Kit artifacts rather than copying them.

## Objective
[Single concise outcome]

## Verified context
[Relevant paths/symbols, observed behavior and project docs; flag assumptions]

## Scope
- In scope: [modules/outcomes]
- Out of scope: [explicit exclusions, if relevant]
- Constraints: [architecture/security/backward compatibility]

## Acceptance criteria and verification
| ID | Observable outcome | Verification method |
| --- | --- | --- |
| AC-01 | [Outcome] | [Test/build/manual check] |
| AC-02 | [Outcome] | [Test/build/manual check] |

## Implementation steps
1. [Actionable step]
2. [Actionable step]

## Verification commands
```bash
# Commands verified against project, or explicitly mark UNVERIFIED
```

## Escalation triggers
[Missing requirements, material scope expansion, architecture/security changes, data loss risk]

## Codex completion contract
Return changed files, implementation summary, status of each AC (PASS/FAIL/UNVERIFIED), actual commands and exit codes, relevant failure excerpts, skipped checks, remaining risks. Never claim unrun tests passed.
