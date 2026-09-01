---
# TreeSpec target repo — REQ-VALID-001
# Phase 1 / Epic-1.1: Validation through tests.
# Source: documents/phases/phase_1.md § "Что строим / 1. Расширение tests/" + § "Определения проверок".
# Status: approved (G_spec closed 2026-08-31, DECISIONS.md #1).

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-VALID-001
title: Mechanical validation tests for manifest, spec L0, and router
status: approved
type: feature
priority: high

epic: EPIC-005-validation-through-tests

scope:
  in:
    - "New test group tests/manifest/ covering tree-spec.toml against CON-10 manifest v0.2 (sections, kernel.version semver, identity.name kebab-case, [pipeline.skills.*].file path resolution, entry_skill membership, gate skill participants, [epic] presence, [meta].language whitelist)"
    - "New test group tests/spec/ covering artifacts/global/biz-spec/REQ-DOMAIN-NNN.md against spec-format.md §6 (id regex + uniqueness, title length, status/type/priority enums, epic regex, scope.in non-empty, AC ≥1 with unique ids, provenance dates/author, source_refs paths resolve)"
    - "New test group tests/router/ fixing the 4 fail-closed checks from skills/tree-spec/SKILL.md § Validation (kernel version, file paths, entry skills, gate skills)"
    - "tests/run-all.sh aggregates tests/manifest/, tests/spec/, tests/router/ with existing per-skill test scripts; exits 0/1; per-assertion output"
    - "Total: ~30–50 asserts across the three new groups; each assert maps 1:1 to a rule in documents/validation.md"
  out:
    - "JSON Schema for tree-spec.toml or for spec frontmatter (cancelled — phase 2 with plugin loader)"
    - "linter-det plugin or any other [plugins] machinery (phase 2)"
    - "Single-binary CLI (cancelled — agent is the runtime)"
    - "Migration of existing per-skill tests; this REQ only adds new groups"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall provide tests/manifest/ with one or more test scripts
      asserting every manifest v0.2 rule documented in CON-10 and the router
      validation procedure (sections, kernel.version, identity.name,
      file-path resolution, entry_skill membership, gate skill participants,
      [epic] key, [meta].language).
    verification:
      method: static_analysis
      command: "test -d tests/manifest && ls tests/manifest/test-*.sh | wc -l"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null
  - id: AC-2
    pattern: ubiquitous
    statement: |
      The system shall provide tests/spec/ with one or more test scripts
      asserting every L0-field rule from documents/spec-format.md §6
      (id format and uniqueness in artifacts/global/biz-spec/, title length,
      status/type/priority enums, epic regex, scope.in non-empty,
      acceptance_criteria ≥1 with unique ids, provenance dates in
      YYYY-MM-DD, provenance.author non-empty, source_refs paths resolve).
    verification:
      method: static_analysis
      command: "test -d tests/spec && ls tests/spec/test-*.sh | wc -l"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null
  - id: AC-3
    pattern: ubiquitous
    statement: |
      The system shall provide tests/router/ with one or more test scripts
      asserting the four fail-closed validation groups from
      skills/tree-spec/SKILL.md § "Validation (fail-closed)" (kernel
      version, [pipeline.skills.*].file path resolution, each stage's
      entry_skill ∈ skills, every gate participant of kind skill ∈
      [pipeline.skills.*]).
    verification:
      method: static_analysis
      command: "test -d tests/router && ls tests/router/test-*.sh | wc -l"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null
  - id: AC-4
    pattern: event_driven
    statement: |
      When tests/run-all.sh is invoked from the repository root, the system
      shall execute every test script under tests/manifest/, tests/spec/,
      tests/router/ and the existing per-skill tests/, in order, and
      aggregate exit codes so the runner returns 0 only if every script
      passes.
    verification:
      method: integration_test
      command: "bash tests/run-all.sh; echo EXIT=$?"
      environment: local
      oracle:
        exit_code: 0
      evidence_required: true
      evidence_format: stdout
  - id: AC-5
    pattern: unwanted
    statement: |
      If a synthetic manifest / spec / router fixture violates a documented
      rule, then bash tests/run-all.sh shall return a non-zero exit code
      and print a per-assertion message that names the failing rule and
      the file path within the fixture.
    verification:
      method: integration_test
      command: "bash tests/run-all.sh; test $? -ne 0 && grep -E 'tests/(manifest|spec|router)/' last_run_output && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: true
      evidence_format: stdout
  - id: AC-6
    pattern: ubiquitous
    statement: |
      The system shall ensure that every assertion in tests/manifest/,
      tests/spec/, tests/router/ is recorded in the check catalog of
      documents/validation.md with: rule, source of truth (spec-format.md §N
      or router SKILL.md or CON-XX), test location
      (tests/<area>/<test>.sh:<assert_id>), and severity.
    verification:
      method: static_analysis
      command: "grep -cE 'tests/(manifest|spec|router)/' documents/validation.md"
      environment: local
      oracle:
        match_count: ">= 30"
      evidence_required: false
      evidence_format: null
  - id: AC-7
    pattern: ubiquitous
    statement: |
      The system shall run all new test groups using Python ≥ 3.11 stdlib
      and bash, with no `pip install` step and no external binary
      dependency (already enforced by tests/_lib/common.sh).
    verification:
      method: static_analysis
      command: "grep -rE 'pip install|requirements\\.txt' tests/manifest tests/spec tests/router 2>/dev/null | wc -l"
      environment: local
      oracle:
        exit_code: 0
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-31
  updated: 2026-08-31
  author: bugae + zed
---

## Context

Phase 0 ended with documented validation rules but no machine-enforced
guardrails: the rules live in `skills/tree-spec/SKILL.md` § "Validation
(fail-closed)", in `skills/tree-spec/core-capabilities/write-spec/SKILL.md`
Step 2, and in `skills/tree-spec/documents/spec-format.md` §6 — but nothing
runs them on every commit. Phase 1 closes that gap by turning every rule
into a mechanical test. Agent remains the runtime; the tests are the
runtime's mechanical pre-flight.

## User flow

1. Developer / agent runs `bash tests/run-all.sh` (or `scripts/tree-spec-check.sh --all`).
2. The runner executes `tests/manifest/`, `tests/spec/`, `tests/router/`
   plus existing per-skill scripts, in a deterministic order.
3. The runner aggregates exit codes; non-zero is reported with the failing
   rule, file path, and assertion id.

## Notes

- One assert per documented rule: every line in `documents/validation.md`
  catalog has a corresponding shell assert. Rules without a test are
  flagged in `documents/validation.md` itself and either get a test or
  move to `linter-det` (phase 2).
- Synthesizes backward-compat coverage via `tests/fixtures/phase_0_manifest.toml`
  (covered by REQ-VALID-002).
- Disjoint write sets with REQ-VALID-002 (fixture), REQ-VALID-003 (catalog
  doc), REQ-VALID-004 (CLI wrapper): VALID-001 owns `tests/manifest/`,
  `tests/spec/`, `tests/router/`, and the wiring in `tests/run-all.sh`.