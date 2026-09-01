---
# Synthetic fixture for tests/spec/test-rules.sh negative testing.
# Only ONE rule is broken: status is "rejected" (REJECT — must be one of
# draft / approved / implemented / done per documents/spec-format.md §5).
# All other L0 fields are valid.
# This fixture exists ONLY for tests/fixtures/test-synthetic.sh; it is NOT
# loaded by write-spec or any other runtime path.

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-BADSE-001
title: "Synthetic fixture: status not in enum"
status: rejected          # ← not in {draft, approved, implemented, done}
type: feature
priority: low

epic: EPIC-005-validation-through-tests

scope:
  in:
    - "Verify that tests/spec/test-rules.sh rejects 'rejected' as a status"
  out:
    - "Nothing — this is a synthetic test fixture"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      This fixture exists solely to assert that tests/spec/test-rules.sh
      flags status values outside the {draft, approved, implemented, done}
      enum (REQ-VALID-001 AC-2 / ASSERT-SPEC-005).
    verification:
      method: static_analysis
      command: "test -f tests/fixtures/synthetic/bad-status-enum.md && echo OK"
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
