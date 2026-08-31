# write-spec — mock scenarios

## Scenario 1: fresh project, bootstrap

**Setup:**
- `artifacts/` does **not** exist.
- Draft from brainstorm: `id=REQ-AUTH-042`, `title="Reset password via email"`,
  L0 fields all filled.

**Expected behaviour:**
1. Step 0 detects missing `artifacts/`.
2. Creates `artifacts/{README.md, INDEX.md, global/biz-spec/, epics/}`.
3. Step 2 validates L0 fields — pass.
4. Step 3 writes `artifacts/global/biz-spec/REQ-AUTH-042.md`.
5. Step 4 creates `artifacts/epics/<EPIC>/docs/biz-spec-delta.md`.
6. Step 5 appends a row to `artifacts/INDEX.md`.
7. Returns paths to the human for gate `G_spec`.

## Scenario 2: project already initialized

**Setup:**
- `artifacts/` exists with `README.md`, `INDEX.md`, `global/biz-spec/`.

**Expected behaviour:**
- Step 0 detects existing `artifacts/` and skips bootstrap.
- Proceeds to Step 2 → 3 → 4 → 5 normally.

## Scenario 3: invalid L0 (missing oracle)

**Setup:** Draft has `acceptance_criteria[0]` without `verification.oracle`.

**Expected behaviour:**
- Step 2 fails validation (`on_missing_l0_fields`).
- `write-spec` returns the error to brainstorm (or the human) and
  does NOT write the file.

## Scenario 4: duplicate id

**Setup:** `artifacts/global/biz-spec/REQ-AUTH-042.md` already exists.

**Expected behaviour:**
- Step 2 detects the duplicate.
- `write-spec` refuses to write (`on_duplicate_id`).
- Returns the conflict for resolution; does NOT silently overwrite.