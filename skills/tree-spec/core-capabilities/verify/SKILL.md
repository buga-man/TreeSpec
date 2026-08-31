---
id: verify
name: verify
description: verify
version: 0.1.0
phase: 0
stage: verify
classification: pure                    # deterministically executes oracles

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - epic_id: string                       # EPIC-NNN-slug
  - spec_refs: [REQ-DOMAIN-NNN]           # related specs
  - report_refs: [path]                   # paths to report-NN.md
output:
  - verification_md: path                 # artifacts/epics/<EPIC>/docs/verification.md

side_effects:
  - runs oracles from acceptance_criteria (per verification.command, if present)
  - writes evidence (stdout, junit, logs) into docs/verification.md
  - does NOT modify code (only verifies)

failure_handling:
  - on_oracle_fail: "record fail in verification.md; do not fix code (that is a return to stage 3)"
  - on_missing_oracle: "conflict doc — the spec is incomplete"
  - on_environment_mismatch: "verification.md marked environment=local, not ci"

composition:
  - may_invoke: []                        # phase 0: no runtime
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: verify

**Stage:** 4 (Verify). **Launched** by the agent after all epic tasks are done.
**Purpose:** **mechanically** run the AC oracles and capture evidence for
gate G_done [Human].

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.verify]` (exit criteria, gate) and
> `[pipeline.skills.verify]` (this skill's contract). The manifest is
> the contract; this markdown is the procedure. If they ever disagree,
> the manifest wins — escalate to the human.

---

## Procedure

### Step 1. Context

Read:

1. `artifacts/epics/<EPIC>/STATUS.md` — are all tasks `done`?
2. `artifacts/epics/<EPIC>/tasks.md` — task list.
3. `artifacts/global/biz-spec/REQ-DOMAIN-NNN.md` — ACs, oracles.
4. `artifacts/epics/<EPIC>/docs/report-NN.md` — implementation reports.
5. `artifacts/epics/<EPIC>/docs/feasibility.md` — known risks.
6. `tree-spec.toml` — which skills are active (for discovery).

### Step 2. Collect oracles

From every spec related to the epic, collect:

- `id`, `title`, `priority`.
- All `acceptance_criteria[*]` with fields `id`, `pattern`, `statement`,
  `verification.{method, command, environment, oracle, evidence_required, evidence_format}`.

If even one AC has `verification.oracle` unfilled — it is a **blocker**:
create `docs/conflict-NNN.md` and stop. Without an oracle there is nothing
to verify.

### Step 3. Run oracles

For each AC:

1. If `verification.command != null` — **run** the command.
2. If `verification.command == null` — that means "manual check";
   set `status = manual_pending`.
3. Compare the observed value with `verification.oracle`.
4. Record:
   - **PASS** — observed matches oracle.
   - **FAIL** — does not match.
   - **SKIP** — environment unavailable (e.g., ci run cannot be triggered locally).

Sample entry in verification.md:

```yaml
- ac: AC-1
  spec: REQ-DOMAIN-NNN
  pattern: event_driven
  oracle: { status_code: 200 }
  observed: { status_code: 200 }
  status: pass
  evidence: docs/evidence/REQ-DOMAIN-NNN_AC-1.junit.xml
  command: "curl -X POST localhost:8080/api/auth/login -d '{...}' -o /dev/null -w '%{http_code}'"
  environment: local
  timestamp: YYYY-MM-DDTHH:MM:SSZ
```

### Step 4. Collect evidence

If `evidence_required = true`:

- Save the run artifact into `docs/evidence/REQ-DOMAIN-NNN_AC-N.junit_xml`
  (or in the format from `evidence_format`).
- Reference the path in `verification.md`.

If `evidence_required = false`:

- `observed` in verification.md is enough.

### Step 5. verification.md

Create `artifacts/epics/<EPIC>/docs/verification.md`:

```markdown
# Verification — EPIC-XXX

**Date:** YYYY-MM-DD
**Agent:** <id>
**Environment:** local | ci | staging

## Summary

| Metric | Value |
|---|---|
| ACs checked | N |
| PASS | N |
| FAIL | N |
| SKIP | N (with justification) |
| MANUAL_PENDING | N |

## Details

### REQ-DOMAIN-NNN — <title>

**Priority:** high
**Spec status:** implemented (checked before moving to done)

#### AC-1: <statement>

- Pattern: event_driven
- Oracle: { status_code: 200 }
- Observed: { status_code: 200 }
- Status: pass | fail | skip | manual_pending
- Evidence: <path or null>
- Notes: ...

(repeat for each AC)

## Open issues

- ...

## Readiness for G_done

- [ ] All FAILs addressed (or a conflict doc with a decision)
- [ ] No unjustified SKIPs
- [ ] No MANUAL_PENDING without a human check plan
```

### Step 6. If there are FAILs

Do not fix the code yourself. That is a **return** to stage 3:

1. Create `docs/conflict-NNN.md` describing which AC failed.
2. Update `tasks.md` → the relevant task `blocked`.
3. `STATUS.md` → "return to stage 3 required".
4. `PATH.md` → entry for the return (stage 4 → stage 3).

The human decides how to fix (via `implement` again or by revising the spec).

### Step 7. Handoff

Return to the human:

- `docs/verification.md`.
- The pass/fail/skip/manual_pending summary.
- The list of open FAILs (if any).

**Verification complete → G_done [Human].**

The human decides. After acceptance: spec `status` → `done`,
`STATUS.md` / `DECISIONS.md` / `PATH.md` updated.

---

## Anti-patterns

- ❌ Verifying ACs "by eye" — that is not an oracle, that is wishful thinking.
- ❌ Skipping FAIL without recording — silent drift.
- ❌ Fixing code from the verify skill — not its job (separate stage 3).
- ❌ Treating SKIP = PASS without justification.
- ❌ Running `verification.command` in production without explicit
  approval (if environment = production — stop).

---

## Claim / Verify

- **Claim:** "All ACs verified mechanically against oracles, evidence
  captured, FAILs opened through conflict docs".
- **Verify (run by the human at G_done):**
  - The pass/fail/skip summary is consistent.
  - All FAILs have a conflict doc with a decision.
  - Evidence files exist and are readable.
  - No silent assumptions.
