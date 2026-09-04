---
# TreeSpec target repo — REQ-INTAKE-001
# Source: phase 0 dogfood, EPIC-002-intake-layer. Filled per spec-format rules.

# ── L0 · REQUIRED ───────────────────────────────────────────
id: REQ-INTAKE-001
title: "Intake layer: persistent requirements buffer and intake skill"
status: done
type: feature
priority: high

epic: EPIC-002-intake-layer

scope:
  in:
    - "Intake buffer artifacts/intake/REQUIREMENTS.md with candidate schema (Cand-ID, text, source ref path+anchor, domain, status, confidence)"
    - "New skill skills/intake/SKILL.md: normalize raw sources into buffer candidates; append-only, never removes rows"
    - "Manifest: [pipeline.skills.intake] declared; stage 1 flow = intake → brainstorm → write-spec; skill count 6→7"
    - "REQ-TREESPEC-001 revised: skill-count assertions (AC-2, constraints) updated from 6 to 7 (rev 2) and later to 8 (rev 5, EPIC-010 T-04, 2026-09-04)"
    - "Dedup and within-raw-set conflict flagging at intake time (documented heuristics)"
    - "Intake format conventions for typical sources (BR/US lists, Jira export, Confluence prose, chat transcripts) in documents/assets/"
    - "Kit self-consistency: kit spec + tests/intake/ following the existing per-skill pattern"
  out:
    - "Runtime automation, CLI, validators (phase 1+)"
    - "Semantic/ML clustering — phase 0 uses documented heuristics only"
    - "Fixing the stale duplicate specs tree in the framework repo — separate decision"
    - "provenance.source_refs extension — covered by REQ-TRACE-001"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall maintain an intake buffer at
      artifacts/intake/REQUIREMENTS.md with a candidate table containing
      columns Cand-ID, text, source ref, domain, status, and confidence.
    verification:
      method: static_analysis
      command: "test -f artifacts/intake/REQUIREMENTS.md && grep -q 'Cand-ID' artifacts/intake/REQUIREMENTS.md && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-2
    pattern: ubiquitous
    statement: |
      The system shall provide an intake skill at skills/intake/SKILL.md
      declared in tree-spec.toml under [pipeline.skills.intake].
    verification:
      method: static_analysis
      command: "test -f skills/intake/SKILL.md && python -c \"import tomllib; d=tomllib.load(open('tree-spec.toml','rb')); assert 'intake' in d['pipeline']['skills']\" && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-3
    pattern: event_driven
    statement: |
      When the intake skill receives one or more raw source paths, it shall
      normalize each source into candidate rows (Cand-ID, text, source ref
      with path+anchor, domain, status=candidate) and append them to the
      buffer without removing existing rows.
    verification:
      method: static_analysis
      command: "grep -cE 'REQUIREMENTS\\.md|Cand-ID|append' skills/intake/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 3"
      evidence_required: false
      evidence_format: null
  - id: AC-4
    pattern: event_driven
    statement: |
      When intake detects candidates overlapping existing buffer rows or
      existing REQs, it shall flag them as duplicate/conflict instead of
      silently merging or discarding.
    verification:
      method: static_analysis
      command: "grep -cE 'duplicate|conflict|overlap' skills/intake/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 2"
      evidence_required: false
      evidence_format: null
  - id: AC-5
    pattern: unwanted
    statement: |
      If intake marks a candidate as selected or starts drafting from it
      without explicit human confirmation, then the system shall not present
      intake as a human-gated buffer.
    verification:
      method: static_analysis
      command: "grep -cE 'human confirmation|one run = one draft' skills/intake/SKILL.md"
      environment: local
      oracle:
        match_count: ">= 1"
      evidence_required: false
      evidence_format: null
  - id: AC-6
    pattern: unwanted
    statement: |
      If the intake skill writes spec files into artifacts/global/biz-spec/
      or fills L2 fields, then the system shall not present it as a
      preparation-only skill.
    verification:
      method: static_analysis
      command: "grep -E 'global/biz-spec/REQ-' skills/intake/SKILL.md"
      environment: local
      oracle:
        exit_code: 1
      evidence_required: false
      evidence_format: null
  - id: AC-7
    pattern: ubiquitous
    statement: |
      The system shall declare 10 skills in tree-spec.toml and
      REQ-TREESPEC-001's skill-count assertions (AC-2, constraints) shall
      reflect the cumulative history (6 → 7 in rev 2, → 8 in rev 5).
      The `log` capability was added in EPIC-010 T-04 (2026-09-04).
    verification:
      method: static_analysis
      command: "python -c \"import tomllib; d=tomllib.load(open('tree-spec.toml','rb')); assert len(d['pipeline']['skills'])==10\" && grep -q 'exactly 8' artifacts/global/biz-spec/REQ-TREESPEC-001.md && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-28
  updated: 2026-08-28
  author: bugae + zed
---

## Context

Candidates extracted from raw requirements today are ephemeral: they live
for one brainstorm run and are re-derived ad-hoc next time. There is no
persistent backlog, no dedup across runs or sources, and nothing flags a
contradiction inside the raw set itself. This REQ adds the preparation
layer in phase 0 style — procedures + artifacts, no runtime:

- `artifacts/intake/REQUIREMENTS.md` — persistent candidate buffer that
  survives sessions (like all TreeSpec memory).
- `skills/intake/SKILL.md` — ingestion skill with single responsibility:
  raw sources → normalized candidates → buffer. Drafting stays in
  `brainstorm`; writing stays in `write-spec`.

## User flow

1. Human points `intake` at one or more raw source paths.
2. Intake normalizes each source into candidate rows and appends them to
   the buffer; overlaps are flagged, never silently merged.
3. Human picks a candidate (by Cand-ID) — explicit confirmation only.
4. `brainstorm` takes that candidate into the L0 dialogue.

## Notes

- Sync contract with REQ-TRACE-001 (same epic): TRACE AC-4 reads this
  buffer; if either spec's scope changes, the other is revised in the same
  session. Disjoint write sets: INTAKE owns skills/intake/, the buffer,
  adapter docs, and the REQ-TREESPEC-001 revision; TRACE owns
  documents/spec-format.md, spec.template.md, and brainstorm/write-spec.
- AC-7 implements DECISIONS.md #1 (human pre-resolved conflict C1:
  skill count 6→7).
