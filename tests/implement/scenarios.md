# implement — mock scenarios

## Scenario 1: simple task, all ACs satisfied

**Setup:** T-01 from `tasks.md` is queued. Spec has 2 ACs.

**Expected output:**
- `docs/report-NN.md` with `ac_coverage` listing both ACs as `satisfied`
  with `test_refs`.
- `verification.tests_status = pass`.
- `tasks.md` row updated to `done`.
- `STATUS.md` updated with progress.

## Scenario 2: scope creep detected

**Setup:** Implementing T-02 would require touching `src/foo.py`
which is outside `scope.in` of the relevant spec.

**Expected behaviour:**
- `implement` recognises the scope creep.
- Creates `docs/conflict-NNN.md` describing the divergence.
- Does NOT silently expand the work.
- Sets `tasks.md` status of T-02 to `blocked`.

## Scenario 3: tests fail

**Setup:** Implementation runs unit tests; 1 of 5 fails.

**Expected behaviour:**
- `ac_coverage` for the related AC has `status: not_covered`.
- `verification.tests_status = fail`.
- `docs/report-NN.md` records the failure with evidence (test output).
- Self-check (Step 5) fails the gate; `implement` does NOT mark the task
  as `done`.

## Scenario 4: one task, one session

**Setup:** Agent attempts to do T-03 and T-04 in one session.

**Expected behaviour:**
- Anti-pattern: implement should refuse and update only T-03.
- Two tasks = two sessions = two reports.