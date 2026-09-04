"""TreeSpec execution-log runtime (REQ-EXEC-002 / EPIC-010).

Lives inside the `tree-spec` skill (`skills/tree-spec/treespec_log/`)
so the skill is self-contained — copy `skills/tree-spec/` and the
runtime comes with it. PYTHONPATH must point at the skill folder.

Public surface:
    treespec_log.runs   — append-only .runs/ store + completeness validation
    treespec_log.wrap   — internal helper for the treespec-wrap.sh script
    treespec_log.main   — CLI entry point (python -m treespec_log)
"""

__version__ = "0.1.0"