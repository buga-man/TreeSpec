#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# treespec-wrap.sh — run any command and log the execution to .runs/.
#
# Self-contained: ships inside the `tree-spec` skill at
# skills/tree-spec/scripts/. The Python runtime lives in the same
# skill folder (skills/tree-spec/treespec_log/), so PYTHONPATH
# points directly at the skill — no walk-up, no external deps.
# Copy `skills/tree-spec/` to a consumer repo and this script keeps
# working without any setup.
#
# Usage:
#   treespec-wrap.sh --epic EPIC-X --claim "..." --verify "..." \
#                    [--timeout 300] -- <cmd> [args...]
#
# Exit code: the wrapped command's exit code (so a failing wrapped test
# makes the wrapper fail too). 2 on bad usage.
# ════════════════════════════════════════════════════════════════
set -u

# ── Resolve the skill root from this script's location ───────────
# This script lives at skills/tree-spec/scripts/treespec-wrap.sh;
# its parent is skills/tree-spec/, which is also where the
# `treespec_log` Python package lives. Set PYTHONPATH there so
# `python -m treespec_log wrap` resolves without any consumer-side
# configuration.
#
# Use BASH_SOURCE[0] (not $0): when invoked as `bash script.sh`,
# $0 is `bash`, not the script path. BASH_SOURCE[0] is always the
# script's own path regardless of how it was invoked.
#
# Override PYTHONPATH (don't prepend) — on Windows, mixing the Cygwin
# path we compute here with a Windows-style PYTHONPATH already in the
# environment confuses Python's parser (os.pathsep is `;` on Windows,
# so the embedded `:` inside the merged string breaks). Since the
# script always knows where its package lives, it always sets the
# exact right value.
SELF="${BASH_SOURCE[0]}"
SKILL_ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
export PYTHONPATH="$SKILL_ROOT"

# ── Translate argv into the Python CLI's expected form ────────────
# treespec_log has no `wrap` subcommand — wrap is an internal helper.
# Invoke it directly via `python -c` with the runtime's wrap_command.
# This keeps the public CLI surface tight (only `run` + `runs`) while
# still giving humans a single shell entry point.
if [ "$#" -lt 1 ]; then
    echo "treespec-wrap.sh: missing arguments (try --help)" >&2
    exit 2
fi

python -c '
import os, sys
import traceback
try:
    sys.path.insert(0, os.environ["PYTHONPATH"].split(os.pathsep)[0])
    from treespec_log.wrap import wrap_command, emit_summary
except Exception:
    traceback.print_exc()
    sys.exit(99)

# Re-parse argv into wrap_command kwargs. Keep parsing here so the
# user-facing surface stays in bash, not in argparse.
import argparse
p = argparse.ArgumentParser(prog="treespec-wrap.sh")
p.add_argument("--epic", required=True)
p.add_argument("--claim", default="")
p.add_argument("--verify", default="")
p.add_argument("--timeout", type=float, default=300.0)
p.add_argument("--cwd", default=None)
p.add_argument("--reproducibility", default="strict",
               choices=["strict", "best-effort"])
p.add_argument("--id-strategy", default="sequential",
               choices=["sequential", "hash"])
p.add_argument("--runs-dir", default=".runs")
p.add_argument("command", nargs=argparse.REMAINDER,
               help="command to run. Prefix with `--`.")
args = p.parse_args()
# REMAINDER includes the `--` itself; strip it so argv[0] is the
# real command, not a literal "--".
cmd = list(args.command)
if cmd and cmd[0] == "--":
    cmd = cmd[1:]
if not cmd:
    print("treespec-wrap.sh: empty command after `--`", file=sys.stderr)
    sys.exit(2)

result = wrap_command(
    runs_dir=args.runs_dir,
    epic_id=args.epic,
    claim=args.claim,
    verify=args.verify,
    command=cmd,
    timeout=args.timeout,
    cwd=args.cwd,
    reproducibility=args.reproducibility,
    id_strategy=args.id_strategy,
)
emit_summary(result)
sys.exit(int(result.exit_code))
' "$@"
rc=$?
if [ "$rc" = "2" ]; then
    echo "treespec-wrap.sh: bad usage — see arguments above" >&2
fi
exit "$rc"