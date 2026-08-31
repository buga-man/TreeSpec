# verify — mock scenarios

## Scenario 1: all oracles pass

**Setup:** Spec REQ-AUTH-042 has 3 ACs, each with a runnable oracle.

**Expected output:**
- `verification.md` with summary `PASS=3, FAIL=0, SKIP=0`.
- Each AC has observed = oracle.
- Evidence files for each AC with `evidence_required=true`.
- Ready for `G_done` [Human + verify].

## Scenario 2: one FAIL

**Setup:** AC-2 oracle returns 500 instead of 200.

**Expected behaviour:**
- `verification.md` summary: `PASS=2, FAIL=1`.
- `verify` creates `docs/conflict-NNN.md` describing the FAIL.
- Returns control to stage 3 (`implement`) — does NOT fix code.

## Scenario 3: missing oracle

**Setup:** AC has `verification.command = null` (manual check).

**Expected behaviour:**
- AC's status = `manual_pending`.
- `verify` does NOT mark it as PASS.
- `verification.md` notes that human verification is required.

## Scenario 4: environment mismatch

**Setup:** AC's `verification.environment = ci` but `verify` runs locally.

**Expected behaviour:**
- AC's status = `SKIP` with justification `environment=local`.
- Documented in `verification.md`.