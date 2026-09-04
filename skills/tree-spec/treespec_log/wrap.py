"""Wrap arbitrary commands with automatic `.runs/` logging.

REQ-EXEC-002 / EPIC-010 (extension). ``wrap`` is the convenient sibling of
``run``: instead of the caller building the record themselves, they hand
``wrap`` a shell command + a claim/verify summary, and ``wrap`` allocates
a fresh run-id, runs the command, captures its output, and writes a
complete record via the same ``runs.write_record`` machinery ``run`` uses.

Append-only is preserved: ``wrap`` always allocates a new sequential
run-id, even on failure, so failed runs are also logged — a failed run
is still a run, and removing it would let the audit trail silently drop
incidents.

Boundary handling: file I/O is delegated to ``runs.write_record`` (which
sits behind its own single ``try/except OSError``). Subprocess I/O is
captured to ``PIPE`` and re-emitted to the user's stream only as a
one-line summary on the way out; the full captured output lives in
``output.json``.
"""

from __future__ import annotations

import dataclasses
import os
import shlex
import subprocess
import sys
from typing import Sequence

from . import runs


@dataclasses.dataclass
class WrapResult:
    run_id: str
    path: str
    exit_code: int
    duration_s: float
    stdout_bytes: int
    stderr_bytes: int


def wrap_command(
    runs_dir: str,
    epic_id: str,
    claim: str,
    verify: str,
    command: Sequence[str],
    *,
    timeout: float = 300.0,
    cwd: str | None = None,
    env: dict | None = None,
    reproducibility: str = "strict",
    id_strategy: str = "sequential",
) -> WrapResult:
    """Run ``command``, capture its output, write a `.runs/` record.

    The record is written regardless of the command's exit code; the
    ``exit-code.txt`` field is the source of truth for success/failure.
    A non-zero timeout raises ``subprocess.TimeoutExpired`` — caller's
    boundary catches it.
    """
    if not command:
        raise ValueError("wrap: command must be non-empty")

    # Allocation MUST happen before the subprocess so a run-id exists even
    # if the command is killed by timeout or signal — the audit trail
    # never observes an execution without a record id.
    run_id = runs.allocate_run_id(
        runs_dir, epic_id, strategy=id_strategy
    )

    started = _monotonic()
    try:
        proc = subprocess.run(
            list(command),
            cwd=cwd,
            env=env,
            stdin=None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=None if timeout == 0 else timeout,
            check=False,
        )
    except FileNotFoundError as exc:
        # Binary missing or path typo — record an honest failure so the
        # audit trail reflects what actually happened.
        proc = subprocess.CompletedProcess(
            args=list(command),
            returncode=127,
            stdout=b"",
            stderr=str(exc).encode("utf-8", errors="replace"),
        )
    except subprocess.TimeoutExpired as exc:
        # Timed-out runs are still runs. Capture whatever partial output
        # the process flushed before being killed, and surface a non-zero
        # exit so the audit trail reflects the timeout.
        proc = subprocess.CompletedProcess(
            args=list(command),
            returncode=124,  # conventional timeout exit code
            stdout=exc.stdout or b"",
            stderr=(exc.stderr or b"") + b"\n[wrap] command timed out\n",
        )
    finished = _monotonic()

    output_data = {
        "stdout": _safe_decode(proc.stdout),
        "stderr": _safe_decode(proc.stderr),
        "exit_code": int(proc.returncode),
        "argv": list(command),
        "duration_s": round(finished - started, 3),
    }

    result = runs.write_record(
        runs_dir,
        epic_id,
        run_id,
        input_data={"argv": list(command), "cwd": cwd, "env_keys": sorted(env) if env else None},
        output_data=output_data,
        claim=claim,
        verify=verify,
        exit_code=int(proc.returncode),
        stochastic=False,
        seed=None,
        metadata={"reproducibility": reproducibility, "mode": "single"},
        id_strategy=id_strategy,
    )

    return WrapResult(
        run_id=run_id,
        path=result.path,
        exit_code=int(proc.returncode),
        duration_s=round(finished - started, 3),
        stdout_bytes=len(proc.stdout or b""),
        stderr_bytes=len(proc.stderr or b""),
    )


def _monotonic() -> float:
    import time

    return time.monotonic()


def _safe_decode(blob: bytes) -> str:
    if not blob:
        return ""
    try:
        return blob.decode("utf-8")
    except UnicodeDecodeError:
        return blob.decode("utf-8", errors="replace")


def format_summary(result: WrapResult) -> str:
    """One-line summary for the CLI to print after a wrap.

    Mirrors the shape of `treespec run`: record path, run-id, then
    wrap-specific metadata (exit code + duration).
    """
    path = result.path.replace(os.sep, "/")
    return (
        f"{path}\n"
        f"run-id: {result.run_id}\n"
        f"command-exit: {result.exit_code}\n"
        f"duration-s: {result.duration_s}"
    )


def emit_summary(result: WrapResult, stream=sys.stdout) -> None:
    """Print the summary to ``stream`` (default: stdout)."""
    print(format_summary(result), file=stream)


def quote_argv(argv: Sequence[str]) -> str:
    """Best-effort pretty-print of the command for human display."""
    try:
        return shlex.join(argv)
    except AttributeError:  # pragma: no cover — py<3.8 fallback
        return " ".join(shlex.quote(a) for a in argv)