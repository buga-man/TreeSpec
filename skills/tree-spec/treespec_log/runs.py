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
from datetime import datetime, timezone

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
    try:
        names = os.listdir(base)
    except OSError:
        return []
    nums: list[int] = []
    for name in names:
        m = _ID_RE.match(name)
        if not m:
            continue
        try:
            nums.append(int(m.group("num")))
        except ValueError:
            continue
    return nums


# Execution-mode groups (REQ-EXEC-003 / EPIC-011). A best-of-n /
# consensus *attempt* shares an (epic, mode) group with its siblings; the
# --chosen record is not an attempt and is exempt from seed-distinctness.
_MODE_GROUP = ("best-of-n", "consensus")


def _iter_attempts(runs_dir: str, epic_id: str, mode: str) -> list[str]:
    """Return run-ids of attempts in the same (epic, mode) group."""
    base = epic_dir(runs_dir, epic_id)
    if not os.path.isdir(base):
        return []
    ids: list[str] = []
    try:
        names = os.listdir(base)
    except OSError:
        return ids
    for name in names:
        if not _ID_RE.match(name):
            continue
        meta_path = os.path.join(base, name, "metadata.json")
        if not os.path.isfile(meta_path):
            continue
        try:
            with open(meta_path, encoding="utf-8") as fh:
                meta = json.load(fh)
        except (ValueError, OSError):
            continue
        if meta.get("mode") == mode and not meta.get("chosen"):
            ids.append(name)
    return ids


def _seed_of(runs_dir: str, epic_id: str, run_id: str):
    """Seed recorded for a run (metadata.run_seed / seed.txt), or None."""
    meta_path = os.path.join(epic_dir(runs_dir, epic_id), run_id, "metadata.json")
    if os.path.isfile(meta_path):
        try:
            with open(meta_path, encoding="utf-8") as fh:
                meta = json.load(fh)
            if meta.get("run_seed") is not None:
                return meta.get("run_seed")
        except (ValueError, OSError):
            pass
    seed_path = os.path.join(epic_dir(runs_dir, epic_id), run_id, "seed.txt")
    if os.path.isfile(seed_path):
        try:
            with open(seed_path, encoding="utf-8") as fh:
                return fh.read().strip()
        except OSError:
            return None
    return None


def _check_mode_seed(runs_dir, epic_id, mode, seed, chosen) -> None:
    """seed-distinctness (AC-4): a best-of-n / consensus attempt must carry
    a seed that is distinct within its (epic, mode) group."""
    if chosen or mode not in _MODE_GROUP:
        return
    if seed is None:
        raise ValueError(f"{mode} attempt requires --seed")
    for other in _iter_attempts(runs_dir, epic_id, mode):
        if _seed_of(runs_dir, epic_id, other) == seed:
            raise ValueError(
                f"seed {seed!r} already used by attempt {other} in "
                f"{epic_id}/{mode}; best-of-n/consensus attempts need distinct seeds"
            )


def _check_attempts(runs_dir, epic_id, mode, attempts, chosen) -> None:
    """chosen/consensus record linking (AC-2, AC-3): --attempts run-ids must
    exist and share the record's epic + mode."""
    if not chosen:
        return
    if not attempts:
        raise ValueError("chosen record requires --attempts <ids>")
    seen = set()
    for run_id in attempts:
        meta_path = os.path.join(epic_dir(runs_dir, epic_id), run_id, "metadata.json")
        if not os.path.isfile(meta_path):
            raise ValueError(f"--attempts run-id {run_id!r} does not exist")
        try:
            with open(meta_path, encoding="utf-8") as fh:
                meta = json.load(fh)
        except (ValueError, OSError) as err:
            raise ValueError(f"--attempts run-id {run_id!r} is not readable") from err
        if meta.get("mode") != mode:
            raise ValueError(
                f"--attempts run-id {run_id!r} is mode {meta.get('mode')!r}, "
                f"not {mode!r}"
            )
        if meta.get("chosen"):
            raise ValueError(f"--attempts run-id {run_id!r} is itself a chosen record")
        seen.add(run_id)
    if len(seen) != len(attempts):
        raise ValueError("--attempts contains duplicate run-ids")


def input_hash(input_data) -> str:
    """Stable 16-hex digest of the normalized input (REQ-EXEC-005).

    Same canonical form as the id derivation: sorted keys, no ASCII
    escaping — one logical input maps to one base id / chain.
    """
    blob = json.dumps(input_data, sort_keys=True, ensure_ascii=False).encode()
    return hashlib.sha256(blob).hexdigest()[:16]


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
        # Collision chaining / open addressing (REQ-EXEC-005, decision
        # 2026-09-04): the base id stays stable per input; a repeat run
        # probes the next free slot of the same chain (<base>-2, -3, …).
        base = f"{epic_id}-{input_hash(input_data)}"
        candidate, n = base, 2
        while os.path.exists(record_dir(runs_dir, epic_id, candidate)):
            candidate = f"{base}-{n}"
            n += 1
        return candidate
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


# ── Flaky detection (REQ-EXEC-004 / EPIC-012) ────────────────────
QUARANTINE_SUBDIR = "quarantine"
LIFT_TIMEOUT_DAYS = 30
MAX_QUARANTINE_RUNS = 10


@dataclass
class SkillRate:
    skill: str
    failed_runs: int
    total_runs: int
    failed_run_ids: list[str] = field(default_factory=list)

    @property
    def rate(self) -> float:
        return self.failed_runs / self.total_runs if self.total_runs else 0.0


def quarantine_path(runs_dir: str, skill_id: str) -> str:
    return os.path.join(runs_dir, QUARANTINE_SUBDIR, f"{skill_id}.json")


def list_epic_records(runs_dir: str, epic_id: str) -> list[tuple[str, dict, int]]:
    """All records of one epic regardless of id format: (run_id, metadata, exit_code).

    Unlike ``_epic_attempts`` this does NOT filter by the sequential id
    shape — hash-strategy ids (``<base>``, ``<base>-2``, ...) are visible too,
    so an agent can read back its own work for reflection.
    ``chosen`` records are included (they are part of the history)."""
    base = epic_dir(runs_dir, epic_id)
    if not os.path.isdir(base):
        return []
    try:
        names = sorted(os.listdir(base))
    except OSError:
        return []
    out: list[tuple[str, dict, int]] = []
    for name in names:
        meta_path = os.path.join(base, name, "metadata.json")
        if not os.path.isfile(meta_path):
            continue
        try:
            with open(meta_path, encoding="utf-8") as fh:
                meta = json.load(fh)
        except (ValueError, OSError):
            continue
        exit_path = os.path.join(base, name, "exit-code.txt")
        try:
            with open(exit_path, encoding="utf-8") as fh:
                code = int(fh.read().strip())
        except (OSError, ValueError):
            code = 0
        out.append((name, meta, code))
    return out


def _epic_attempts(runs_dir: str, epic_id: str) -> list[tuple[str, dict, int]]:
    """Non-chosen attempt records of one epic: (run_id, metadata, exit_code).

    ``chosen`` records link attempts and are not attempts themselves, so they
    never count toward total_runs (feasibility risk #1). Only sequential-shape
    ids count as attempts — flaky semantics (REQ-EXEC-004) apply to the
    default strategy; hash records stay visible via ``list_epic_records``."""
    return [
        t
        for t in list_epic_records(runs_dir, epic_id)
        if _ID_RE.match(t[0]) and not t[1].get("chosen")
    ]


def report_epic(runs_dir: str, epic_id: str) -> list[SkillRate]:
    """Aggregate failed_runs / total_runs per skill over one epic's attempts."""
    if not os.path.isdir(epic_dir(runs_dir, epic_id)):
        raise ValueError(f"no runs recorded for epic {epic_id!r}")
    rates: dict[str, SkillRate] = {}
    for run_id, meta, code in _epic_attempts(runs_dir, epic_id):
        skill = str(meta.get("skill", "unknown"))
        rate = rates.setdefault(
            skill, SkillRate(skill=skill, failed_runs=0, total_runs=0)
        )
        rate.total_runs += 1
        if code != 0:
            rate.failed_runs += 1
            rate.failed_run_ids.append(run_id)
    return [rates[k] for k in sorted(rates)]


def save_quarantine(
    runs_dir: str,
    skill_id: str,
    *,
    tolerance: float,
    rate: SkillRate,
    epic_id: str,
) -> str:
    """Create or update the quarantine entry; returns the file path.

    First quarantine creates the file (keeps ``quarantined_at``); a later
    flaky epic updates rate/epic and appends failed run-ids (capped at the
    last 10)."""
    path = quarantine_path(runs_dir, skill_id)
    entry: dict | None = None
    if os.path.isfile(path):
        try:
            with open(path, encoding="utf-8") as fh:
                entry = json.load(fh)
        except (ValueError, OSError):
            entry = None
    if entry is None:
        entry = {
            "skill": skill_id,
            "quarantined_at": datetime.now(timezone.utc).isoformat(),
            "clean_epics": 0,
        }
    entry["flaky_tolerance"] = tolerance
    entry["rate"] = {"failed_runs": rate.failed_runs, "total_runs": rate.total_runs}
    entry["epic"] = epic_id
    runs_ = list(entry.get("runs", [])) + [
        r for r in rate.failed_run_ids if r not in entry.get("runs", [])
    ]
    entry["runs"] = runs_[-MAX_QUARANTINE_RUNS:]
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        _write_json(path, entry)
    except OSError:
        # Boundary: let the CLI report the failure (same pattern as write_record).
        raise
    return path


def load_quarantine(runs_dir: str, skill_id: str) -> dict | None:
    path = quarantine_path(runs_dir, skill_id)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (ValueError, OSError):
        # Unreadable/corrupt entry: treat as absent; the release path then
        # fails loudly on the missing quarantined_at instead of a traceback.
        return None


def release_quarantine(
    runs_dir: str,
    skill_id: str,
    *,
    clean: int | None = None,
    manual: bool = False,
) -> str:
    """Release a quarantine entry (deletes the JSON); returns the reason.

    No flags — 30-day time-out only. ``clean=N`` trusts the agent runtime's
    consecutive-clean-epic count (documented protocol). ``manual`` is
    unconditional."""
    path = quarantine_path(runs_dir, skill_id)
    if not os.path.isfile(path):
        raise ValueError(f"{skill_id} not quarantined")
    if manual:
        reason = "manual"
    elif clean is not None:
        reason = f"clean-epics:{clean}"
    else:
        entry = load_quarantine(runs_dir, skill_id) or {}
        try:
            since = datetime.fromisoformat(entry["quarantined_at"])
        except (KeyError, TypeError, ValueError):
            raise ValueError(
                f"quarantine for {skill_id!r} has no valid quarantined_at"
            ) from None
        age_days = (datetime.now(timezone.utc) - since).total_seconds() / 86400
        if age_days < LIFT_TIMEOUT_DAYS:
            raise ValueError(
                f"{skill_id} quarantined {age_days:.1f} days ago "
                f"(< {LIFT_TIMEOUT_DAYS}); use --clean <N> or --manual to release early"
            )
        reason = "timeout"
    try:
        os.remove(path)
    except OSError:
        # Boundary: let the CLI report the failure.
        raise
    return reason


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
    mode: str = "single",
    chosen: bool = False,
    attempts: list | None = None,
    selection=None,
    skill: str | None = None,
) -> RunResult:
    """Write a complete record atomically (temp dir + rename).

    Atomic write means ``validate`` never observes a half-written record,
    so an incomplete artifact can never slip into the audit trail.

    Execution mode (REQ-EXEC-003 / EPIC-011):
      * ``mode`` ∈ {single, best-of-n, consensus} is recorded in
        ``metadata.mode`` (defaults to ``single`` for backwards compatibility).
      * A best-of-n / consensus **attempt** (``chosen=False``) needs a
        ``seed`` and it must be distinct within the epic + mode group
        (seed-distinctness, AC-4). The ``--chosen`` record is exempt.
      * A ``chosen`` record links to its attempts (``metadata.attempts``)
        and records the selection outcome (``metadata.selection``).

    The body sits behind one boundary handler: validation and file errors
    surface to treespec.main, which reports them. The inner try performs the
    atomic temp-dir write + rename and rolls back on any failure.
    """
    try:
        _check_mode_seed(runs_dir, epic_id, mode, seed, chosen)
        _check_attempts(runs_dir, epic_id, mode, attempts, chosen)

        base = epic_dir(runs_dir, epic_id)
        os.makedirs(base, exist_ok=True)

        # Hash chain membership (REQ-EXEC-005): every hash-strategy record
        # carries the input digest so the whole chain of one input is
        # queryable. Additive — sequential records are untouched.
        if id_strategy == "hash":
            metadata = {
                **(metadata or {}),
                "id_strategy": "hash",
                "input_hash": input_hash(input_data),
            }

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
                mode,
                chosen,
                attempts,
                selection,
                skill,
            )
            os.replace(tmp_dir, final_path)
        except BaseException:
            # Roll the partial temp dir back so nothing incomplete is left behind.
            _rmtree(tmp_dir)
            raise

        return RunResult(run_id=run_id, path=final_path, stochastic=stochastic)
    except (OSError, FileExistsError, ValueError):
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
    mode,
    chosen,
    attempts,
    selection,
    skill=None,
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
        # Seed is auditable whenever one is supplied (best-of-n / consensus
        # attempts carry distinct seeds), not only for stochastic skills.
        if seed is not None:
            _write_text(os.path.join(path, "seed.txt"), str(seed))
        _write_json(
            os.path.join(path, "metadata.json"),
            _build_metadata(
                stochastic,
                seed,
                metadata,
                mode,
                chosen,
                attempts,
                selection,
                skill,
            ),
        )
    except OSError:
        raise


def _build_metadata(
    stochastic, seed, metadata, mode, chosen, attempts, selection, skill=None
) -> dict:
    """metadata.json: reproducibility level, mode, retries, the skill slug
    (flaky-detection grouping, REQ-EXEC-004), plus the best-of-n / consensus
    linking fields when this is a chosen record."""
    meta = {
        # AC-3: reproducibility level is the first key so the oracle's
        # "output_contains reproducibility" check is unambiguous.
        "reproducibility": "best-effort" if not stochastic else "strict",
        "mode": mode,
        "retries": 0,
        "stochastic": bool(stochastic),
        "run_seed": seed,
    }
    if skill is not None:
        meta["skill"] = skill
    if metadata:
        meta.update(metadata)
    if chosen:
        meta["chosen"] = True
        meta["attempts"] = list(attempts or [])
        meta["selection"] = (
            selection if selection is not None else _default_selection(mode)
        )
    return meta


def _default_selection(mode) -> dict:
    """Per-mode default selection record (REQ-EXEC-003 / AC-2, AC-3)."""
    if mode == "consensus":
        return {
            "criteria": "majority",
            "answer": None,
            "tally": {},
            "tie_break": "lowest-seed",
        }
    return {"criteria": "oracle pass rate", "chosen_run": None}


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
