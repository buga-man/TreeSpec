---
# TreeSpec target repo — REQ-VALID-002
# Phase 1 / Epic-1.2: Backward-compat gate.
# Source: documents/phases/phase_1.md § "Что строим / 2. Backward-compat fixture" + § "DoD phase 1 #3".
# Status: approved (G_spec closed 2026-09-02, EPIC-006 DECISIONS.md #1).

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-VALID-002
title: Backward-compatibility gate via phase_0 manifest fixture
status: approved
type: feature
priority: high

epic: EPIC-006-backward-compat-fixture

scope:
  in:
    - "tests/fixtures/phase_0_manifest.toml — verbatim copy of documents/phases/phase_0/tree-spec.toml, frozen as the canonical backward-compat baseline"
    - "tests/manifest/test-backward-compat.sh — runs every manifest assertion from REQ-VALID-001 against the fixture; passes only if the fixture survives all current and future checks"
    - "Wire into tests/run-all.sh so the backward-compat test runs on every full invocation"
    - "Documented in documents/validation.md as DoD-3 phase 1: any new manifest rule that breaks the phase_0 fixture is a breaking change and must be explicitly handled (opt-in via [kernel].compatibility='lenient' or deferred)"
  out:
    - "Multi-version compatibility (only phase_0 → phase_1 is covered; phase_1 → phase_2 follows in phase 2)"
    - "Migration tooling (conversion scripts, automatic upgraders)"
    - "Network-fetched fixtures or external baselines"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall ship tests/fixtures/phase_0_manifest.toml as a
      verbatim copy of documents/phases/phase_0/tree-spec.toml, byte-for-byte
      identical at the time this REQ is implemented.
    verification:
      method: static_analysis
      command: "diff -q tests/fixtures/phase_0_manifest.toml documents/phases/phase_0/tree-spec.toml"
      environment: local
      oracle:
        exit_code: 0
      evidence_required: false
      evidence_format: null
  - id: AC-2
    pattern: event_driven
    statement: |
      When bash tests/manifest/test-backward-compat.sh runs, the system
      shall execute every assert in tests/manifest/ against the fixture
      and return exit code 0 only if all asserts pass.
    verification:
      method: integration_test
      command: "bash tests/manifest/test-backward-compat.sh; echo EXIT=$?"
      environment: local
      oracle:
        exit_code: 0
      evidence_required: true
      evidence_format: stdout
  - id: AC-3
    pattern: event_driven
    statement: |
      When a new manifest check is added to tests/manifest/ that breaks
      the phase_0 fixture, then bash tests/run-all.sh shall return a
      non-zero exit code so the change cannot land without explicit
      acknowledgment.
    verification:
      method: integration_test
      command: "bash tests/run-all.sh; test $? -ne 0 && echo BREAKING_DETECTED"
      environment: local
      oracle:
        output_contains: "BREAKING_DETECTED"
      evidence_required: true
      evidence_format: stdout
  - id: AC-4
    pattern: ubiquitous
    statement: |
      The system shall document the backward-compat rule in
      documents/validation.md as DoD-3 phase 1, including the procedure
      for handling a breaking change (opt-in via
      [kernel].compatibility='lenient', deferral, or migration notes).
    verification:
      method: static_analysis
      command: "grep -cE 'backward.compat|phase_0_manifest\\.toml' documents/validation.md"
      environment: local
      oracle:
        match_count: ">= 2"
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-31
  updated: 2026-09-02
  author: bugae + zed
---

## Context

Phase 1 introduces mechanical validation but raises the bar on backward
compatibility: any new check that breaks the phase_0 manifest silently
cuts off consumers who have not yet upgraded. Fixing this at the rule
level — not after the fact — turns "did we break anyone?" into a CI
question.

## User flow

1. A new manifest rule is proposed in a PR.
2. The PR runs `bash tests/run-all.sh`; the backward-compat script runs
   the fixture first.
3. If the fixture fails, the PR is red; the rule author must either
   make it opt-in (via `[kernel].compatibility='lenient'`), defer it,
   or write migration notes.

## Notes

- This REQ depends on REQ-VALID-001 (asserts must exist to be run).
- Disjoint write sets: VALID-002 owns `tests/fixtures/phase_0_manifest.toml`,
  `tests/manifest/test-backward-compat.sh`, and the backward-compat
  paragraph in `documents/validation.md`.