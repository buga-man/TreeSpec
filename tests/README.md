# Tests

This folder contains mechanical tests that run without an agent in
the loop. Three kinds of tests live here:

- **Per-skill tests** — verify each skill's `SKILL.md` exists at the
  declared path, has the right shape, and matches its spec's ACs.
- **Per-rule tests** — verify the manifest, spec L0 fields, and the
  router's fail-closed validation procedure. These are the **mechanical
  pre-flight** for every TreeSpec run (REQ-VALID-001).
- **Synthetic harness** — drives intentionally-bad fixtures through
  the per-rule tests to catch false negatives (a rule that fails to
  detect a violation).

## Layout

```
tests/
├── README.md                       # this file
├── run-all.sh                      # entry point — runs per-skill + per-rule tests
├── _lib/
│   └── common.sh                   # shared helpers (assert_* functions)
│
├── intake/                         # per-skill test (one folder per skill)
│   ├── test-structure.sh           # file presence, frontmatter, body shape
│   ├── test-contract.sh            # matches REQ-INTAKE-001 ACs
│   └── scenarios.md                # mock scenarios (documentation)
├── session-resume/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
├── brainstorm/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
├── write-spec/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
├── plan/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
├── implement/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
├── verify/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
│
├── manifest/                       # per-rule test (one folder per rule group)
│   └── test-rules.sh               # manifest v0.2 rule assertions
├── spec/                           # (added by EPIC-005 T-04)
│   └── test-rules.sh               # spec L0 field assertions
├── router/                         # (added by EPIC-005 T-03)
│   └── test-rules.sh               # router fail-closed check mirror
│
└── fixtures/                       # synthetic test inputs (EPIC-005 T-05/T-06)
    ├── test-synthetic.sh           # the synthetic harness
    └── synthetic/
        ├── bad-empty-scope.md      # each fixture violates exactly one rule
        ├── bad-id-format.md
        ├── bad-duplicate-id.md
        ├── bad-missing-author.md
        ├── bad-status-enum.md
        └── bad-entry-skill.toml
```

## What each file does

### Per-skill tests (`tests/<skill>/test-{structure,contract}.sh`)

#### `test-structure.sh`

Verifies that the skill **exists at the declared path** and has the
**right shape**:

- File exists.
- Frontmatter opens with `---` and has required fields (id, version,
  phase, classification, stage, etc.).
- Body has the expected procedure steps (`### Step N. …`).
- Body has `## Anti-patterns` and `## Claim / Verify` sections.
- Body declares the manifest as source of truth.

These are **shape** tests — they don't verify the skill works
correctly, only that it exists and looks like a skill.

#### `test-contract.sh`

Verifies that the skill **matches its spec**
(`artifacts/global/biz-spec/REQ-X-001.md`). Each AC in the spec has
a corresponding `static_analysis` check in the spec — typically a
`grep` against the skill's `SKILL.md`. This test file runs those
checks.

If a test fails here, **either** the skill drifted from its spec,
**or** the spec needs updating. Resolve via the standard protocol:
open a conflict, decide which way to update, append the decision to
`DECISIONS.md`.

#### `scenarios.md`

**Documentation, not auto-runnable.** Describes mock scenarios:
given a specific state of `artifacts/` and a skill invocation, what
should the skill output? Used by humans reviewing the skill and by
phase 1+ when we wrap scenarios in a stub agent harness.

### Per-rule tests (`tests/<group>/test-rules.sh`)

A new group of tests added in EPIC-005 (REQ-VALID-001). Each group
has **one** `test-rules.sh` script that runs a set of mechanical
asserts against the relevant artifacts:

- **`manifest/`** — asserts `tree-spec.toml` against CON-10 (manifest
  v0.2): the 7 required sections, kernel.version semver,
  identity.name kebab-case, every `[pipeline.skills.*].file`
  resolves, entry_skill ∈ `[pipeline.skills]`, gate-skill
  participants, `[epic]` key, `[meta].language` whitelist,
  `[pipeline.evaluation]` presence.
- **`spec/`** — asserts every `artifacts/global/biz-spec/REQ-*.md`
  against `documents/spec-format.md §6` L0 fields: id regex +
  uniqueness, title length, status/type/priority enums, epic regex,
  scope.in non-empty, AC ≥1 with unique ids, provenance dates +
  author, conditional source_refs path resolution.
- **`router/`** — mechanically mirrors the router's 4 fail-closed
  checks documented in `skills/tree-spec/SKILL.md § "Validation
  (fail-closed)"` (kernel version, file paths, entry skills, gate
  skills).

Each assert has a stable id (e.g. `ASSERT-MANIFEST-001`,
`ASSERT-SPEC-NNN`, `ASSERT-ROUTER-NNN`) so the **rule catalog** at
[`documents/validation.md`](../documents/validation.md) can reference
each rule by id. That catalog is the single source of truth for what
each assert checks and its source of truth; the assert names here are
self-documenting shadows of those rows.

### Synthetic harness (`tests/fixtures/test-synthetic.sh`)

A **negative test** harness added in EPIC-005 T-06. It walks
`tests/fixtures/synthetic/bad-*` fixtures (T-05) and asserts each
rule correctly fires on its assigned fixture (failure = pass for
the synthetic test; false negative = test failure).

The harness is **not** wired into `tests/run-all.sh` (per T-06 AC-6)
because the fixtures are intentionally bad — including the harness
in the happy path would always make the runner red. Run separately
(see "How to run" below).

## How to run

```bash
# From the repo root:

# Run everything (per-skill + per-rule; exits 0 iff all pass):
bash tests/run-all.sh

# Run a single per-skill test:
bash tests/intake/test-structure.sh
bash tests/intake/test-contract.sh

# Run a single per-rule test:
bash tests/manifest/test-rules.sh
bash tests/spec/test-rules.sh
bash tests/router/test-rules.sh

# Run the synthetic harness separately (manual / CI pre-merge):
bash tests/fixtures/test-synthetic.sh
# exits 0 if every fixture triggers its expected rule
# exits 1 with a named diagnostic if any rule slipped through

# Pre-flight a single area (EPIC-008 / REQ-VALID-004); fast, stdlib-only.
bash skills/tree-spec/scripts/tree-spec-check.sh --manifest
bash skills/tree-spec/scripts/tree-spec-check.sh --spec
bash skills/tree-spec/scripts/tree-spec-check.sh --router
# (no flag or --all) runs the same battery as tests/run-all.sh
```

`run-all.sh` exits 0 if all tests pass, 1 otherwise. The list of
failed tests is printed at the end.

## Catalog

The exhaustive catalog of all per-rule assertions lives at
[`documents/validation.md`](../documents/validation.md) (EPIC-007,
REQ-VALID-003) — the canonical single source of truth for what is
validated, where, and how to extend it. It is the canonical
description of what `tests/run-all.sh` validates (REQ-VALID-003 AC-4).

Each assertion in `tests/{manifest,spec,router}/test-rules.sh` has a
stable id (`ASSERT-<GROUP>-NNN`) referenced by that catalog. The
assertion names here remain self-documenting: they are printed on
pass/fail by `tests/_lib/common.sh`.

## What this is NOT

- **Not a runtime test suite.** Skills are markdown procedures, not
  executable code. The per-skill tests verify shape and contract,
  not behaviour.
- **Not a substitute for the `verify` skill.** The `verify` skill
  (in `skills/tree-spec/core-capabilities/verify/SKILL.md`) checks
  **spec ACs** (oracle runs); these tests check **manifest rules,
  spec L0 fields, and the router's documented procedure**.
- **Not a CI gate in phase 0.** Phase 0 has no runtime; these tests
  are run manually. Phase 1+ may add CI integration (EPIC-008).
- **Per-rule tests do not enforce skill **behaviour**.** They
  enforce structural rules (manifest format, spec format, file
  paths). A skill that exists at the right path with the right
  shape but produces wrong output is still green here.

## Conventions

- Each test script sources `_lib/common.sh` for shared helpers.
- All paths are relative to the project root (`$TESTS_PROJECT_ROOT`).
- Test scripts exit with the number of failed assertions (capped at
  255). `run-all.sh` converts this to a simple pass/fail.
- Use `bash`, not `sh`. The scripts use bashisms (`[[ … ]]`, arrays,
  `printf -v`).
- Every assertion in the per-rule tests has a stable id
  (`ASSERT-<GROUP>-NNN`) printed in the assertion name. The catalog
  at [`documents/validation.md`](../documents/validation.md) references
  these by id.
- The synthetic harness inverts normal assertion semantics: a rule
  correctly rejecting a fixture is a PASS (the rule fired). A rule
  accepting a fixture is a FAIL (false negative — the rule design
  is broken or the fixture is malformed).
