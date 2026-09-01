---
# Synthetic fixture for tests/spec/test-rules.sh negative testing.
# Only ONE rule is broken: id collides with REQ-INTAKE-001 (REJECT — must be
# globally unique across artifacts/global/biz-spec/). All other L0 fields are
# valid.
# This fixture exists ONLY for tests/fixtures/test-synthetic.sh; it is NOT
# loaded by write-spec or any other runtime path.
#
# NOTE: this fixture is intentionally placed under tests/fixtures/synthetic/
# (NOT artifacts/global/biz-spec/) so it does NOT actually collide with the
# real REQ-INTAKE-001. The synthetic test discovers the id format and runs
# a cross-check against the real artifacts/global/biz-spec/ dir.

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-INTAKE-001       # ← collides with the real spec's id
title: "Synthetic fixture: id collides with REQ-INTAKE-001"
status: draft
type: feature
priority: low

epic: EPIC-005-validation-through-tests

scope:
  in:
    - "Verify that tests/spec/test-rules.sh flags duplicate ids when this fixture is moved into artifacts/global/biz-spec/ alongside the real spec"
  out:
    - "Nothing — this is a synthetic test fixture"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      This fixture exists solely to assert that tests/spec/test-rules.sh
      flags duplicate spec ids (REQ-VALID-001 AC-2 / ASSERT-SPEC-002).
    verification:
      method: static_analysis
      command: "test -f tests/fixtures/synthetic/bad-duplicate-id.md && echo OK"
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
