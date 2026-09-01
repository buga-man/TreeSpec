---
# TreeSpec target repo — REQ-TRACE-001
# Source: phase 0 dogfood, EPIC-002-intake-layer. Filled per spec-format rules.

# ── L0 · REQUIRED ───────────────────────────────────────────
id: REQ-TRACE-001
title: Raw-to-spec provenance traceability via source_refs
status: done
type: feature
priority: high

epic: EPIC-002-intake-layer

scope:
  in:
    - "Optional provenance.source_refs[] (path, anchor, original_text) documented in this repo's documents/spec-format.md and documents/assets/spec.template.md"
    - "documents/ bootstrapped in this repo so the kit is self-contained (fixes write-spec template gap)"
    - "brainstorm reworked: records source_refs in the draft when generating from raw sources; reads candidates from the intake buffer when present"
    - "write-spec preserves and validates source_refs when writing the spec file"
  out:
    - "Upstream sync of ../documents (framework repo) — separate maintainer task"
    - "Automated traceability queries/tooling (phase 1+)"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall document the optional provenance.source_refs field
      in documents/spec-format.md and documents/assets/spec.template.md.
    verification:
      method: static_analysis
      command: "grep -q 'source_refs' documents/spec-format.md && grep -q 'source_refs' documents/assets/spec.template.md && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-2
    pattern: event_driven
    statement: |
      When a spec draft is generated from raw sources via brainstorm, its
      provenance shall include source_refs entries (path, anchor,
      original_text) linking the spec back to the raw requirement.
    verification:
      method: static_analysis
      command: "grep -cE 'source_refs' skills/brainstorm/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null
  - id: AC-3
    pattern: event_driven
    statement: |
      When write-spec registers a spec carrying source_refs, it shall verify
      each referenced path exists; if any is missing, it shall refuse to
      write the spec.
    verification:
      method: static_analysis
      command: "grep -cE 'source_refs' skills/write-spec/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 2"
      evidence_required: false
      evidence_format: null
  - id: AC-4
    pattern: event_driven
    statement: |
      When the intake buffer exists, brainstorm shall select candidates from
      it instead of re-extracting requirements from source_doc per run.
    verification:
      method: static_analysis
      command: "grep -cE 'intake buffer|REQUIREMENTS\\.md' skills/brainstorm/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-28
  updated: 2026-08-28
  author: bugae + zed
---

## Context

Spec provenance today records only author/date — there is no link from a
spec back to the raw requirement it grew from. Without that link, nobody
can prove that a systematic draft really derives from specific raw data.
This REQ closes the raw → draft auditability gap with an optional
`provenance.source_refs[]` field (path + anchor + original_text).

Per spec-format's own rule ("format changes are fixed here first, then
derivatives are synced"), the format doc and template are updated in this
repo as part of this REQ. This also fixes a gap found during brainstorm:
`write-spec` references `documents/assets/spec.template.md`, which did not
exist in this repo (DECISIONS.md #2).

## Notes

- Sync contract with REQ-INTAKE-001 (same epic): AC-4 reads the intake
  buffer defined by INTAKE AC-1; if either spec's scope changes, the other
  is revised in the same session.
- source_refs is optional: specs without a raw source simply omit it —
  backward compatible with existing artifacts.
