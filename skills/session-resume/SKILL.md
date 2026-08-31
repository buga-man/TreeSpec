---
id: session-resume
name: session-resume
description: session-resume
version: 0.1.0
phase: 0
stage: any                              # run at the start of any session
classification: pure                    # read-only, deterministic

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - epic_id: string | null              # if null, detect from INDEX.md
  - language: string | null             # i18n: overrides [meta.language] for this session only
output:
  - resume_report: markdown             # human-readable summary
  - recommendations: [string]           # suggested next actions

side_effects:
  - reads artifacts/INDEX.md
  - reads artifacts/epics/<EPIC>/{STATUS,PATH,DECISIONS,tasks}.md
  - reads artifacts/epics/<EPIC>/docs/conflict-*.md (to count open conflicts)
  - reads tree-spec.toml (to validate declared skills)
  - does NOT write anything

failure_handling:
  - on_no_artifacts_dir: "report 'no artifacts/ — bootstrap via write-spec'; do NOT create files (that is write-spec's job)"
  - on_no_active_epic: "report 'no active epic' and recommend creating one"
  - on_missing_artifacts: "report the missing file and recommend running the relevant skill"
  - on_ambiguous_state: "report the state and recommend manual review"

composition: []                      # read-only, no composition
---

# Skill: session-resume

**Stage:** any — runs at the start of a session, before any other skill.
**Purpose:** recover the current epic state from the artifacts and recommend
the next action. **Read-only.** Does not run anything, does not write
anything, does not make decisions.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.skills.session-resume]` (this skill) and `[pipeline.evaluation]`
> (global rules). The manifest is the contract; this markdown is the
> procedure the agent follows to satisfy it. If they ever disagree, the
> manifest wins — escalate to the human.

---

## Procedure

### Step 1. Find the active epic

1. If `artifacts/` does not exist — this is a **fresh project**. Report
   "no artifacts/ — bootstrap via `write-spec` (run `brainstorm` first to
   get a draft)" and stop. Do **not** create files — that is `write-spec`'s
   responsibility (see its Step 0).
2. If `artifacts/INDEX.md` does not exist — same: report "no INDEX.md —
   bootstrap via `write-spec`" and stop.
3. Read `artifacts/INDEX.md`.
4. Find the first row with `Status` ∈ `{ in progress, blocked }`. That is
   the active epic.
5. If none — report "no active epic" and stop.
6. If several — pick the topmost (oldest) and warn that others are queued.

### Step 2. Read the epic state

Read **only** these four files (do not read full PATH/DECISIONS history —
just headers):

1. `artifacts/epics/<EPIC>/STATUS.md` — current stage, made, next steps,
   open problems.
2. `artifacts/epics/<EPIC>/PATH.md` — last 1–2 transitions (bottom of
   the table).
3. `artifacts/epics/<EPIC>/DECISIONS.md` — last 1–2 decisions.
4. `artifacts/epics/<EPIC>/tasks.md` — the overview table.

Plus, list files in `artifacts/epics/<EPIC>/docs/` to detect
`conflict-NNN.md` files. Open any with `Status: open`.

### Step 3. Cross-check with the manifest

Read the root `tree-spec.toml` to know:

- which skills are declared;
- which gates exist;
- whether the epic has its own `tree-spec.toml` override.

If a skill the agent might invoke is not declared — warn.

### Step 4. Determine the active language

Active language is an **output directive**, not a file-resolution
mechanism (I18N v3, DECISIONS #8/#9). There are no locale folders and no
per-locale copies of kit content: the agent reads canonical system files
(skills, references, templates) directly and only adapts its own output.
The machine contract — identifiers (REQ-*, EPIC-*, skill ids), verification
commands, oracle values, field names, and file paths — is always canonical
English and is never localized, regardless of the active language.

The session's active language is resolved in this order:

1. **Explicit request/input wins.** If the `language` input is set (or the
   user explicitly asked during the session — "делай на русском", "write in
   English"), use it for this session only. It always beats `[meta.language]`
   and auto-detect.
2. **Manifest value.** Else if `[meta.language]` is set (root manifest; an
   epic manifest may override it — CON-10 inheritance),
   `loc = [meta.language]`.
3. **Auto-detect.** Else scan the active epic's files (`STATUS.md`,
   `PATH.md`, `DECISIONS.md`, `tasks.md`, `docs/*.md`) and count
   natural-language tokens in `{en, ru}` (Cyrillic vs Latin, or common
   words) across all text. A clear majority sets the session language; a
   mixed result stays English.
4. **Default.** Else `'en'`.

The `{en, ru}` whitelist is phase 0: any other value silently falls back
to canonical English. Determination is session-scoped — it never writes to
a manifest; pinning a locale stays an explicit human edit of `[meta]`
(DECISIONS #5).

### Step 5. Determine the recommended next action

Use this decision tree (read artifacts, do not guess):

| If you observe... | Recommend |
|---|---|
| `artifacts/` does not exist | Run `brainstorm` then `write-spec` — the latter bootstraps `artifacts/` |
| `artifacts/INDEX.md` does not exist | Run `write-spec` to bootstrap |
| No spec in `global/biz-spec/` referenced by epic | Run `brainstorm` |
| Spec exists but not registered in `INDEX.md` | Run `write-spec` |
| Status = stage 1 but spec status = `approved` | Gate `G_spec` is open → wait for human |
| Status = stage 1 and spec status = `approved` and no `tasks.md` | Run `plan` |
| Status = stage 2 and `tasks.md` exists but no human sign-off (no DECISIONS entry after plan) | Gate `G_plan` is open → wait for human |
| Status = stage 3 and queued tasks exist | Run `implement` on the next queued T-NN |
| Status = stage 3 and all tasks done, no `docs/verification.md` | Run `verify` |
| Status = stage 4 and verification.md exists with FAILs | Open conflict doc for each FAIL → return to stage 3 |
| Status = stage 4 and verification.md shows PASS | Gate `G_done` is open → wait for human |
| Open conflict doc exists | **Stop. Resolve the conflict before any other action.** |
| STATUS.md and tasks.md disagree (e.g., STATUS says stage 3, but tasks table shows none done) | Report inconsistency and ask the human |

### Step 6. Output the resume report

```markdown
# Session Resume — EPIC-XXX-slug

**Date:** YYYY-MM-DD
**Stage:** N — <stage name>
**Status:** in progress | blocked

## Current state

- Epic: EPIC-XXX-slug
- Stage: N
- Last transition: <date> — <description>
- Last decision: <date> — <one-line summary> (or "none recorded")
- Active task: T-NN "<name>" <status> (or "none — pick from queued")
- Active language: <loc> (source: session input / [meta.language] / auto-detect / 'en')
- Open conflicts: <count> (or "none")

## Tasks overview

| Task | Status | Complexity |
|------|--------|------------|
| T-01 | done | S |
| T-02 | in progress | S |
| T-03 | queued | M |

## Recommended next action

- **Run skill:** <skill-id> (declared in tree-spec.toml: yes/no)
- **Gate pending:** <gate-name> or "no gate — proceed"
- **Conflict to resolve first:** <conflict-NNN.md> or "n/a"

## Warnings

- <any inconsistencies, missing files, undeclared skills>
```

### Step 7. Hand off

Return the report to the calling agent / human. **Do not invoke any skill
yourself** — `session-resume` only diagnoses, it does not act.

---

## Anti-patterns

- ❌ Invoking another skill from `session-resume` — that is implicit
  composition (invariant 6, CON-07). This skill is read-only.
- ❌ Writing to any file (even `STATUS.md`) — that is the job of the
  active skill at the end of the session, not this one.
- ❌ Returning "everything looks fine" without checking the artifacts —
  the whole point is to recover state from files, not from chat history.
- ❌ Hard-coding stage → skill mapping in code — derive it from
  tree-spec.toml + observed artifact state.
- ❌ Skipping conflict docs — they are blockers (invariant 2, CON-07).

---

## Claim / Verify

- **Claim:** "Epic state recovered from artifacts, recommended next
  action identified, no side effects".
- **Verify (manual, by the human reading the report):**
  - The "Stage" matches `STATUS.md`.
  - The "Last transition" matches the last row in `PATH.md`.
  - The "Tasks overview" matches `tasks.md`.
  - The "Recommended next action" is consistent with the actual
    artifact state (e.g., it does not recommend `verify` when no
    `report-NN.md` exists yet).
  - Open conflicts are flagged.
