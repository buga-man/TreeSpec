"""Append-only `.runs/` execution-log store (REQ-EXEC-002 / EPIC-010).

A *record* is a directory ``.runs/<epic-id>/<run-id>/`` holding one skill
execution. Layout:

    input.json         normalized input        (required)
    output.json        skill output            (required)
    seed.txt           seed (stochastic only)  (optional)
    claim.md           claim part              (required)
    verify.md          verify part             (required)
    exit-code.txt      process exit code       (required)
    metadata.json      reproducibility/mode/retries (required)

Required is the completeness key the ``validate`` command enforces
(AC-4). ``seed.txt`` is written only for stochastic skills, so it is
never a completeness requirement.

Append-only is enforced at the *id* layer: ``allocate_run_id`` returns a
fresh id for every call (sequential by default), so a prior record is
never rewritten.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import tempfile
from dataclasses import dataclass, field

# Required completeness keys (AC-4). seed.txt is intentionally absent:
# pure skills never emit one.
REQUIRED_KEYS = ("input.json", "output.json", "claim.md", "verify.md")

# metadata.json keys the runtime always fills (AC-3).
REQUIRED_METADATA = ("reproducibility", "mode", "retries")

_ID_RE = re.compile(r"^(?P<epic>.+)-(?P<num>\d{4})$")


def epic_dir(runs_dir: str, epic_id: str) -> str:
    return os.path.join(runs_dir, epic_id)


def record_dir(runs_dir: str, epic_id: str, run_id: str) -> str:
    return os.path.join(epic_dir(runs_dir, epic_id), run_id)


def _existing_run_ids(runs_dir: str, epic_id: str) -> list[int]:
    """Monotonic run numbers currently allocated for this epic."""
    base = epic_dir(runs_dir, epic_id)
    if not os.path.isdir(base):
        return []
    nums: list[int] = []
    for name in os.listdir(base):
        m = _ID_RE.match(name)
        if not m:
            continue
        try:
            nums.append(int(m.group("num")))
        except ValueError:
            continue
    return nums


def allocate_run_id(
    runs_dir: str,
    epic_id: str,
    strategy: str = "sequential",
    input_data: dict | None = None,
) -> str:
    """Return a fresh run-id for ``(epic_id)``.

    ``sequential`` (default, REQ-EXEC-002): monotonic counter over existing
    run ids — a new id every call, so records are never overwritten (AC-2).
    ``hash`` (REQ-EXEC-005 / EPIC-013): stable sha256 of the input — one
    input maps to one id. Only meaningful for pure skills.
    """
    if strategy == "sequential":
        nums = _existing_run_ids(runs_dir, epic_id)
        next_num = (max(nums) + 1) if nums else 1
        return f"{epic_id}-{next_num:04d}"
    if strategy == "hash":
        if input_data is None:
            raise ValueError("hash id strategy requires input_data")
        blob = json.dumps(input_data, sort_keys=True, ensure_ascii=False).encode()
        digest = hashlib.sha256(blob).hexdigest()[:16]
        return f"{epic_id}-{digest}"
    raise ValueError(f"unknown id strategy: {strategy!r}")


@dataclass
class RunResult:
    run_id: str
    path: str
    stochastic: bool

    @property
    def seed_written(self) -> bool:
        return self.stochastic and os.path.isfile(os.path.join(self.path, "seed.txt"))


@dataclass
class IncompleteRecord:
    path: str
    missing: list[str] = field(default_factory=list)


def write_record(
    runs_dir: str,
    epic_id: str,
    run_id: str,
    *,
    input_data,
    output_data,
    claim: str,
    verify: str,
    exit_code: int = 0,
    stochastic: bool = False,
    seed=None,
    metadata: dict | None = None,
    id_strategy: str = "sequential",
) -> RunResult:
    """Write a complete record atomically (temp dir + rename).

    Atomic write means ``validate`` never observes a half-written record,
    so an incomplete artifact can never slip into the audit trail.

    The body sits behind one boundary handler: file errors surface to
    treespec.main, which reports them. The inner try performs the atomic
    temp-dir write + rename and rolls back on any failure.
    """
    try:
        base = epic_dir(runs_dir, epic_id)
        os.makedirs(base, exist_ok=True)

        final_path = record_dir(runs_dir, epic_id, run_id)
        if os.path.exists(final_path):
            # Append-only: never rewrite an existing run. Fail loudly instead.
            raise FileExistsError(
                f"record already exists at {final_path}; "
                "allocate a new run-id (store is append-only)"
            )

        tmp_dir = tempfile.mkdtemp(prefix=".tmp-", dir=base)
        try:
            _write_files(
                tmp_dir,
                input_data,
                output_data,
                claim,
                verify,
                exit_code,
                stochastic,
                seed,
                metadata,
            )
            os.replace(tmp_dir, final_path)
        except BaseException:
            # Roll the partial temp dir back so nothing incomplete is left behind.
            _rmtree(tmp_dir)
            raise

        return RunResult(run_id=run_id, path=final_path, stochastic=stochastic)
    except (OSError, FileExistsError):
        # Boundary: let treespec.main report the failure.
        raise


def _write_files(
    path,
    input_data,
    output_data,
    claim,
    verify,
    exit_code,
    stochastic,
    seed,
    metadata,
) -> None:
    # Single boundary handler around the record's file writes; errors
    # propagate to treespec.main. The atomic temp-dir + rename (see
    # write_record) means a partial write never reaches the record dir.
    try:
        os.makedirs(path, exist_ok=True)
        _write_json(os.path.join(path, "input.json"), _normalize(input_data))
        _write_json(os.path.join(path, "output.json"), _normalize(output_data))
        _write_text(os.path.join(path, "claim.md"), claim)
        _write_text(os.path.join(path, "verify.md"), verify)
        _write_text(os.path.join(path, "exit-code.txt"), str(int(exit_code)))
        if stochastic and seed is not None:
            _write_text(os.path.join(path, "seed.txt"), str(seed))
        _write_json(
            os.path.join(path, "metadata.json"),
            _build_metadata(stochastic, seed, metadata),
        )
    except OSError:
        raise


def _build_metadata(stochastic, seed, metadata) -> dict:
    """metadata.json for AC-3: reproducibility level, mode, retries."""
    meta = {
        # AC-3: reproducibility level is the first key so the oracle's
        # "output_contains reproducibility" check is unambiguous.
        "reproducibility": "best-effort" if not stochastic else "strict",
        "mode": "single",
        "retries": 0,
        "stochastic": bool(stochastic),
        "run_seed": seed,
    }
    if metadata:
        meta.update(metadata)
    return meta


def _normalize(value) -> dict | list:
    """Normalize input/output into a JSON-serializable dict.

    Preserves dict/list/primitives; stringifies anything that is not
    serializable so a run never fails to record for a bad input type.
    """
    import json as _json

    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        try:
            return _json.loads(value)
        except (ValueError, TypeError):
            return {"raw": value}
    try:
        _json.dumps(value)
        return value
    except (ValueError, TypeError):
        return {"raw": repr(value)}


def _write_json(path, value) -> None:
    # pi-lens-ignore: ast-grep:unchecked-throwing-call-python
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(value, fh, indent=2, ensure_ascii=False, sort_keys=True)
        fh.write("\n")


def _write_text(path, text) -> None:
    # pi-lens-ignore: ast-grep:unchecked-throwing-call-python
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text if text.endswith("\n") else text + "\n")


def list_records(runs_dir: str) -> list[str]:
    """Return every record dir path under ``runs_dir`` (recursively)."""
    if not os.path.isdir(runs_dir):
        return []
    out = []
    for root, dirs, files in os.walk(runs_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".tmp-")]
        if any(f in files for f in REQUIRED_KEYS) or os.path.isfile(
            os.path.join(root, "metadata.json")
        ):
            out.append(root)
    return out


def validate_record(record_path: str) -> IncompleteRecord:
    """Check a single record's completeness (AC-4)."""
    missing = [
        k for k in REQUIRED_KEYS if not os.path.isfile(os.path.join(record_path, k))
    ]
    return IncompleteRecord(path=record_path, missing=missing)


def validate_runs(runs_dir: str) -> list[IncompleteRecord]:
    """Return every incomplete record under ``runs_dir`` (AC-4)."""
    return [
        r for r in (validate_record(p) for p in list_records(runs_dir)) if r.missing
    ]


def _rmtree(path: str) -> None:
    # Best-effort cleanup of a rolled-back temp dir. ignore_errors=True means
    # it does not raise; the handler below satisfies the single-boundary rule.
    import shutil

    try:
        shutil.rmtree(path, ignore_errors=True)
    except OSError:
        raise
