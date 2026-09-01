---
id: intake
name: intake
description: intake idea
version: 0.1.0
phase: 0
stage: spec
classification: hybrid

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - raw_sources: string[]               # paths to raw requirement sources (files or directories)
output:
  - buffer_update: path                 # artifacts/intake/REQUIREMENTS.md — rows appended

side_effects:
  - appends candidate rows to artifacts/intake/REQUIREMENTS.md
  - creates artifacts/intake/REQUIREMENTS.md on first run (bootstrap, idempotent)

failure_handling:
  - on_missing_source: "skip the source, list it in the handoff for the human"
  - on_overlap_detected: "flag the row as duplicate/conflict; never merge or discard silently"
  - on_ambiguous_domain: "mark domain as an open question for the human"

composition:
  - may_invoke: []                        # phase 0: no composition
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: intake

**Stage:** 1 (Spec), preparation step. **Launched** by the agent at the
start of stage 1, before `brainstorm`.
**Purpose:** normalize raw requirement sources into a persistent
candidate buffer — the systematic entry point for raw requirements.
This skill prepares only: drafting belongs to `brainstorm`, writing spec
files belongs to `write-spec`.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.spec]` (exit criteria, gate) and
> `[pipeline.skills.intake]` (this skill's contract). The manifest
> is the contract; this markdown is the procedure. If they ever
> disagree, the manifest wins — escalate to the human.

---

## Procedure

### Step 1. Collect raw sources

Input: one or more raw source paths — files or directories. Typical
formats and extraction heuristics: see `../../documents/assets/intake-formats.md`.

Before extracting, check what is already in the buffer: if a source was
already ingested (same path), append only genuinely new rows.

If the human has no raw sources yet (pure conversation idea), pass
through to `brainstorm` immediately — there is nothing to normalize.

### Step 2. Normalize each source into candidate rows

For every requirement-like statement found in a source, produce one row:

- **Cand-ID** — next free C-NNN (scan existing buffer rows).
- **Text** — the requirement restated concisely and unambiguously.
- **Source ref** — `path + anchor` (heading, item id, or line number).
- **Domain** — 2–8 uppercase letters per the REQ domain convention; if
  unclear, mark it as an open question for the human.
- **Status** — always `candidate`.
- **Confidence** — high / medium / low, by how directly the source states
  a requirement.

Append all new rows to the buffer. Never remove or rewrite existing rows:
a correction is a new row that references the old Cand-ID.

### Step 3. Check overlaps (before handoff)

Compare each new row against:

1. **Existing buffer rows** — same intent from another source?
2. **Existing REQs in the biz-spec store** — already specced?

When an overlap is detected, flag it in the row's Text as
`duplicate of C-NNN` or `conflict with REQ-DOMAIN-NNN`, and report it in
the handoff. Never merge or discard candidates silently — that decision
belongs to the human.

### Step 4. Selection (human-gated)

A candidate moves from `candidate` to `selected` only with explicit
human confirmation: the human names a Cand-ID and confirms it for
drafting. Intake never selects on its own, never pre-selects "obvious"
candidates, never starts drafting from them.

One run = one draft: after selection, hand exactly that candidate to
`brainstorm` as input for the L0 dialogue.

### Step 5. Handoff

Return to the human:

- The new Cand-IDs appended to the buffer.
- All duplicate/conflict flags with references.
- The selected candidate (if any) — ready for `brainstorm`.

**The buffer is updated; drafting proceeds in `brainstorm` [next skill].**

---

## Anti-patterns

- ❌ Removing or rewriting buffer rows — history is append-only, like
  PATH/DECISIONS.
- ❌ Silently merging overlapping candidates — flag instead; the human
  decides.
- ❌ Writing spec files (intake never writes into biz-spec) or filling
  L2 fields — preparation only.
- ❌ Selecting a candidate without explicit human confirmation.
- ❌ Re-extracting an already-ingested source on every run — check the
  buffer first, append only what is new.

---

## Claim / Verify

- **Claim:** "Raw sources normalized into the intake buffer; overlaps
  flagged; selection human-gated".
- **Verify (run by the `verify` skill):**
  - The buffer file exists with the candidate schema.
  - New rows reference real source paths and anchors.
  - No existing row was removed or rewritten.
  - Overlapping rows carry duplicate/conflict flags instead of being
    merged.
