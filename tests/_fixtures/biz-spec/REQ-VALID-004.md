---
# TreeSpec target repo — REQ-VALID-004
# Phase 1 / Epic-1.4: tree-spec-check script.
# Source: documents/phases/phase_1.md § "Что строим / 4. Tooling для агента" + § "DoD phase 1 #4".
# Status: draft (awaiting G_spec).

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-VALID-004
title: tree-spec-check bash wrapper for fast pre-flight checks
status: draft
type: chore
priority: medium

epic: EPIC-008-tree-spec-check-script

scope:
  in:
    - "scripts/tree-spec-check.sh — bash + Python (stdlib only) wrapper around tests/_lib/common.sh, no separate binary"
    - "Modes: --manifest, --spec, --router, --all (default)"
    - "Each mode runs only the corresponding assert group (manifest, spec, or router) so a single-area check returns in under one second"
    - "Exit code 0 on success, 1 on any failing assert; human-readable output (color-on-TTY)"
    - "<100 lines of bash (excluding sourced common.sh)"
  out:
    - "Standalone binary (Rust/Go/Node) — explicitly cancelled in phase_1.md"
    - "JSON output format (deferred to phase 1.5 / phase 2 if a need appears)"
    - "Network/file-watch mode"
    - "Plugin discovery or runtime registration"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall ship scripts/tree-spec-check.sh at the repository
      root, executable, written in bash with Python stdlib helpers, and
      not exceeding 100 lines of bash excluding any sourced common.sh.
    verification:
      method: static_analysis
      command: "test -x scripts/tree-spec-check.sh && grep -cvE '^\\s*(#|$)' scripts/tree-spec-check.sh | awk '{ if ($1 <= 100) print OK }'"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-2
    pattern: event_driven
    statement: |
      When scripts/tree-spec-check.sh is invoked with --manifest, --spec,
      or --router, the system shall execute only the corresponding assert
      group from tests/<area>/ and return within one second on a typical
      workstation.
    verification:
      method: integration_test
      command: "time scripts/tree-spec-check.sh --manifest 2>&1 | tail -1"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: true
      evidence_format: stdout
  - id: AC-3
    pattern: event_driven
    statement: |
      When scripts/tree-spec-check.sh is invoked with --all (or no flag),
      the system shall run every assert group in tests/manifest/,
      tests/spec/, tests/router/ and exit 0 on success, 1 on any failure,
      with a per-assertion message naming the failing rule and file path.
    verification:
      method: integration_test
      command: "scripts/tree-spec-check.sh --all; echo EXIT=$?"
      environment: local
      oracle:
        exit_code: 0
      evidence_required: true
      evidence_format: stdout
  - id: AC-4
    pattern: unwanted
    statement: |
      If scripts/tree-spec-check.sh introduces a `pip install` step, a
      network call, or a compiled binary dependency, then the system
      shall not present it as a stdlib-only wrapper.
    verification:
      method: static_analysis
      command: "grep -E 'pip install|curl|wget|go build|cargo build' scripts/tree-spec-check.sh"
      environment: local
      oracle:
        exit_code: 1
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-31
  updated: 2026-08-31
  author: bugae + zed
  source_refs:
    - path: ../../../../documents/phases/phase_1.md
      anchor: "Эпик-1.4: tree-spec-check script"
      original_text: "scripts/tree-spec-check.sh — обёртка над bash tests/run-all.sh + быстрые checks. Режимы --manifest, --spec, --router, --all. Использует те же assert'ы, что и tests/. Размер — <100 строк bash."
---

## Context

The agent runs validation at session start, but `bash tests/run-all.sh`
covers the whole battery (per-skill + manifest + spec + router). For
iterative work — a quick manifest edit, a spec fix — the full run is
overkill. `tree-spec-check.sh` exposes the three new groups as named
modes so the agent (or a developer) can pre-flight one area in under a
second.

## User flow

1. After editing a manifest section, the agent runs
   `scripts/tree-spec-check.sh --manifest`.
2. Only `tests/manifest/` runs; exit 0/1 with the failing rule if any.
3. The agent fixes the issue and re-runs; full `bash tests/run-all.sh`
   runs in CI / pre-commit.

## Notes

- This REQ depends on REQ-VALID-001 (the asserts being wrapped).
- Disjoint write sets: VALID-004 owns `scripts/tree-spec-check.sh` and
  its registration in `tests/README.md` and the kit's session-start
  documentation if applicable.
- Same-script invocation contract: `--all` ≡ `bash tests/run-all.sh`
  exit-code semantics, so the two runners never disagree.