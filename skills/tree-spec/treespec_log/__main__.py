"""`python -m treespec_log` CLI entry point (REQ-EXEC-002 / EPIC-010).

Subcommands:
    run     write a .runs/<epic-id>/<run-id>/ record for one skill execution
    runs    inspect the .runs/ store (list | validate)

The `wrap` capability (wrapping arbitrary commands with auto-logging) is
NOT exposed here — it lives in `treespec_log.wrap` as an internal helper
and is invoked only through `skills/tree-spec/scripts/treespec-wrap.sh`,
which is the kit's single user-facing entry point for ad-hoc command
logging. That keeps the public CLI surface tight and makes
"wrap a command" a skill capability rather than a free-form CLI flag.

Errors are caught once at the boundary so the CLI fails loudly with a
clean message instead of a traceback (and never silently swallows a
real I/O error inside the store).
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from . import runs


def _cmd_run(args: argparse.Namespace) -> int:
    run_id = runs.allocate_run_id(
        args.runs_dir, args.epic, strategy=args.id_strategy, input_data=args.input
    )
    # Parse --attempts only when --chosen is set (REQ-EXEC-003 / AC-2, AC-3).
    attempts = None
    if args.chosen:
        attempts = list(args.attempts or [])
    # Parse --selection JSON only when --chosen is set; modes build a
    # per-mode default when it is omitted.
    selection = None
    if args.chosen and args.selection:
        try:
            selection = json.loads(args.selection)
        except ValueError as err:
            raise ValueError(f"--selection is not valid JSON: {args.selection!r}") from err
    result = runs.write_record(
        args.runs_dir,
        args.epic,
        run_id,
        input_data=args.input,
        output_data=args.output,
        claim=args.claim,
        verify=args.verify,
        exit_code=args.exit_code,
        stochastic=args.stochastic,
        seed=args.seed,
        metadata={"reproducibility": args.reproducibility},
        id_strategy=args.id_strategy,
        mode=args.mode,
        chosen=args.chosen,
        attempts=attempts,
        selection=selection,
    )
    # AC-1: print the record path so the oracle sees ".runs/".
    # Normalise to forward slashes so the path is identifiable even on
    # Windows, where os.path.join emits backslashes.
    print(result.path.replace(os.sep, "/"))
    print(f"run-id: {result.run_id}")
    if result.stochastic and result.seed_written:
        print(f"seed: {args.seed}")
    return 0


def _cmd_runs(args: argparse.Namespace) -> int:
    if args.runs_action == "list":
        for path in runs.list_records(args.runs_dir):
            print(path)
        return 0
    if args.runs_action == "validate":
        incomplete = runs.validate_runs(args.runs_dir)
        if incomplete:
            for rec in incomplete:
                print(f"INCOMPLETE {rec.path}: missing {rec.missing}")
            return 1
        print(f"OK: all records complete under {args.runs_dir}")
        return 0
    raise ValueError(f"unknown runs action: {args.runs_action!r}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="treespec_log", description="Execution log writer"
    )
    parser.add_argument(
        "--runs-dir", default=".runs", help="runs store root (default: .runs)"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="write a .runs/ record for one execution")
    run.add_argument("skill", help="skill slug being executed")
    run.add_argument("--epic", required=True)
    run.add_argument(
        "--input", default="{}", help="normalized input JSON (str or object)"
    )
    run.add_argument("--output", default="{}", help="skill output JSON (str or object)")
    run.add_argument("--claim", default="")
    run.add_argument("--verify", default="")
    run.add_argument("--exit-code", type=int, default=0)
    run.add_argument("--stochastic", action="store_true")
    run.add_argument("--seed", default=None, help="seed (best-of-n/consensus attempts)"
    )
    run.add_argument("--reproducibility", default="strict")
    run.add_argument(
        "--id-strategy", default="sequential", choices=["sequential", "hash"]
    )
    # Execution modes (REQ-EXEC-003 / EPIC-011). --mode defaults to single,
    # so existing invocations are unchanged. --chosen/--attempts/--selection
    # build the chosen/consensus record that links a group of attempts.
    run.add_argument(
        "--mode",
        default="single",
        choices=["single", "best-of-n", "consensus"],
        help="execution mode recorded in metadata.mode (default: single)",
    )
    run.add_argument(
        "--chosen", action="store_true",
        help="write the chosen/consensus record that links to --attempts",
    )
    run.add_argument(
        "--attempts", nargs="+", default=None,
        help="attempt run-ids grouped by a --chosen record (AC-2, AC-3)",
    )
    run.add_argument(
        "--selection", default=None,
        help="selection outcome JSON for the --chosen record (defaults per mode)",
    )
    run.set_defaults(func=_cmd_run)

    runs_cmd = sub.add_parser("runs", help="inspect the .runs/ store")
    runs_cmd.add_argument("runs_action", choices=["list", "validate"])
    runs_cmd.add_argument("--path", default=".runs", help="runs store to act on")
    runs_cmd.set_defaults(func=_cmd_runs)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (FileExistsError, ValueError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
