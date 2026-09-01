---
# Synthetic fixture for tests/spec/test-rules.sh negative testing.
# Only ONE rule is broken: id has lowercase letters and 1 digit (REJECT — must
# match ^REQ-[A-Z]{2,8}-\d{3}$). All other L0 fields are valid.
# This fixture exists ONLY for tests/fixtures/test-synthetic.sh; it is NOT
# loaded by write-spec or any other runtime path.

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-foo-1            # ← lowercase 'foo' and 1 digit '1' — violates id regex
title: "Synthetic fixture: malformed id (lowercase + 1 digit)"
status: draft
type: feature
priority: low

epic: EPIC-005-validation-through-tests

scope:
  in:
    - "Verify that tests/spec/test-rules.sh rejects lowercase domain"
    - "Verify that tests/spec/test-rules.sh rejects single-digit suffix"
  out:
    - "Nothing — this is a synthetic test fixture"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      This fixture exists solely to assert that tests/spec/test-rules.sh
      flags the id as failing the ^REQ-[A-Z]{2,8}-\d{3}$ regex
      (REQ-VALID-001 AC-2 / ASSERT-SPEC-001).
    verification:
      method: static_analysis
      command: "test -f tests/fixtures/synthetic/bad-id-format.md && echo OK"
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
