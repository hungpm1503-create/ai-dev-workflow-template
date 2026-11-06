# TokenEconomizer: opt-in, reversible pilot

Upstream: [microsoft/TokenEconomizer](https://github.com/microsoft/TokenEconomizer) (Apache-2.0). This repository does **not** vendor or automatically install that plugin, its hooks or its model calls. Its optional integration is local configuration and an offline contract test. It is not a dependency for normal Claude → Codex development.

## Rules and ownership

| Layer | Authority |
| --- | --- |
| User decisions, `AGENTS.md`, `CLAUDE.md`, specs and Full Governance | Canonical; never overridden by plugin output |
| Protected-path permissions, independent review, Stop auto-verification, Codex wrapper sandbox/timeout | Mandatory safeguards; unchanged |
| `workflow-memory.sh` | Per-task working state and evidence exchanged between Claude and Codex |
| `learn-from-task` | Permanent approved project lessons, only after validation and human adoption |
| TokenEconomizer micro-skills | Untrusted short **environmental hints**, not permission, acceptance, policy or code review |

The plugin learns **separately for Claude and Codex**. Its hints are not cross-agent working memory. A suggested "fact" cannot change test commands or authorize skipping quality gates. Optimization errors may fail open, but security and verification gates may **not**.

## Install only if you explicitly want a local trial

1. Work in a disposable checkout or branch. Review [upstream installation](https://github.com/microsoft/TokenEconomizer#quick-start), its Python 3.10+ requirement and [supported CLI versions](https://github.com/microsoft/TokenEconomizer#supported-versions). Record the **exact upstream commit SHA** and Claude/Codex versions. Do not copy third-party hooks into this repository's tracked `.claude/settings.json` or rewrite `scripts/codex-delegate.sh`.
2. Install the upstream plugin by its own instructions on an approved local machine. The upstream defaults turn on auto-pruning and loopguard; **configure before running substantive tasks**. The launcher at `~/.tokeneconomizer/bin/te` typically exists after the first session. If absent, the helper exits with a clear error rather than installing anything.
3. From the target repository run:

   ```bash
   bash scripts/token-economizer-pilot.sh configure
   bash scripts/token-economizer-pilot.sh doctor
   bash scripts/token-economizer-pilot.sh status
   TE_HOST=codex bash scripts/token-economizer-pilot.sh status
   ```

   The chosen safety profile is `microskills=envfacts`, `toolprune=propose`, `loopguard=off`. It uses **zero additional model calls to synthesize facts**, never automatically applies a pruning proposal, and does not activate the experimental loop detector. Configuration is local to TokenEconomizer's store, not committed to git, and applies to both agents in this repository. Use `TE_HOST=codex` to inspect Codex-specific state; observations are per host.

4. Inspect proposals with the upstream `toolprune` command. **Do not run `toolprune apply` in this pilot.** On Claude Code pruning targets individual tools; on Codex it targets capability bundles that may include collaboration/subagents. If you previously applied pruning, restore it explicitly.
5. Only on an isolated failure-loop fixture, and only after reviewing upstream fixes, try:

   ```bash
   bash scripts/token-economizer-pilot.sh loopguard-on
   # Run a controlled, non-destructive pilot task
   bash scripts/token-economizer-pilot.sh loopguard-off
   ```

   This uses advisory `nudge` behavior. Loopguard never forcibly stops agents, and its judge/redirect can make **paid model calls**. It never replaces verification, human approval, timeout or escalation.

6. Roll back:

   ```bash
   bash scripts/token-economizer-pilot.sh disable
   bash scripts/token-economizer-pilot.sh restore-tools
   TE_HOST=codex bash scripts/token-economizer-pilot.sh restore-tools
   ```

   Then uninstall the plugin via upstream instructions if desired. `TE_DISABLE=1` disables it for a **single** agent session; it does not uninstall the plugin or restore previously disabled tools.

## Known risks and compatibility (reviewed 2026-11-06)

- [Upstream issue #142](https://github.com/microsoft/TokenEconomizer/issues/142) reports lost loopguard tool-call state during **parallel** tool execution. This is why the safe profile leaves loopguard off until validated; no stuck/not-stuck signal can prove a task succeeded.
- [Upstream issue #131](https://github.com/microsoft/TokenEconomizer/issues/131) reports Claude side-call errors with certain `verbose: true` configurations. Use `envfacts` rather than an LLM proposer for the initial experiment.
- Claude Code and Codex each use third-party SessionStart/Stop and tool hooks. The existing repo already relies on `UserPromptSubmit`, `PreToolUse`, and `Stop`. Do **not** combine or replace the project's safety hooks with optimization hooks. If the plugin interferes, disable/uninstall **the plugin**, not the security gates.
- The Codex wrapper runs `codex exec` in a sandbox and validates paths afterward. It should keep doing so regardless of optional plugin presence. Headless Codex hook notices are not displayed: query the upstream `te status` after a run instead.
- The plugin reads session logs and retains local state under `~/.tokeneconomizer`. When using its LLM features, digests are sent through your own agent login and may contain commands, file basenames or redacted errors. Do not pilot with secrets, customer/financial data or untrusted repositories; review [upstream privacy details](https://github.com/microsoft/TokenEconomizer/blob/main/docs/PLUGIN.md).

## Benchmark: baseline vs safe pilot

Use equivalent tasks on the **same repository state**, with matched model, effort, CLI version, test budget and environment. Alternate repeated runs and distinguish *cold* from *warm* learned state. Only the pilot group has the external plugin configured; do **not** compare unrelated task batches or assume the research's percentage transfers to this template.

Record:

| Metric | Minimum evidence |
| --- | --- |
| Identity | Task ID, repo SHA, agent/model/effort, CLI/plugin version, profile and warm/cold |
| Billing | Cached input, uncached input, output and other charged tokens; prices and plugin's **own** model-call overhead |
| Reliability | Acceptance criteria, actual commands/exit codes, PASS/FAIL/UNVERIFIED and independent review |
| Efficiency | Elapsed time, number of agent/model calls, failing/repeated tests, tool suggestions |
| Adverse effects | False loop interventions, unexpected tool unavailability, approvals, safety-hook failures |

Use cost pricing per token class; `saving_pct = 100 * (baseline_cost - pilot_cost) / baseline_cost`, where pilot cost **includes plugin overhead**. Report per-task paired changes, overall pass rate, and elapsed time. Never treat low cached-token count or an agent exit code 0 as evidence of correct implementation.

**Promotion criteria:** demonstrated net savings without lower pass/acceptance rate or regressions in approvals, hooks, review and latency. Keep the plugin optional until a real live pilot meets those criteria. The offline test only verifies the profile's **CLI arguments**, not upstream runtime or real model behavior.

Offline validation (no model or network):

```bash
bash scripts/validate-workflow.sh
bash scripts/test-token-economizer-pilot.sh
```

See [live pilot checklist](pilot-checklist.md) for the separate human verification of Claude Code/Codex behaviors.
