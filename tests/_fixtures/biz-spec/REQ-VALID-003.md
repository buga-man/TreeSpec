---
# TreeSpec target repo — REQ-VALID-003
# Phase 1 / Epic-1.3: Validation protocol doc.
# Source: documents/phases/phase_1.md § "Что строим / 3. Validation protocol (документация)" + § "DoD phase 1 #5".
# Status: draft (awaiting G_spec).

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-VALID-003
title: Validation protocol document as single source of truth
status: draft
type: chore
priority: medium

epic: EPIC-007-validation-protocol-doc

scope:
  in:
    - "documents/validation.md — new canonical document, single source of truth on what is validated, where, and how to extend"
    - "Section 1: Validation route — router → init → skill → verify; which checks at each point; fail-closed vs warning"
    - "Section 2: Check catalog — table of rule | source of truth (spec-format.md §N / router SKILL.md / CON-XX) | test location (tests/<area>/<test>.sh:<assert_id>) | severity"
    - "Section 3: Extension convention — how to add a new check (new assert in tests/, catalog entry, manifest docs link)"
    - "Section 4: Exit semantics — bash tests/run-all.sh exit 0/1; per-assertion output; color-on-TTY"
    - "Section 5: Phase 2 boundary — what is NOT covered by tests/ (semantic conflicts, spec ↔ spec, requirement ↔ north-star) and moves to linter-ai / plugin loader"
    - "Cross-references: tests/README.md and the router frontmatter (\"Source of truth\") link to documents/validation.md"
  out:
    - "Per-skill validation procedures inside individual SKILL.md files (subsumed by the single catalog)"
    - "Localized copies of validation.md (i18n does not cover this; canonical English only)"
    - "Automated generation of the catalog from asserts (phase 2+; for now the catalog is hand-maintained alongside the asserts)"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall ship documents/validation.md at the repository
      root, distinct from documents/phases/ and documents/concepts/.
    verification:
      method: static_analysis
      command: "test -f documents/validation.md && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-2
    pattern: ubiquitous
    statement: |
      The system shall ensure documents/validation.md contains all five
      named sections: Validation route, Check catalog, Extension
      convention, Exit semantics, Phase 2 boundary.
    verification:
      method: static_analysis
      command: "grep -cE '^## (Validation route|Check catalog|Extension convention|Exit semantics|Phase 2 boundary)' documents/validation.md"
      environment: local
      oracle:
        match_count: "5"
      evidence_required: false
      evidence_format: null
  - id: AC-3
    pattern: ubiquitous
    statement: |
      The system shall ensure every assert in tests/manifest/, tests/spec/,
      tests/router/ is referenced by exactly one row in the Check catalog
      section of documents/validation.md, with rule, source of truth,
      test location, and severity.
    verification:
      method: static_analysis
      command: "grep -cE 'tests/(manifest|spec|router)/.*\\.sh' documents/validation.md"
      environment: local
      oracle:
        match_count: ">= 30"
      evidence_required: false
      evidence_format: null
  - id: AC-4
    pattern: ubiquitous
    statement: |
      The system shall ensure tests/README.md references
      documents/validation.md as the canonical description of what
      tests/run-all.sh validates.
    verification:
      method: static_analysis
      command: "grep -cE 'documents/validation\\.md|validation\\.md' tests/README.md"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null
  - id: AC-5
    pattern: ubiquitous
    statement: |
      The system shall ensure the frontmatter of skills/tree-spec/SKILL.md
      declares documents/validation.md in its "Source of truth" comment
      block alongside tree-spec.toml and documents/spec-format.md.
    verification:
      method: static_analysis
      command: "grep -cE 'documents/validation\\.md' skills/tree-spec/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-31
  updated: 2026-08-31
  author: bugae + zed
  source_refs:
    - path: ../../../../documents/phases/phase_1.md
      anchor: "Эпик-1.3: Validation protocol doc"
      original_text: "documents/validation.md (новый) — единственный источник истины о том, что валидируется, где, и как расширять. Структура: Маршрут валидации, Каталог проверок, Конвенция расширения, Exit semantics, Граница с phase 2."
---

## Context

Phase 1 codifies validation as markdown + tests. The catalog is what
keeps the two sides in sync: every rule has a documented source of
truth and a mechanical test. Without the catalog, the asserts drift and
the docs rot; without the docs, the asserts become cargo-culted.

## User flow

1. Author proposes a new rule. They add the rule's assert under
   `tests/<area>/` and a row in the catalog.
3. Reviewer cross-checks: catalog row matches assert id; assert covers
   the rule.
4. CI runs `bash tests/run-all.sh` and the catalog is re-checked (catalog
   completeness is itself an assert in REQ-VALID-001 AC-6).

## Notes

- Catalog rows are append-only in spirit; renumbering the catalog is a
  PR-sized change with explicit diff.
- This REQ depends on REQ-VALID-001 (the asserts that populate the
  catalog).
- Disjoint write sets: VALID-003 owns `documents/validation.md` and the
  cross-reference additions in `tests/README.md` and
  `skills/tree-spec/SKILL.md`.