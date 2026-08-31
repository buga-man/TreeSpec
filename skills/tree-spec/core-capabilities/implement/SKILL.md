---
id: implement
name: implement
description: implement plans
version: 0.1.0
phase: 0
stage: implement
classification: hybrid

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - task: ref                             # T-NN from the epic tasks.md
  - spec_refs: [REQ-DOMAIN-NNN]           # related specs
output:
  - code_changes: path[]                  # list of files changed
  - report_md: path                       # artifacts/epics/<EPIC>/docs/report-NN.md

side_effects:
  - changes files in the repo (code/tests/docs)
  - creates docs/report-NN.md
  - updates tasks.md (task status)
  - updates the epic STATUS.md
  - may create docs/conflict-NNN.md

failure_handling:
  - on_test_failure: "record in report, do not silently fix"
  - on_breaking_change: "create conflict doc, do not merge"
  - on_missing_dependency: "conflict doc, do not assume"
  - on_scope_creep: "conflict doc, do not widen scope.in without G_plan"

composition:
  - may_invoke: []                        # phase 0: no runtime composition
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: implement

**Stage:** 3 (Implement). **Launched** by the agent, one task at a time.
**Purpose:** implement a task with a **claim/verify report**, staying
inside the spec scope and not breaking ACs.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.implement]` (exit criteria) and
> `[pipeline.skills.implement]` (this skill's contract). The manifest
> is the contract; this markdown is the procedure. If they ever
> disagree, the manifest wins — escalate to the human.

---

## Procedure

### Step 1. Context (mandatory)

Read **before** any edits:

1. `artifacts/epics/<EPIC>/STATUS.md` — current state.
2. `artifacts/epics/<EPIC>/tasks.md` — your T-NN row, acceptance criteria.
3. Related specs (`spec_refs`) — in full, especially ACs and `scope.out`.
4. `docs/feasibility.md` and `docs/system-analysis.md` — if any.
5. `PATH.md` — do not repeat disproved approaches.
6. `DECISIONS.md` — do not reopen decided items.

### Step 2. Check preconditions

Before starting, verify:

- All `depends_on` tasks are in status `done`. If not — stop.
- No open conflict docs block this task.
- Required permissions (read/write on files) are available.

If anything is off — stop. Update `tasks.md` → `blocked`, write to `STATUS.md`.

### Step 3. Implementation

Rules:

- **Stay inside `scope.in`** of the relevant spec. `scope.out` is taboo.
- **Minimal changes.** No drive-by refactors. If a refactor is needed —
  open task T-NN+1.
- **Do not touch** files outside `permissions.write` (if declared in L2 `execution`).
- **Do not deploy** to production without explicit approval (if L2 `forbidden_actions`).
- **No magic values** — all numbers / strings through named constants.

### Step 4. Claim/Verify report

Create `artifacts/epics/<EPIC>/docs/report-NN.md` per the template
`../../documents/assets/report.template.md`. Fill the frontmatter **completely**:

```yaml
task_id: T-NN
req_refs: [REQ-DOMAIN-NNN]
spec_refs: [REQ-DOMAIN-NNN]
epic: EPIC-XXX-slug
agent: <agent-id>
timestamp: <ISO-8601 UTC>
tools: [<used skills / tools>]

# AC COVERAGE — critical
ac_coverage:
  - ac: AC-1
    status: satisfied | partial | not_covered
    evidence: "<what confirms completion>"
    test_refs: [<test or oracle path>]
  # ... for each AC related to this task

scope_adherence:
  in_respected: true | false
  out_respected: true | false
  deviations: []

dependencies:
  requires: [REQ-DOMAIN-NNN]
  affects: [REQ-DOMAIN-NNN]
  breaking_changes: false | true

verification:
  build_status: pass | fail | not_run
  tests_status: pass | fail | not_run
  lint_status: pass | fail | not_run
  ci_run: <link or null>
```

The body (narrative): what was done, decisions made, problems noticed.
**Do not contradict the frontmatter.**

### Step 5. Self-checks (stage exit criterion)

Before declaring the task done, run:

1. **AC coverage complete.** Every AC from the spec related to this task
   has a `status` in `ac_coverage`. `not_covered` without justification is a blocker.
2. **Evidence exists.** Every `satisfied` AC has `test_refs` or explicit
   evidence in `verification.ci_run`.
3. **Scope respected.** `out_respected: true`. If `false` — open a conflict.
4. **Lint / format / tests green** for the changed code.
5. **STATUS.md and tasks.md updated.**

### Step 6. Conflicts (if any arose)

If during implementation you find:

- A divergence between spec and reality → `docs/conflict-NNN.md` (Step 7).
- Scope creep (you want to do more than scope.in) → `docs/conflict-NNN.md`.
- A new task that was not in the plan → add to `tasks.md` with status
  `queued` (do NOT execute without G_plan).

### Step 7. Wrap up

1. Update `tasks.md`: status T-NN → `done`.
2. Update the epic `STATUS.md`: current task, progress, problems.
3. If there was a conflict — `PATH.md` entry for the return.
4. If you made a technical decision — `DECISIONS.md` entry.

---

## Anti-patterns

- ❌ Claiming "pass" without `test_refs` or `ci_run` — that is not verification,
  that is wishful thinking (invariant 3, CON-07).
- ❌ Widening scope without a conflict doc — silent drift.
- ❌ Doing several tasks at once — you lose who owns what.
- ❌ Ignoring `path.md` and repeating a disproved approach.
- ❌ Changing `dependencies` or the lockfile without explicit approval.
- ❌ Hiding a "tiny" bug fix in the task PR — file it as its own task.

---

## Claim / Verify

- **Claim:** "Task T-NN implemented within scope, report with
  ac_coverage and verification filled".
- **Verify (run by the `verify` skill at stage 4):**
  - All ACs from the spec related to the task have `status` and `evidence`.
  - `tests_status = pass` for all test_refs.
  - `out_respected = true`.
  - No open conflict docs on this task.
  - tasks.md and STATUS.md updated.
