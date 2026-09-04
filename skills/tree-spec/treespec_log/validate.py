"""Manifest consistency checks (REQ-EXEC-005 / EPIC-013, T-02).

One check for now: the id-strategy / purity guard. The `hash` id strategy
is only valid for pure (deterministic) skills — declared as
``pure = true`` under ``[pipeline.skills.<id>]``. ``run`` itself does not
enforce this (the CLI stays manifest-agnostic, decision 2026-09-04); the
agent calls ``validate`` before running a skill with
``--id-strategy hash``.

Stdlib only: ``tomllib`` (Python >= 3.11).
"""

from __future__ import annotations

import tomllib


def check_id_strategy(
    manifest_path: str, skill_id: str, strategy: str | None = None
) -> tuple[int, str]:
    """Check that ``skill_id`` may use the effective id strategy.

    Effective strategy: the explicit ``strategy`` argument if given, else
    ``[kernel].id_strategy`` from the manifest, else ``"sequential"``.

    Returns ``(exit_code, message)``:
      0 — allowed (sequential always; hash for a skill with ``pure = true``);
      1 — rejected: hash strategy for a skill that is not declared pure;
      2 — usage error: unreadable/invalid manifest or unknown skill id.
    """
    try:
        with open(manifest_path, "rb") as fh:
            manifest = tomllib.load(fh)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        return 2, f"error: cannot read manifest {manifest_path!r}: {exc}"

    effective = strategy or manifest.get("kernel", {}).get("id_strategy", "sequential")
    if effective != "hash":
        return 0, (f"ok: effective id strategy '{effective}' does not require purity")

    skills = manifest.get("pipeline", {}).get("skills", {})
    if skill_id not in skills:
        return 2, f"error: skill '{skill_id}' not declared in {manifest_path}"
    # Strict on purpose: purity must be declared as the TOML boolean
    # `true` — `1`, `"yes"` & co. do not count.
    pure = skills[skill_id].get("pure")
    if isinstance(pure, bool) and pure:
        return 0, f"ok: skill '{skill_id}' is pure — hash id strategy allowed"
    return 1, (
        f"error: skill '{skill_id}' is not pure — hash id strategy requires "
        f"[pipeline.skills.{skill_id}] pure = true"
    )
