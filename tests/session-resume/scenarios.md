# session-resume — mock scenarios

These scenarios are **documentation, not auto-runnable tests**. They
describe expected agent behavior when invoking the skill under
specific conditions. The structural and contract tests verify file
content; these verify reasoning.

To make them runnable in phase 1+, wrap each scenario with a stub
agent harness.

## Scenario 1: fresh project (no `artifacts/`)

**Setup:**
- `tree-spec.toml` exists with 6 skills declared.
- `artifacts/` does **not** exist.

**Expected session-resume output:**

```markdown
# Session Resume — <no active epic>

## Recommended next action

- **Run skill:** `brainstorm` (to produce a draft)
- **Then:** `write-spec` (which bootstraps `artifacts/`)
- **Gate pending:** none
- **Conflict to resolve first:** n/a

## Warnings

- `artifacts/` is missing — `write-spec` will create it on first run.
```

## Scenario 2: project with one epic in stage 3

**Setup:**
- `artifacts/INDEX.md` has one row, status `in progress`, stage 2.
- `artifacts/epics/EPIC-007-foo/STATUS.md` says stage 3.
- `tasks.md` has T-01..T-04; T-03 is queued.

**Expected session-resume output:**

```markdown
# Session Resume — EPIC-007-foo

**Stage:** 3 — Implement
**Status:** in progress

## Current state
- Epic: EPIC-007-foo
- Stage: 3
- Last transition: 2026-08-28 — implement started (T-01 done)
- Active task: none — pick from queued
- Open conflicts: none

## Tasks overview
| T-01 | done    | S |
| T-02 | done    | S |
| T-03 | queued  | M |
| T-04 | queued  | L |

## Recommended next action
- **Run skill:** `implement` on T-03
- **Gate pending:** none
- **Conflict to resolve first:** n/a
```

## Scenario 3: open conflict doc

**Setup:**
- `artifacts/INDEX.md` shows epic in stage 3.
- `artifacts/epics/EPIC-007-foo/docs/conflict-001.md` has `Status: open`.

**Expected session-resume output:**

```markdown
# Session Resume — EPIC-007-foo

## Recommended next action

- **Stop.** Resolve `docs/conflict-001.md` before any other action.
```

The agent MUST NOT proceed to `implement` or any other skill while a
conflict doc is open.

## Scenario 4: gate pending

**Setup:**
- Spec REQ-X-001 has `status: approved`.
- `tasks.md` exists with T-01..T-03.

**Expected session-resume output:**

```markdown
# Session Resume — EPIC-XXX

**Stage:** 2 — Plan

## Recommended next action

- **Gate pending:** `G_plan` — wait for human approval before stage 3.
```

## Scenario 5: verification has FAILs

**Setup:**
- `docs/verification.md` exists with status `pass=5, fail=1, skip=0`.

**Expected session-resume output:**

```markdown
# Session Resume — EPIC-XXX

**Stage:** 4 — Verify

## Open issues
- AC-3 (REQ-X-001): FAIL — oracle returned 500

## Recommended next action

- **Open conflict doc for AC-3**, then **return to stage 3** (re-run `implement`).
```