---
id: brainstorm
name: brainstorm
description: brainstorming ideas
version: 0.1.0
phase: 0
stage: spec
classification: stochastic

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - idea: string                                # short description from the human
  - context: string | null                      # links to related REQs / epics
  - source_doc: path | null                     # OPTIONAL: raw requirements file (BR list, US backlog, Confluence page); used only when no candidate comes from the intake buffer
output:
  - draft_spec: markdown                        # L0 spec draft (no oracle yet)
  - source_candidates: list(string) | null      # OPTIONAL: when source_doc given, list of candidate REQ IDs identified

side_effects:
  - reads artifacts/INDEX.md
  - reads artifacts/global/biz-spec/ (to trace existing REQs)
  - reads artifacts/intake/REQUIREMENTS.md (intake buffer) for candidates, if it exists
  - reads source_doc (if provided and no intake-buffer candidate chosen) to identify candidate requirements
  - does NOT create artifact files (the draft is passed to write-spec)

failure_handling:
  - on_missing_context: "ask the human for clarification; do not guess"
  - on_ambiguous_idea: "return a question; do not fabricate a spec"
  - on_conflict_with_existing: "create docs/conflict-NNN.md (via write-spec)"
  - on_source_doc_too_vague: "report which candidate requirements are unclear; do not fabricate L0 from gibberish"
  - on_source_doc_not_found: "stop with a clear error; do not proceed with assumption"

composition: []                            # does not invoke other skills implicitly
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: brainstorm

**Stage:** 1 (Spec). **Launched** by the human at the start of an epic.
**Purpose:** turn an idea / request into an L0 spec draft.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.spec]` (which skills, exit criteria, gate) and
> `[pipeline.skills.brainstorm]` (this skill's contract). The manifest
> is the contract; this markdown is the procedure. If they ever
> disagree, the manifest wins — escalate to the human.

---

## Procedure

### Step 1. Context (mandatory)

Read **before** any action:

1. `artifacts/INDEX.md` — which epics are already in flight, which REQs exist.
2. `artifacts/global/biz-spec/README.md` — what is in the biz-spec, which domains.
3. If the human supplied REQ links — read those specs in full.
4. If an epic was specified — read its `STATUS.md` (briefly, not the full history).

**Do not start the dialogue until you know what is already in the system.**

### Step 1.5. Select candidate requirements

Candidates come from two places, in this order:

1. **The intake buffer** (`artifacts/intake/REQUIREMENTS.md`) — if it
   exists, candidates were already normalized there by the `intake`
   skill. **Select from it; do not re-extract** from raw sources per run.
2. **A raw source document** (`source_doc: path`) — fallback when there
   is no intake buffer or it holds no relevant candidate.

If the input includes `source_doc: path`, the human has supplied a
**raw requirements source** — typically one of:

- A list of Business Requirements (BR-NNN) or User Stories (US-NNN).
- A Confluence / Notion page with prose requirements.
- A workshop transcript with needs and constraints.
- A Jira / GitHub-issue dump.

Procedure:

1. **Check the intake buffer first.** If `artifacts/intake/REQUIREMENTS.md`
   exists, read its candidate rows and present them to the human for
   selection (by Cand-ID). Do not re-extract from raw sources — the
   buffer is the persistent backlog.
2. **Otherwise** (no buffer), if `source_doc` is provided: verify the
   file exists (fail with `on_source_doc_not_found` otherwise); read it;
   extract candidate IDs and one-line summaries (structured BR/US →
   IDs; prose → implicit requirements per paragraph or "shall"/"must"
   sentence).
3. Output the candidates as `source_candidates` (list of strings).
   If fewer than 1 or more than ~50 candidates are available — fail with
   `on_source_doc_too_vague`.
4. Ask the human: **"Which one to spec out?"** (single, by ID) or
   **"Spec them all sequentially?"** (bulk mode — explicit choice,
   not assumed).
5. If the human picks one (or default): proceed to Step 2 with that
   specific requirement as the focus of the dialogue.
6. If the human picks bulk: — generate drafts one at a time, getting
   human confirmation between each. **Do not silently emit N drafts.**

Examples of valid `source_doc` shapes:

```
# Structured (BR list)
BR-1  Reset password via email
BR-2  Rate-limit login attempts
BR-3  Audit log for sensitive operations
...

# Prose (Confluence excerpt)
"The system shall allow users to reset their password via email.
 Login attempts must be rate-limited at 5/minute/IP.
 Sensitive operations (create, delete, export) must be audit-logged."
```

### Step 2. Clarifying questions

Ask the human **at least 3, at most 7 questions** for every ambiguity
in the list below. If the answer is already given in the original idea
or context — skip it.

- **Who** will consume the outcome? (target segment / role)
- **What pain** are we addressing? (what does not work now, or costs too much)
- **How is success measured?** (at least one measurable criterion)
- **Boundaries:** what is explicitly OUT of scope?
- **Dependencies:** any external systems / teams without which this cannot fly?
- **Schedule:** a deadline or "as soon as possible"?
- **Priority:** relative to what? (if there is a backlog — which rank)

If the human cannot answer about measurability — it is a blocker. Record
it in the spec `open_questions` as `blocking: true`.

### Step 3. Generate the draft

Build an **L0 spec draft** (L0 fields only; L1/L2 are not filled here —
that is the responsibility of `write-spec` and / or plugins).

Mandatory draft fields (see `documents/spec-format.md` § L0):

- `id` — next free `REQ-DOMAIN-NNN` (scan `global/biz-spec/`).
- `title` — single, imperative, ≤120 chars.
- `status: draft`.
- `type` — `feature` / `bug` / `refactor` / `chore` / `spike` / `compliance`.
- `priority` — ask the human.
- `epic` — ID of the current epic (e.g., `EPIC-001-validate-phase0`).
- `scope.in` — ≥1 concrete outcome.
- `scope.out` — explicit non-goals.
- `acceptance_criteria` — ≥1 AC; each has `id`, `pattern`, `statement`.
  `verification` and `oracle` — **not filled at this stage**, leave the
  placeholder `<filled at stage 4 or by the risk-testing plugin>`.
- `provenance.created` — today.
- `provenance.updated` — today.
- `provenance.author` — `<human-name> + <agent-name>`.
- `provenance.source_refs` — when the draft derives from raw sources
  (an intake-buffer candidate or a `source_doc`), add one entry per raw
  requirement used, each with `path`, `anchor`, and `original_text`.
  This links the spec back to its raw source for auditability. Leave it
  empty when the idea is purely conversational.

The draft is **not written to files** — it is the chat result handed off
to `write-spec`.

### Step 4. Conflicts (if any)

If during context analysis (Step 1) you discover the new spec contradicts
an existing one:

1. **Do not silently fix it.** Record the conflict in the brainstorm output
   (as a `conflicts` field in the draft).
2. Hand the conflict off to `write-spec` — it will create `docs/conflict-NNN.md`.

Common cases:

- New REQ overlaps an existing one → choose: replace / deprecates / alternative.
- New REQ requires what an existing REQ forbids → contradict.
- New REQ extends an existing one → extends.

### Step 5. Handoff

Return to the human:

- The spec draft itself.
- The list of clarifications you had to make.
- The list of conflicts, if any.
- A recommendation: "hand off to `write-spec` or discuss the conflicts further".

---

## Anti-patterns

- ❌ Generating a spec without reading existing REQs → drift.
- ❌ Filling `verification` and `oracle` at the brainstorm stage → that is
  the responsibility of `plan` / the `risk-testing` plugin, not brainstorm.
- ❌ Using `assumptions_policy = assume_silently` → hidden coupling.
- ❌ Asking only one question, or only "how" — you will miss "why".
- ❌ Returning a draft without an `id` — impossible to trace.
- ❌ Emitting multiple L0 drafts from a single brainstorm run without
  explicit human confirmation per draft — one run = one draft (or one
  draft at a time in bulk mode).
- ❌ Inventing requirements when `source_doc` is vague — return
  `on_source_doc_too_vague` and ask the human to disambiguate.
- ❌ Skipping `source_doc` reading when it is provided — the human
  gave you a structured input; use it instead of re-deriving.

---

## Claim / Verify

- **Claim:** "Spec draft formed with awareness of `artifacts/` context
  (and `source_doc` if provided)".
- **Verify (run by the `verify` skill at stage 4):**
  - `id` is unique in `global/biz-spec/`.
  - All L0 fields are filled (status=draft is acceptable).
  - `acceptance_criteria` has ≥1 AC.
  - Conflicts are either resolved or recorded in `conflict-NNN.md`.
  - If the draft derives from raw sources (intake-buffer candidate or
    `source_doc`), its `provenance.source_refs` lists the source paths,
    anchors, and original text.
