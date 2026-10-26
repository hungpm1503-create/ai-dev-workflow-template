# Real Codex A/B Pilot — one small task

## Purpose

Compare a **fair concise v0.3-style progress note** against a **concise v0.4-style task checkpoint**, using a single tiny coding task and exactly the same source, tests and agent rules.

The baseline is *not* padded with synthetic history. This corrects a bias in the earlier synthetic 95.2%-smaller replay experiment: a good v0.3 handoff may already be short.

## Run offline preparation (CI, no model)

```bash
bash scripts/benchmark-codex-ab.sh --prepare-only
```

The fixture is `coupon.cjs`. It incorrectly stringifies null/numbers and accepts blanks/invalid codes. Each isolated temporary Git repo includes the same broken implementation and six `node --test` checks. Preparation verifies both initially FAIL and reports the exact context-file byte counts.

## Run two real Codex trials (explicit opt-in only)

From an authenticated Mac or Linux machine with Node.js and Codex CLI installed:

```bash
codex --version
codex login status
bash scripts/benchmark-codex-ab.sh --run
```

Optionally set `CODEX_AB_MODEL` to the **same available model** for both arms. The runner uses `codex exec --ephemeral --json --sandbox workspace-write` in **two independent local fixture repositories**. It does not require external packages or network in the model's coding workspace, and never modifies the application source.

Outputs live in ignored `.claude/benchmark-runs/ab.XXXXXX/`:

- `RESULTS.md`: per-arm CLI exit, local test exit, pass count, actual usage fields, elapsed seconds, input bytes.
- `baseline.events.jsonl`, `memory.events.jsonl`: private raw event traces (not committed).
- `baseline/` and `memory/`: independent Git repositories; inspect `git diff`.
- `*.after.log`: test evidence.

**Two Codex executions consume model allowance/tokens.** CI never performs them; the `--run` flag is explicitly opt-in.

## Model usage semantics

Codex JSONL `turn.completed.usage` reports `input_tokens`, `cached_input_tokens` and `output_tokens`; the runner aggregates these across completed turns. **Cached tokens are included in input**, not an additional charge. If usage is missing, the runner reports N/A rather than inventing a token count.

See [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode) for the documented `--json` event contract.

## Interpretation limits

- One trial per arm is exploratory: **do not claim quality or cost advantages** from one pair.
- Context lengths may be similar; a well-written handoff already avoids re-reading a complete chat.
- Prompt differences, model randomness, cache and order effects need repeated independent runs.
- A local checkpoint works only in the same working copy; no remote sync or actual cross-agent continuation is demonstrated.
- Human review must still examine diff, requirements and untested risks.

The criterion for advancing v0.4 is not merely fewer bytes: equal or better accepted test outcomes, no additional review errors, and a meaningful reduction in real model tokens or repeated context reads across multiple trials.
