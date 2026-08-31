# plan — mock scenarios

## Scenario 1: simple spec with 3 ACs

**Setup:** Spec has 3 acceptance_criteria; each maps to one task.

**Expected output:**
- `tasks.md` with T-01, T-02, T-03.
- Each task: REQ link, complexity (S/M/L/XL) with justification,
  acceptance criteria, dependencies DAG (likely linear: T-02
  depends on T-01, T-03 on T-02).
- `feasibility.md` with summary, risks, recommendation.

## Scenario 2: spec with API changes

**Setup:** Spec introduces a new REST endpoint.

**Expected output:**
- `tasks.md` decomposes the work into implementation + tests + docs.
- `system-analysis.md` created with the endpoint contract
  (`POST /tokens/reset`, request/response shape, breaking-change
  assessment = "no").
- Complexity is at least M (new API surface).

## Scenario 3: circular dependency detected

**Setup:** Brainstorm output implies T-02 depends on T-03 AND
T-03 depends on T-02.

**Expected behaviour:**
- `plan` refuses to write `tasks.md`.
- Returns error to brainstorm / human.
- Does NOT silently pick a direction or break the cycle.