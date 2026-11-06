#!/usr/bin/env bash
# Optional local TokenEconomizer profile. No install or model calls.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

usage() {
  cat <<'USAGE'
Usage: bash scripts/token-economizer-pilot.sh COMMAND
Commands:
  configure      Opt in to envfacts + toolprune proposals; loopguard off
  loopguard-on   Enable experimental advisory loopguard explicitly
  loopguard-off  Disable loopguard
  status         Show current host's status
  doctor         Diagnose the local installation
  restore-tools  Restore plugin-pruned tools for current host
  disable        Disable all three mechanisms (restore separately if needed)
Env: TE_HOST=claude|codex (default claude), TE_CLI=/path/to/te (optional)
No tracked workflow rules, gates, hooks, or Codex wrapper are changed.
USAGE
}
if (( $# != 1 )); then usage >&2; exit 2; fi
cmd="$1"
case "$cmd" in
  configure|loopguard-on|loopguard-off|status|doctor|restore-tools|disable) ;;
  help|-h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
host="${TE_HOST:-claude}"
case "$host" in
  claude|codex) ;;
  *) echo 'ERROR: TE_HOST must be claude or codex.' >&2; exit 2 ;;
esac
te="${TE_CLI:-${HOME}/.tokeneconomizer/bin/te}"
if [[ ! -f "$te" || ! -x "$te" ]]; then
  echo "ERROR: TokenEconomizer launcher missing or not executable: $te" >&2
  echo 'Install upstream plugin and complete its first session before configuring.' >&2
  exit 3
fi
case "$cmd" in
  configure)
    "$te" --host "$host" config set microskills=envfacts toolprune=propose loopguard=off
    echo 'Configured: LLM-free envfacts, pruning proposals only, loopguard off.'
    ;;
  loopguard-on)
    "$te" --host "$host" config set loopguard=on
    echo 'Advisory loopguard on; it never replaces verification, timeout or approval.'
    ;;
  loopguard-off) "$te" --host "$host" config set loopguard=off ;;
  status) "$te" --host "$host" status ;;
  doctor) "$te" --host "$host" doctor ;;
  restore-tools)
    "$te" --host "$host" toolprune restore
    echo 'Restored plugin-managed tool restrictions for the selected host.'
    ;;
  disable)
    "$te" --host "$host" config set microskills=off toolprune=off loopguard=off
    echo 'Disabled mechanisms. Run restore-tools if pruning was applied earlier.'
    ;;
esac
