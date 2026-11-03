# Example handoff (MEDIUM / LOW / LOW, Claude plan → Codex)

A filled-in copy of `docs/workflow/handoff-template.md` for reference. Real handoffs live in the ignored `.workflow/handoffs/` folder. For VIBE-mode tasks, the short form in `.claude/skills/vibe/SKILL.md` is enough.

## Task ID
TASK-EXAMPLE-001

## Route (keep concise)
- Complexity: MEDIUM
- Governance risk: LOW
- Traceability: LOW
- Selected planning path: CLAUDE
- Governance: STANDARD
- Single canonical source: the plan in "Implementation steps" below
- Required independent reviews and human approval evidence: PENDING (user confirms scope in chat)

## Objective
The todo list page shows a "Clear completed" button that removes all completed items and persists the change.

## Approval status
Status: PENDING

(Changed to `APPROVED` only after the user agrees to the scope above.)

## Verified context
- `src/components/TodoList.tsx` renders the list and already receives `todos` and `setTodos` (verified).
- `src/store/todos.ts` exports `saveTodos(todos)` that writes to localStorage (verified).
- Tests use Vitest + Testing Library in `src/components/__tests__/` (verified).
- Assumption: button hidden when there are no completed items (confirm with user if unsure).

## Scope
- In scope: button in `TodoList.tsx`, a `clearCompleted` helper in `src/store/todos.ts`, tests.
- Out of scope: undo, server sync, styling overhaul.
- Constraints: keep existing component API; no new dependency.

## Acceptance criteria and verification
| ID | Observable outcome | Verification method |
| --- | --- | --- |
| AC-01 | Clicking "Clear completed" removes only completed todos | Vitest component test |
| AC-02 | Result persists after reload | Unit test on `clearCompleted` + `saveTodos` call |
| AC-03 | Button hidden when no todo is completed | Vitest component test |
| AC-04 | Typecheck and lint pass | `npm run typecheck && npm run lint` |

## Implementation steps
1. Add `clearCompleted(todos)` to `src/store/todos.ts` returning the filtered list; unit-test it.
2. Render the button in `TodoList.tsx` when `todos.some(t => t.done)`; on click call `setTodos` and `saveTodos`.
3. Add component tests for AC-01 and AC-03.

## Verification commands
```bash
npm test -- --run src/components/__tests__/TodoList.test.tsx src/store
npm run typecheck
npm run lint
```

## Escalation triggers
Need to change the store's public API, add a dependency, or touch files outside scope.

## Completion contract
Codex reports changed files, each acceptance criterion PASS/FAIL/UNVERIFIED, actual commands and exit codes, failure excerpts and remaining risk. A zero CLI exit code does not prove the task passed.
