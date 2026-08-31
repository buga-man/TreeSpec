---
id: init
name: init
description: Bootstrap a fresh project — create the manifest from the kit template and the artifacts/ skeleton, idempotently
version: 0.1.0
phase: 0
stage: any
classification: hybrid                 # deterministic structure + judgement on identity fields

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - directory: string                   # project root where the kit is being installed
output:
  - manifest: path                      # newly created tree-spec.toml
  - artifacts_skeleton: path[]          # artifacts/README.md, artifacts/INDEX.md, global/biz-spec/, epics/
side_effects:
  - writes tree-spec.toml from tree-spec.template.toml (identity filled by the human)
  - creates the artifacts/ skeleton (idempotent)
  - does NOT touch user files already present in the project
failure_handling:
  - on_existing_manifest: "skip — the manifest already lives (idempotent)"
  - on_missing_identity: "ask the human for [identity].name; do NOT guess a project name"
  - on_existing_user_files: "do NOT overwrite them — leave a warning, do NOT fabricate artifacts"

composition: []                         # bootstrap is a single responsibility (invariant: bootstrap in one place)
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: init

**Stage:** any — launched by the router (Step 2 of the startup sequence)
when a project has no `tree-spec.toml`. **Purpose:** bootstrap a fresh
project by creating the manifest from the kit template plus the
`artifacts/` skeleton. Bootstrap logic lives in **exactly one** capability
(the invariant that removed the duplicated bootstrap from `write-spec` and
`intake`).

> **Source of truth:** `tree-spec.toml` section
> `[pipeline.skills.init]` (this skill's contract) and `[pipeline.gates.*]`.
> The manifest is the contract; this markdown is the procedure the agent
> follows to satisfy it.

## Procedure

### Step 1. Idempotency check

```
test -f tree-spec.toml && echo EXISTS || echo MISSING
```

- **EXISTS** → skip; the manifest already lives (AC-3, second run changes
  nothing). Stop.
- **MISSING** → continue.

### Step 2. Fill identity

Read `tree-spec.template.toml` and set `[identity].name` and
`[identity].owners` from the human (ask for the project name if not given;
never guess — `on_missing_identity`). Write the result to `tree-spec.toml`.

### Step 3. Create the artifacts/ skeleton

Create (only if missing, idempotently):

```
artifacts/README.md
artifacts/INDEX.md
artifacts/global/biz-spec/README.md
artifacts/epics/
```

Do **not** overwrite user files already present. If a file the skeleton
would create already exists with content, leave it and warn.

### Step 4. Validate

After creating the manifest, run the router's startup validation (kernel
version, `[pipeline.skills.*].file` resolution, `entry_skill` membership,
gate skill participants). If any check fails, report each failed check and
stop — do **not** route to any capability (AC-5).

## Anti-patterns

- ❌ Fabricating a manifest by hand — always derive it from
  `tree-spec.template.toml`.
- ❌ Overwriting existing user files.
- ❌ Re-introducing bootstrap logic into any capability other than `init`.

## Claim / Verify

- **Claim:** "tree-spec.toml created from template with human identity,
  artifacts/ skeleton created, validation passed, idempotent".
- **Verify (run by the `verify` skill):**
  - Running `init` in a dir without `tree-spec.toml` creates the manifest
    from the template and the artifacts/ skeleton (AC-3).
  - A second run changes no file (AC-3).
