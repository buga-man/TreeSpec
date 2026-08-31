---
id: plan
name: plan
description: plan idea
version: 0.1.0
phase: 0
stage: plan
classification: hybrid                 # structure is deterministic, estimates are stochastic

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - approved_spec: path                   # artifacts/global/biz-spec/REQ-DOMAIN-NNN.md (status=approved)
  - epic_id: string                       # EPIC-NNN-slug
output:
  - tasks_md: path                        # artifacts/epics/<EPIC>/tasks.md
  - feasibility_md: path                  # artifacts/epics/<EPIC>/docs/feasibility.md
  - system_analysis_md: path | null       # artifacts/epics/<EPIC>/docs/system-analysis.md (if APIs)

side_effects:
  - creates tasks.md
  - creates docs/feasibility.md
  - may create docs/system-analysis.md
  - does NOT modify the spec (only registers tasks in the epic)

failure_handling:
  - on_ambiguous_complexity: "return to brainstorm/write-spec; do not guess S/M/L/XL"
  - on_external_dependency: "flag as risk_flag in feasibility"
  - on_circular_dependency: "refuse; conflict doc"

composition: []
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: plan

**Stage:** 2 (Plan). **Launched** by the agent after G_spec is passed.
**Purpose:** decompose an approved spec into **tasks** with complexity,
ACs, REQ links, and feasibility analysis.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.plan]` (exit criteria, gate) and
> `[pipeline.skills.plan]` (this skill's contract). The manifest is the
> contract; this markdown is the procedure. If they ever disagree, the
> manifest wins — escalate to the human.

---

## Procedure

### Step 1. Context

Read:

1. `artifacts/global/biz-spec/REQ-DOMAIN-NNN.md` — the approved spec.
2. `artifacts/epics/<EPIC>/docs/biz-spec-delta.md` — which REQs the epic covers.
3. `artifacts/epics/<EPIC>/STATUS.md` — current state of the epic.
4. `artifacts/INDEX.md` — which epics / tasks are in flight (any resource conflicts?).
5. If specified — read the specs in `depends_on`.

### Step 2. Decompose into tasks

One AC from the spec = one or several tasks. Rules:

- AC with `pattern = ubiquitous` / `optional` — either its own task (if
  measurable) or part of another task.
- AC with `pattern = event_driven` / `state_driven` / `error` — its own task
  with an explicit trigger.
- AC with `pattern = unwanted` — its own task with a forbid-test.

Each task gets:

- `T-NN` (NN — two-digit number with a leading zero, in generation order).
- Name — single, imperative, ≤80 chars.
- REQs — list of REQs it covers.
- Complexity — S/M/L/XL (see Step 3).
- Acceptance criteria — 1–5 measurable items.
- API contracts — if the task introduces / modifies a public API (link to
  system-analysis.md or "none").

### Step 3. Estimate complexity (S/M/L/XL)

Criteria — from `documents/artifacts.md` § "Complexity":

| Size | Repos / modules | API | Migrations | Novelty |
|---|---|---|---|---|
| **S** | 1 module | none | none | repeats a pattern |
| **M** | 1–2 modules | internal | none | partially new |
| **L** | 3+ modules or 2 repos | new public | local | new domain logic |
| **XL** | 3+ repos | breaking | global | new architecture area |

**Rules:**

- Estimate **each task**, not the epic.
- Epic complexity = max over tasks (not the sum).
- XL = mandatory human code review at stage 3.
- L+XL = require an explicit feasibility justification.
- If you cannot judge novelty — it is a risk flag; record it in feasibility.

### Step 4. Inter-task dependencies

Build the task DAG:

- Task T-X depends on T-Y if T-X cannot start without T-Y's outcome.
- **No cycles.** If you find one — refuse and request intervention.
- Cross-epic dependencies are a separate topic (phase 3+).

Dependencies are recorded explicitly in `tasks.md`: `depends_on: [T-02, T-03]`.

### Step 5. feasibility.md

Create `artifacts/epics/<EPIC>/docs/feasibility.md`:

```markdown
# Feasibility — EPIC-XXX

## Summary

| Metric | Value |
|---|---|
| Total tasks | N |
| Most complex | T-NN (XL) |
| Aggregate complexity (max) | XL |
| API contracts | N new / M modified |
| Migrations | yes/no (if yes — which) |
| External dependencies | list |

## Risks

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| 1 | ... | low/med/high | low/med/high | ... |

## Open questions

- ...

## Recommendation

- Ready for G_plan [Human]? yes/no
- Should the epic be decomposed further? yes/no
```

### Step 6. system-analysis.md (if there is API work)

If at least one task introduces / modifies a public API, create
`docs/system-analysis.md`:

```markdown
# System Analysis — EPIC-XXX

## Contracts

### T-NN: <name>
- Provides: <what it gives the world>
- Consumes: <what it needs>
- Signature: <contract (HTTP, function, event)>

## Changes to existing APIs

- <endpoint>: before → after, justification

## Backward compatibility

- Breaking changes: yes/no
- Migration plan: <if yes>
```

### Step 7. tasks.md

Create / update `artifacts/epics/<EPIC>/tasks.md`. There is no template
file — the layout is fully described in
`documents/references/artifacts-layout.md` (per-epic folder section).
Fill in:

- Status overview (table).
- Each task as its own T-NN section with the fields above.

### Step 8. Handoff

Return to the human:

- The list of tasks with complexity.
- The dependency map.
- The risk list from feasibility.
- The filled feasibility.md and tasks.md.

**The plan is ready for G_plan [Human].**

The human adjusts complexity, adds / removes tasks. After approval —
STATUS.md and DECISIONS.md are updated.

---

## Anti-patterns

- ❌ Summing complexity (3×M = XL) — epic complexity = max over tasks.
- ❌ Estimating complexity without analysing novelty.
- ❌ Hiding inter-task dependencies (implicit composition = invariant 6).
- ❌ Writing feasibility as "everything will be fine" — that is not feasibility.
- ❌ Creating tasks.md without REQ links — you lose traceability.

---

## Claim / Verify

- **Claim:** "Spec decomposed into tasks with complexity, dependencies,
  and feasibility analysis".
- **Verify (run by the `verify` skill):**
  - Every task has an REQ link.
  - Every complexity estimate is justified.
  - The task DAG has no cycles.
  - All AC risks are recorded in feasibility.
  - tasks.md conforms to the per-epic layout in
    `documents/references/artifacts-layout.md`.
