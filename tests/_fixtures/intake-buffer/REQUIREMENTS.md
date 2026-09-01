# Intake Buffer — Requirements Candidates

Persistent candidate backlog for the intake layer (REQ-INTAKE-001).
Survives sessions like all TreeSpec memory. Managed by the `intake`
skill: rows are appended, overlaps are flagged, selection is human-gated.

## Candidates

| Cand-ID | Text | Source ref | Domain | Status | Confidence |
|---------|------|------------|--------|--------|------------|
| C-001 | Kit spec drift: stale duplicate REQ-*.md in ../specs/ diverge from canonical copies (REQ-BRAIN-001 missing AC-7/AC-8; REQ-SETUP-001 differs) — decide cleanup or de-duplication of the specs tree | EPIC-002 STATUS.md § Idea; user phase 0 findings 2026-08-28 | KIT | candidate | high |
| C-002 | README "Epic file layout" table lists per-epic tree-spec.toml without an optional marker — clarify semantics (template and EPIC-001 treat it as optional) | ../documents/phases/phase_0/README.md § Epic file layout | KIT | candidate | high |
| C-003 | Phase 1 source: documents/phases/phase_1.md — Validation as Markdown, Tested Mechanically. Pre-identified epics (bulk mode): Эпик-1.1 Validation through tests → EPIC-005 (REQ-VALID-001), Эпик-1.2 Backward-compat gate → EPIC-006 (REQ-VALID-002), Эпик-1.3 Validation protocol doc → EPIC-007 (REQ-VALID-003), Эпик-1.4 tree-spec-check script → EPIC-008 (REQ-VALID-004). All four specced this session 2026-08-31 in queue order; awaits G_spec × 4 before plan stage | ../documents/phases/phase_1.md § Что строим | VALID | candidate | high |

## Status legend

| Status | Meaning |
|--------|---------|
| candidate | Extracted from a raw source; not yet chosen |
| selected | Human explicitly confirmed this candidate for drafting (one run = one draft) |
| specced | An L0 spec exists for this candidate (link the REQ in Notes below) |
| discarded | Rejected by human; kept for history, never deleted |

## Rules

- Append-only: intake adds candidates and never removes or rewrites rows.
  Corrections = a new row referencing the old Cand-ID.
- Overlaps with existing buffer rows or existing REQs are flagged as
  duplicate/conflict — never silently merged or discarded.
- Selection to `selected` requires explicit human confirmation; intake
  never selects on its own.

## Notes

- C-001 is explicitly out of scope for EPIC-002 (REQ-INTAKE-001
  scope.out); it lives here as a candidate for a future epic.
