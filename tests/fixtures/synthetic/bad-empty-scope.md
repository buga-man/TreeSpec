---
# Synthetic fixture for tests/spec/test-rules.sh negative testing.
# Only ONE rule is broken: scope.in is empty (REJECT — must be non-empty per
# documents/spec-format.md §6). All other L0 fields are valid.
# This fixture exists ONLY for tests/fixtures/test-synthetic.sh; it is NOT
# loaded by write-spec or any other runtime path.

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-BADES-001
title: "Synthetic fixture: empty scope.in (broken rule)"
status: draft
type: feature
priority: low

epic: EPIC-005-validation-through-tests

scope:
  in: []               # ← empty list — violates "scope.in non-empty"
  out:
    - "Nothing — this is a synthetic test fixture, not a real spec"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      This fixture exists solely to assert that tests/spec/test-rules.sh
      flags scope.in as empty (REQ-VALID-001 AC-2 / ASSERT-SPEC-009).
    verification:
      method: static_analysis
      command: "test -f tests/fixtures/synthetic/bad-empty-scope.md && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-09-01
  updated: 2026-09-01
  author: bugae + zed
---
