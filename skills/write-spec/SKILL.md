---
id: write-spec
name: write-spec
description: write-spec
version: 0.1.0
phase: 0
stage: spec
classification: stochastic

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - draft_spec: markdown                  # from brainstorm
  - template: string                      # path to template (default: documents/assets/spec.template.md)
output:
  - spec_file: path                       # artifacts/global/biz-spec/REQ-DOMAIN-NNN.md
  - index_entry: bool                     # whether artifacts/INDEX.md was updated

side_effects:
  - may create artifacts/ directory tree if missing (bootstrap, idempotent)
  - creates a file under artifacts/global/biz-spec/
  - creates docs/biz-spec-delta.md inside the epic
  - updates artifacts/INDEX.md (new row)
  - creates docs/conflict-NNN.md (if there were conflicts)

failure_handling:
  - on_invalid_id: "refuse to write, return to brainstorm with a request to revisit id"
  - on_duplicate_id: "refuse to write, conflict doc"
  - on_missing_l0_fields: "refuse to write, return to brainstorm for rework"
  - on_missing_source_ref: "refuse to write, ask to fix the source_refs path in the draft"

composition:
  - may_invoke: []                        # phase 0: no composition
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: write-spec

**Stage:** 1 (Spec). **Launched** by the agent after `brainstorm`.
**Purpose:** turn an L0 spec draft into a **valid file** per the template
`documents/assets/spec.template.md` and register it in the system.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.spec]` (exit criteria, gate) and
> `[pipeline.skills.write-spec]` (this skill's contract). The manifest
> is the contract; this markdown is the procedure. If they ever
> disagree, the manifest wins — escalate to the human.

---

## Procedure

### Step 0. Bootstrap artifacts (if missing)

If the project is fresh — `artifacts/` does not exist — bootstrap the
minimum structure before any other step. This makes the kit
self-contained: the user installs `tree-spec.toml` + `skills/` +
`specs/`, then runs `write-spec` and gets a usable tree.

Check whether `artifacts/` exists:

```
test -d artifacts && echo EXISTS || echo MISSING
```

If **MISSING**, create the minimum structure inline — no template
files are required (the layout is fully described in
`documents/references/artifacts-layout.md`):

```
mkdir -p artifacts/global/biz-spec
mkdir -p artifacts/epics
```

Bootstrap invariants (asserted by `REQ-TREESPEC-001` AC-6):

1. `artifacts/README.md` — agent protocol (session start/end rules).
   Copy verbatim from this skill's knowledge of the protocol, or read it
   from the kit source if available.
2. `artifacts/INDEX.md` — empty header table ready for epic registration.
3. `artifacts/global/biz-spec/` — directory (biz-spec REQ storage).
4. `artifacts/global/biz-spec/README.md` — domain / numbering conventions
   (optional but recommended).
5. `artifacts/epics/` — directory (one folder per epic, created on
   demand by the `plan` skill).

Subdirectories like `artifacts/global/intake/` and the per-epic folder
are **created on demand** by their owning skill (`intake` and `plan`
respectively). Bootstrap only creates the 5 entries above.

> **Reference:** see `documents/references/artifacts-layout.md` for the
> complete directory tree, file roles, and naming conventions.

If **EXISTS**, skip this step — the user already has structure.

> **Why this lives in `write-spec`:** it is the first **writing** skill
> in the pipeline. Anything before it (`session-resume`, `brainstorm`)
> is read-only or in-memory. `write-spec` is the natural place to
> prepare the disk before its own writes.

### Step 1. Context

Read:

1. `documents/assets/spec.template.md` — the canonical template (single source of truth).
2. `documents/spec-format.md` — the canonical rules reference.
3. `artifacts/global/biz-spec/README.md` — conventions for domain / numbering.
4. `artifacts/global/biz-spec/` — existing specs to verify `id` uniqueness.

### Step 2. Validate the draft (mandatory before writing)

Before creating the file, check **every** L0 field of the draft. If even
one is missing or empty — **do not write the file**, return to brainstorm.

Checks:

- `id` matches `^REQ-[A-Z]{2,6}-\d{3}$`.
- `id` is unique in `artifacts/global/biz-spec/`.
- `title` non-empty, ≤120 chars.
- `status` ∈ `{draft, approved, implemented, done}`.
- `type` ∈ `{feature, refactor, bug, chore, spike, compliance}`.
- `priority` ∈ `{critical, high, medium, low}`.
- `epic` matches `^EPIC-\d{3}-[a-z][a-z0-9-]*$`.
- `scope.in` non-empty; each item is a concrete outcome.
- `scope.out` may be empty (recommended to fill).
- `acceptance_criteria` ≥1 AC; each `id` is unique within the spec.
- `provenance.created` / `provenance.updated` — `YYYY-MM-DD` format.
- `provenance.author` non-empty.
- If `provenance.source_refs` is present: every `.path` must exist in
  the repo (raw → spec traceability); any missing file blocks the write.

### Step 3. Write the spec

Create the file `artifacts/global/biz-spec/REQ-DOMAIN-NNN.md`:

1. Copy `documents/assets/spec.template.md`.
2. Replace every `<PLACEHOLDER>` with the value from the draft.
3. Keep **commented instructions** in the file? **No.** Before writing,
   strip all commented instructions from the template — they are for the
   spec author only.
4. Keep empty L1/L2 sections **only if they will be filled later**.
   Otherwise — remove them.

Final file structure:

```yaml
---
# L0 (all)
id, title, status, type, priority, epic,
scope.in, scope.out,
acceptance_criteria[*].id, pattern, statement, verification,
provenance.created, updated, author
provenance.source_refs (if present in the draft — keep verbatim)

# L1 (only filled ones)
# L2 (only filled ones)
---
## Context
## User flow
## Notes
```

The body (Context / User flow / Notes) is optional. Frontmatter alone is
acceptable.

### Step 4. biz-spec-delta.md

Create `artifacts/epics/<EPIC>/docs/biz-spec-delta.md` with the list of
REQs the epic introduces / modifies:

```markdown
# biz-spec-delta — EPIC-XXX

| REQ | Action | Related AC | Spec status |
|-----|--------|------------|-------------|
| REQ-DOMAIN-NNN | add | AC-1, AC-2 | draft |

Actions: add | modify | deprecate.
Related AC — which AC in the epic's tasks cover this REQ (filled at stage 2).
Spec status — at the time the delta was created.
```

### Step 5. Register in INDEX.md

Add a row in `artifacts/INDEX.md`:

```
| Idea | Epic | Stage | Status | Tasks (done/total) | REQs | Open conflicts | Updated |
| | EPIC-XXX | 1 (Spec) | in progress | 0/N | REQ-DOMAIN-NNN | — | YYYY-MM-DD |
```

### Step 6. Conflicts (if any were in the draft)

If brainstorm marked conflicts:

1. Create `artifacts/epics/<EPIC>/docs/conflict-NNN.md` per
   `documents/assets/conflict-doc.template.md`.
2. Status: `open`.
3. Add an entry in the epic `STATUS.md` → "Open problems".
4. Add a row in the epic `tasks.md` → first task T-00 "Close conflict-NNN"
   with status `blocked`.

### Step 7. Handoff

Return to the human:

- The path of the created spec file.
- The path of biz-spec-delta.md.
- The id and title for gate G_spec.
- The list of open conflicts (if any).

**The spec is ready for G_spec [Human].**

---

## Anti-patterns

- ❌ Writing the spec without L0 validation → the file will be invalid, G_spec cannot pass.
- ❌ Leaving commented instructions from the template in the final file.
- ❌ Filling L2 fields (`execution.*`, `failure_handling.*`) in phase 0 —
  we do not have the `risk-testing` plugin, these fields are not validated.
- ❌ Using `verification.oracle` with a "by-eye" value — that is not an
  oracle, that is wishful thinking.
- ❌ Creating the spec inside the epic (`artifacts/epics/<EPIC>/specs/`),
  instead of `global/biz-spec/` — breaks the single-source-of-truth invariant.
- ❌ Dropping or "fixing" source_refs from the draft — keep them verbatim;
  if a referenced path is missing, refuse to write (see failure_handling).
- ❌ Bootstrap may write files other than `artifacts/README.md`,
  `artifacts/INDEX.md`, `artifacts/global/biz-spec/`,
  `artifacts/global/biz-spec/README.md`, and `artifacts/epics/`. Do
  not touch user files during bootstrap — fail-closed if something else
  is missing. See `documents/references/artifacts-layout.md` for the
  authoritative list.

---

## Claim / Verify

- **Claim:** "Spec written into `global/biz-spec/`, passed L0 validation,
  registered in INDEX.md".
- **Verify (run by the `verify` skill):**
  - The file exists and parses as valid YAML frontmatter.
  - All L0 fields are present.
  - `id` is globally unique.
  - `biz-spec-delta.md` references this REQ.
  - INDEX.md has the row for this REQ.
