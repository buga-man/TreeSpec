# Per-skill tests

This folder contains tests for the **7 skills** in `skills/`. The
structure mirrors `skills/`: one folder per skill, with three
artefacts inside.

## Layout

```
tests/
├── README.md                # this file
├── run-all.sh               # entry point — runs all test scripts
├── _lib/
│   └── common.sh            # shared test helpers (assert_* functions)
├── intake/
│   ├── test-structure.sh    # file presence, frontmatter, body shape
│   ├── test-contract.sh     # matches REQ-INTAKE-001.md ACs
│   └── scenarios.md         # mock scenarios (documentation)
├── session-resume/
│   ├── test-structure.sh    # file presence, frontmatter, body shape
│   ├── test-contract.sh     # matches specs/REQ-RESUME-001.md ACs
│   └── scenarios.md         # mock scenarios (documentation)
├── brainstorm/
│   ├── test-structure.sh
│   ├── test-contract.sh
│   └── scenarios.md
└── … (one folder per skill)
```

## What each file does

### `test-structure.sh`

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

### `test-contract.sh`

Verifies that the skill **matches its spec** (`specs/REQ-X-001.md`).
Each AC in the spec has a corresponding `static_analysis` check in the
spec — typically a `grep` against the skill's `SKILL.md`. This test
file runs those checks.

If a test fails here, **either** the skill drifted from its spec,
**or** the spec needs updating. Resolve via the standard protocol:
open a conflict, decide which way to update, append the decision to
`DECISIONS.md`.

### `scenarios.md`

**Documentation, not auto-runnable.** Describes mock scenarios:
given a specific state of `artifacts/` and a skill invocation, what
should the skill output? Used by humans reviewing the skill and by
phase 1+ when we wrap scenarios in a stub agent harness.

## How to run

```bash
# From the repo root:
bash tests/run-all.sh

# Or a single skill:
bash tests/session-resume/test-structure.sh
bash tests/session-resume/test-contract.sh
```

`run-all.sh` exits 0 if all tests pass, 1 otherwise. The list of failed
tests is printed at the end.

## What this is NOT

- **Not a runtime test suite.** Skills are markdown procedures, not
  executable code. The tests verify shape and contract, not behaviour.
- **Not a substitute for the `verify` skill.** The `verify` skill
  (in `skills/verify/SKILL.md`) checks **spec ACs** (oracle runs);
  these tests check **skill contracts** (frontmatter shape, spec
  alignment).
- **Not a CI gate in phase 0.** Phase 0 has no runtime; these tests
  are run manually. Phase 1+ may add CI integration.

## Conventions

- Each test script sources `_lib/common.sh` for shared helpers.
- All paths are relative to the project root (`$TESTS_PROJECT_ROOT`).
- Test scripts exit with the number of failed assertions (capped at
  255). `run-all.sh` converts this to a simple pass/fail.
- Use `bash`, not `sh`. The scripts use bashisms (`[[ … ]]`, arrays,
  `printf -v`).