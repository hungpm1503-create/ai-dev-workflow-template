# Claude → Codex Task Handoff Template

Use Medium/Large plan details here; Small tasks may use a compact version. Save a unique approved handoff at \`.claude/handoffs/TASK-<id>.md\` (gitignored). Do not reuse \`latest.md\`.

## Task ID
TASK-<unique>

## Objective
[One observable result]

## Approval status
Status: PENDING

Replace \`PENDING\` with the exact value \`APPROVED\` only after the relevant user/scope approval. The wrapper rejects anything other than \`Status: APPROVED\` in this section. This field is a process guard, **not authentication** or proof of a user's identity. Do not approve your own material decisions.

## Verified context
[Actual paths/symbols, relevant project docs and explicitly labeled assumptions]

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
\`\`\`bash
# Verified against the project or marked UNVERIFIED
\`\`\`

## Escalation triggers
[Missing requirements, unexpected scope, architectural/security changes, data loss]

## Completion contract
Codex reports changed files, each acceptance criterion PASS/FAIL/UNVERIFIED, actual commands and exit codes, failure excerpts and remaining risk. A zero CLI exit code does not prove the task passed.
