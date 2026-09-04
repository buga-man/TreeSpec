---
id: docs/validation
kind: validation-catalog
epic: EPIC-007-validation-protocol-doc
req: REQ-VALID-003
status: canonical
language: en
---

# Validation protocol

Canonical catalog of **what TreeSpec validates, where, against what
source, and how to extend it**. This is the single source of truth the
`verify` skill and CI drive against, so that the mechanical asserts and
the prose never silently diverge.

Source of REQ: `artifacts/global/biz-spec/REQ-VALID-003.md` (Phase 1 /
Epic-1.3). Conceptual roots it is derived from live under the kit:
`skills/tree-spec/documents/spec-format.md` (spec L0 rules),
`skills/tree-spec/documents/references/artifacts-layout.md` (artifact
shape), and `skills/tree-spec/SKILL.md § Validation (fail-closed)` (the
router procedure this document catalogues).

## Notation

- **Severity** — how the failure surfaces:
  - `FAIL (fail-closed)` — stops the run, non-zero exit, **no routing /
    no gate closes**. Used for contract and pre-flight invariants.
  - `FAIL` — counted as a failure but is a diagnostic report; the test
    still exits non-zero so CI catches it. Used for mechanical rule
    checks.
  - `WARN` — informational; does not affect the exit code. Used only for
    schema-deferred asserts (pre-v0.2 manifests).
- **Fail mode** — what the assert guards against: `false positive`
  (rejecting a good input) or `false negative` (accepting a bad input).
  Mechanical asserts are built to kill false negatives.
- **AC pattern** — the EARS pattern from `spec-format.md §4` each AC is
  written in; determines the verification method.

## Validation route

Validation happens in **three cascading phases**. Each phase is a
gate; if an earlier phase fails the later ones do not run.

```
        +---------------------------------------------------+
  any   |  PHASE 0 — router pre-flight (fail-closed)        |
  start |  skills/tree-spec/SKILL.md § Validation (fail-closed)
        |  4 checks, exits the session on any failure
        +-------------------+-------------------------------+
                            | pass
        +-------------------v-------------------------------+
        |  PHASE 1 — mechanical per-rule tests (exit 0 iff   |
        |  all pass)                                          |
        |  tests/run-all.sh                                   |
        |    - tests/manifest/test-rules.sh   (schema-aware)  |
        |    - tests/manifest/test-backward-compat.sh (REQ-VALID-002) |
        |    - tests/spec/test-rules.sh                         |
        |    - tests/router/test-rules.sh                       |
        +-------------------+-------------------------------+
                            | pass
        +-------------------v-------------------------------+
        |  PHASE 2 — spec AC oracles                          |
        |  <skill>/<area>/test-contract.sh runs each spec's  |
        |  static_analysis/verification oracles               |
        |  FAIL → docs/conflict-NN.md (not a code fix)        |
        +-----------------------------------------------------+
```

- **Phase 0** (fail-closed) is the router's human-described procedure.
  It is the **design**; `tests/router/test-rules.sh` is its mechanical
  mirror. Both must pass. Severity `FAIL (fail-closed)`.
- **Phase 1** is the canonical pre-flight (REQ-VALID-001). Runs without
  an agent in the loop. Exit 0 iff every assertion passes — the exit
  code is the failure count, capped at 255. See §4 Exit semantics.
- **Phase 2** is `verify` running each spec's AC oracles against their
  `verification.oracle`. Not in this catalog's check table; it is the
  per-AC execution layer. See §5 Phase 2 boundary.

## Check catalog

Every row is one mechanical assertion. Test scripts are the executable
artifacts; the ID + source + severity describe it.

### Reference table (test scripts)

Every script in `tests/{manifest,spec,router}` is referenced at least
here (route) and below (catalog), so the catalog is self-indexing.

| # | Script | Runs | Severity |
| --- | -------- | ------ | ---------- |
| 1 | `tests/manifest/test-rules.sh` | manifest v0.2 rule assertions | FAIL |
| 2 | `tests/manifest/test-backward-compat.sh` | phase_0 manifest gate (REQ-VALID-002) | FAIL |
| 3 | `tests/spec/test-rules.sh` | spec L0 field rule assertions | FAIL |
| 4 | `tests/router/test-rules.sh` | router fail-closed check mirror | FAIL (fail-closed) |
| 5 | `tests/manifest/test-rules.sh` | manifest rules (detailed below) | FAIL |
| 6 | `tests/manifest/test-backward-compat.sh` | backward-compat gate (detailed below) | FAIL |
| 7 | `tests/spec/test-rules.sh` | spec rules (detailed below) | FAIL |
| 8 | `tests/router/test-rules.sh` | router checks (detailed below) | FAIL (fail-closed) |

### Manifest rules — `tests/manifest/test-rules.sh`

Source: `skills/tree-spec/documents/spec-format.md` (field grammar) +
`CON-10` (manifest v0.2) + `SKILL.md § Validation (fail-closed)`.
Coverage map: 001–007 required sections; 008 `kernel.version` semver;
009 `identity.name` kebab; 010 `skills.*.file` resolves; 011 stage
`entry_skill ∈ skills`; 012 gate skill participant; 013 `[epic]` present;
014 `[meta].language` whitelist; 015 `evaluation` present; 016–017
classification schema (REQ-EXEC-001 / EPIC-009): 016 four fields present,
017 enum + flaky_tolerance fraction; 018 stdlib guard.

Schema awareness (REQ-VALID-002 / EPIC-006): asserts 003, 010, 013, 014
are v0.2-era; on a pre-v0.2 manifest they report an explicit `WARN`
SKIP with reason and never affect the exit code.

| # | Assertion | Rule | Source of truth | test location | Sev |
| --- | ----------- | ------ | ----------------- | --------------- | ----- |
| M-001 | `identity` present | `[identity]` required section | `spec-format.md §6` / CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-001` | FAIL |
| M-002 | `kernel` present | `[kernel]` required section | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-002` | FAIL |
| M-003 | `meta` present | `[meta]` required section | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-003` | FAIL (v0.2) |
| M-004 | `pipeline` present | `[pipeline]` required section | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-004` | FAIL |
| M-005 | `pipeline.stages` present | stages table required | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-005` | FAIL |
| M-006 | `pipeline.skills` present | skills table required | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-006` | FAIL |
| M-007 | `pipeline.gates` present | gates table required | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-007` | FAIL |
| M-008 | `kernel.version` semver | `0.x.y(-pre+build)?` phase-0 strict | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-008` | FAIL |
| M-009 | `identity.name` kebab | `[a-z][a-z0-9-]*` | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-009` | FAIL |
| M-010 | `skills.*.file` resolves | each `[pipeline.skills.*].file` exists under `skills/tree-spec/` | `SKILL.md Manifest v0.2 resolution` | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-010` | FAIL (v0.2) |
| M-011 | stage `entry_skill ∈ skills` | every stage's `entry_skill` ∈ `[pipeline.skills]` | `SKILL.md § Capabilities` | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-011` | FAIL |
| M-012 | gate skill participant | every gate participant of `kind=skill` names a declared skill | `SKILL.md § Validation` | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-012` | FAIL |
| M-013 | `[epic]` present | machine-maintained pointer key exists | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-013` | FAIL (v0.2) |
| M-014 | `[meta].language` whitelist | `en` or `ru` | `spec-format.md §8` | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-014` | FAIL (v0.2) |
| M-015 | `evaluation` present | user-owned cross-cutting section present | CON-10 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-015` | FAIL |
| M-016 | stdlib guard | no `pip install` / `requirements.txt` in `tests/manifest/` | REQ-VALID-001 AC-7 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-016` | FAIL |
| M-017 | four classification fields present | every `[pipeline.skills.<id>]` declares `classification`, `reproducibility`, `execution_mode`, `flaky_tolerance` (non-empty); names skill + field on missing | REQ-EXEC-001 AC-1 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-017` | FAIL (v0.2) |
| M-018 | classification enum + flaky_tolerance fraction | `classification ∈ {pure,stochastic,hybrid}`, `reproducibility ∈ {strict,best-effort,none}`, `execution_mode ∈ {single,best-of-n,consensus}`, `flaky_tolerance` a fraction in [0,1]; names rejected value | REQ-EXEC-001 AC-2 | `tests/manifest/test-rules.sh` `ASSERT-MANIFEST-018` | FAIL (v0.2) |

### Backward-compat gate — `tests/manifest/test-backward-compat.sh`

Source: `REQ-VALID-002` (EPIC-006). Guards the frozen phase_0 manifest
so new rules never silently cut off pre-v0.2 consumers.

| # | Assertion | Rule | Source of truth | test location | Sev |
|---|-----------|------|-----------------|---------------|-----|
| BWC-001 | fixture verbatim | fixture is a byte-identical copy of canonical phase_0 source | `SKILL.md § Capabilities` | `tests/manifest/test-backward-compat.sh` `ASSERT-MANIFEST-BWC-001` | WARN (SKIP if source absent) |
| BWC-002 | rules pass on fixture | all manifest asserts pass against the frozen baseline | `tests/manifest/test-rules.sh` | `tests/manifest/test-backward-compat.sh` `ASSERT-MANIFEST-BWC-002` | WARN (SKIP if source absent) |

### Spec L0 rules — `tests/spec/test-rules.sh`

Source: `skills/tree-spec/documents/spec-format.md §6` (L0 fields).
Coverage map walks every `tests/_fixtures/biz-spec/REQ-*.md`.
S-017 is a per-REQ verdict on the **live** `artifacts/global/biz-spec/REQ-EXEC-003.md`
(not a fixture walk): it fails spec validation unless that REQ declares a
non-empty `selection_criteria` (EPIC-011 verdict at epic init).

| # | Assertion | Rule | Source of truth | test location | Sev |
| --- | ----------- | ------ | ----------------- | --------------- | ----- |
| S-001 | id regex | `^REQ-[A-Z]{2,8}-\d{3}$` | `spec-format.md §3` | `tests/spec/test-rules.sh` `ASSERT-SPEC-001` | FAIL |
| S-002 | id unique | id unique across the directory | `spec-format.md §3` | `tests/spec/test-rules.sh` `ASSERT-SPEC-002` | FAIL |
| S-003 | title non-empty | `title` non-empty string | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-003` | FAIL |
| S-004 | title length | `title ≤ 120` characters | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-004` | FAIL |
| S-005 | status enum | `status ∈ {draft, approved, implemented, done}` | `spec-format.md §5` | `tests/spec/test-rules.sh` `ASSERT-SPEC-005` | FAIL |
| S-006 | type enum | `type ∈ {feature, bug, refactor, chore, spike, compliance}` | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-006` | FAIL |
| S-007 | priority enum | `priority ∈ {critical, high, medium, low}` | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-007` | FAIL |
| S-008 | epic regex | `epic matches ^EPIC-\d{3}-[a-z][a-z0-9-]*$` | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-008` | FAIL |
| S-009 | scope.in non-empty | `scope.in` non-empty list of non-empty strings | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-009` | FAIL |
| S-010 | AC ≥ 1 | `acceptance_criteria` non-empty | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-010` | FAIL |
| S-011 | AC ids unique | AC ids unique within each spec | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-011` | FAIL |
| S-012 | `provenance.created` | `YYYY-MM-DD` | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-012` | FAIL |
| S-013 | `provenance.updated` | `YYYY-MM-DD` | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-013` | FAIL |
| S-014 | `provenance.author` | non-empty | `spec-format.md §6` | `tests/spec/test-rules.sh` `ASSERT-SPEC-014` | FAIL |
| S-015 | `source_refs` resolves | if present, every `.path` resolves relative to spec dir | `spec-format.md §6` (REQ-TRACE-001 AC-3) | `tests/spec/test-rules.sh` `ASSERT-SPEC-015` | FAIL |
| S-016 | stdlib guard | no `pip install` / `requirements.txt` in `tests/spec/` | REQ-VALID-001 AC-7 | `tests/spec/test-rules.sh` `ASSERT-SPEC-016` | FAIL |
| S-017 | `selection_criteria` present | REQ-EXEC-003 declares a non-empty spec-level `selection_criteria` (EPIC-011 verdict at epic init) | `spec-format.md §6` / REQ-EXEC-003 | `tests/spec/test-rules.sh` `ASSERT-SPEC-017` | FAIL |

### Router fail-closed mirror — `tests/router/test-rules.sh`

Mechanical mirror of the router's 4 documented checks
(`SKILL.md § Validation (fail-closed)`). Each check name is quoted
verbatim from the source.

| # | Assertion | Rule | Source of truth | test location | Sev |
| --- | ----------- | ------ | ----------------- | --------------- | ----- |
| R-001 | kernel version | `[kernel].version` matches `^0\.1\.[0-9]+(-[A-Za-z0-9.-]+)?$` | `SKILL.md § Validation` | `tests/router/test-rules.sh` `ASSERT-ROUTER-001` | FAIL (fail-closed) |
| R-002 | file paths | every `[pipeline.skills.*].file` resolves under `skills/tree-spec/` | `SKILL.md Manifest v0.2 resolution` | `tests/router/test-rules.sh` `ASSERT-ROUTER-002` | FAIL (fail-closed) |
| R-003 | entry skills | every stage's `entry_skill ∈ stage.skills AND ∈ [pipeline.skills]` | `SKILL.md § Capabilities` | `tests/router/test-rules.sh` `ASSERT-ROUTER-003` | FAIL (fail-closed) |
| R-004 | gate skills | every gate participant of `kind=skill` names a declared skill | `SKILL.md § Validation` | `tests/router/test-rules.sh` `ASSERT-ROUTER-004` | FAIL (fail-closed) |
| R-005 | stdlib guard | no `pip install` / `requirements.txt` in `tests/router/` | REQ-VALID-001 AC-7 | `tests/router/test-rules.sh` `ASSERT-ROUTER-005` | FAIL (fail-closed) |

## Extension convention

How to add a new validation rule and keep the catalog from rotting. Keep
these three in sync in **one change**:

1. **Add the assert** under the relevant area — `tests/<area>/`, named
   `test-rules.sh`, sourced via `. "$(dirname "$0")/../_lib/common.sh"`.
   Give it a stable id `ASSERT-<GROUP>-NNN` (never reused); print it in
   the assert name so `common.sh` reports it on pass/fail.
2. **Add a catalog row** in the section above for that area, pointing at
   the script + exact assertion id. Renumbering rows is a PR-sized
   change with an explicit diff (catalog is append-only in spirit).
3. **Link the manifest** (if it's a manifest rule). New manifest rules
   that would break the frozen phase_0 fixture must go through the
   backward-compat gate: defer, opt in via `[kernel].compatibility`
   `lenient`, or add migration notes (REQ-VALID-002).

Checklist to close: `bash tests/run-all.sh` passes, `bash
tests/fixtures/test-synthetic.sh` passes (rule fires on its bad
fixture), and the catalog row above exists.

## Exit semantics

Bash test scripts (`common.sh`):

- Exit code = **number of failed assertions**, capped at 255.
  `report_and_exit` prints `PASS — N assertions` (exit 0) or
  `FAIL — P passed, F failed` (exit 1).
- **Skips never affect the exit code** — a `WARN`-severity assert
  (schema-deferred, missing canonical source) reports `~ SKIP …` and
  returns early.
- **`tests/run-all.sh`** (entry point) aggregates across all groups and
  exits 0 **iff every script exits 0**. It does not include the synthetic
  harness (that would always go red — its fixtures are intentionally bad).
- **Color-on-TTY**: `common.sh` enables green `✓` / red `✗` / yellow
  `~ SKIP` / heading colour only when stdout is a TTY (`[ -t 1 ]`);
  otherwise colour is stripped and output stays machine-parsable.
- **Per-assertion output**: each assert prints its full name
  (`ASSERT-<GROUP>-NNN: …`) on pass/fail, so a red run names the
  failing rule without needing to read the script.

## Phase 2 boundary

What this catalog **does not** cover (mechanical pre-flight stops at
phase 1). Everything below moves to phase 2 tooling / semantic checks:

- **Semantic conflicts** — REQ ↔ REQ contradictions, epic ↔ requirement
  mismatches, requirement ↔ north-star alignment. These need judgement,
  not a regex; handled by the human `G_spec`/`G_plan` gates.
- **Spec ↔ spec** — `depends_on` cycles, orphan REQs, coverage gaps
  against the idea. Structural in CI is possible, but semantic
  correctness is a review concern.
- **Rule semantics vs. rule presence** — the catalog asserts a rule
  *exists and fires on the right fixture*; it does not grade whether the
  rule *means* the right thing. That is the linter-ai / plugin-loader
  domain (EPIC-008 territory).
- **Auto-generated catalog** — auto-generating this catalog from the
  asserts (scope `out`) is phase 2+. For now it is hand-maintained
  alongside the asserts; §4 extension convention is how you keep them in
  sync without a generator.

> **Canonical scope:** `documents/validation.md` sits at the repository
> root, deliberately distinct from `documents/phases/` and
> `documents/concepts/`. I18n (REQ-I18N-001) does not localize this — it
> is English-only and machine-verifiable.
