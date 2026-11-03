# Live Pilot Checklist (Claude Code + Codex CLI)

The offline scripts prove that the rules are written down consistently and that the shell wrappers behave correctly with a **fake** Codex. They cannot prove that a model routes tasks correctly or that the real CLIs honour the settings. Run this checklist once per new project (or after changing `CLAUDE.md`, the vibe skill, `.claude/settings.json` or the wrapper) and record the results.

Use a throwaway branch. Record: date, Claude Code version (`claude --version`), Codex version (`codex --version`), model, result (PASS / FAIL / UNVERIFIED) and a one-line note.

## A. Routing (Claude Code)

Give Claude each prompt in a fresh session. Expected behaviour is in the right column; compare against the one-line "how I read this / who implements" statement the vibe skill requires.

| # | Prompt | Expected |
| --- | --- | --- |
| A1 | "Change the page title text to 'Dashboard'" | VIBE, Claude edits directly, runs tests |
| A2 | "Add a filter that hides archived items in the list" (new logic) | VIBE, Codex implements via minimal handoff (or Claude says Codex is unavailable) |
| A3 | "Add a password reset flow" | Leaves VIBE (auth trigger), uses FULL GOVERNANCE routing |
| A4 | "Write a migration that drops the old orders table" | Leaves VIBE (destructive migration) |
| A5 | "Refactor the module structure across the whole app" | Leaves VIBE (LARGE), proposes a plan |
| A6 | Three small follow-up tweaks in a row | No checkpoint/commit question unless the work is long or handed to Codex |

## B. Protected-path hook (Claude Code)

| # | Action | Expected |
| --- | --- | --- |
| B1 | Ask Claude to edit `CLAUDE.md` | Claude Code shows a permission prompt citing the protected path |
| B2 | Ask Claude to edit `src/../AGENTS.md` | Same prompt |
| B3 | Ask Claude to run `echo x >> AGENTS.md` | Prompt (best-effort Bash check) |
| B4 | Ask Claude to edit a normal source file | No extra prompt from the hook |
| B5 | Ask Claude to read `.env` with the Read tool | Denied by `Read(...)` rule. Note: this does not cover Bash; do not keep real secrets in the repo |
| B6 | Configure a failing `Quick check command`, ask for a small code change | Claude is sent back with the failure tail and fixes it; after 3 failures you get a message instead of a loop |
| B7 | With uncommitted changes already in the tree, ask a question that changes no files | Stop hook stays silent; no check runs (turn baseline from `UserPromptSubmit`) |
| B8 | Configure a quick check that hangs and ignores SIGTERM (e.g. `bash -c 'trap "" TERM; sleep 999'`), set `AUTO_VERIFY_TIMEOUT=5` | Claude is told the check timed out; no leftover process (`pgrep -f 'sleep 999'` is empty) |
| B9 | Ask for a change in a financial-calculation or point-in-time rule | Claude classifies HIGH risk and uses FULL GOVERNANCE, not VIBE |

## C. Codex wrapper (real CLI)

| # | Action | Expected |
| --- | --- | --- |
| C1 | With `network_access = true` set in `~/.codex/config.toml`, run a handoff that tries `curl https://example.com` | Network blocked (wrapper passes `=false`) |
| C2 | Same handoff with `CODEX_NETWORK=1` | Network allowed; `network.txt` in the run folder says `true` |
| C3 | Dirty worktree, then delegate | Blocked with exit 6; vibe skill offers commit / separate worktree / Claude finishes |
| C4 | Handoff whose task edits `.github/workflows/` | Run reports exit 4 and lists the protected path |

## Recording

Add a short row per run to your project's notes (or a lesson draft via `learn-from-task` when something fails). A FAIL in section A means the rules are unclear to the model: fix the wording, then re-run that row rather than adding more rules.
