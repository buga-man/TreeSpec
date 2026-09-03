---
id: tree-spec
name: tree-spec
description: Registrar and router for the TreeSpec kit. Runs startup, validates the manifest, runs session-resume, and dispatches to the next capability (intake, spec, plan, implement, verify, resume)
version: 0.1.0
phase: 0
stage: any                              # runs at the start of any session, before any capability
classification: hybrid                 # deterministic state-based routing + judgement on ambiguous state

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - command: string                     # free-text request ("start tree-spec", "implement T-02", "new idea", ...)
  - language: string | null             # i18n: overrides [meta.language] for this session only
output:
  - resume_report: markdown             # from session-resume
  - next_capability: string             # capability id to dispatch to
side_effects:
  - reads tree-spec.toml (root manifest + skill-root-relative [pipeline.skills.*].file paths)
  - reads artifacts/INDEX.md and the active epic STATUS.md
  - may run the `init` capability on a fresh project (no tree-spec.toml)
  - may recompute the machine-maintained [epic] pointer (AC-6)
  - does NOT modify any user-owned section without an explicit human request (AC-7)
failure_handling:
  - on_missing_tree_spec_toml: "run the init capability; do NOT fabricate a manifest"
  - on_validation_failure: "stop; report each failed check; do NOT route to any capability (AC-5)"
  - on_ambiguous_state: "report the observed state; ask the human; do NOT guess"

composition:
  - may_invoke: [init, session-resume]  # explicit only — routing is not implicit composition (invariant 6)
# ── SOURCE OF TRUTH (concepts) ──────────────────────────────────
#   - ../../documents/validation.md          # what is validated, where, how to extend
#   - ../../documents/spec-format.md         # spec L0 fields
#   - tree-spec.toml                         # the manifest / contract
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, field names, paths, and
# verification commands/oracles stay canonical English.
---

# Skill: tree-spec (router / registrar)

**Stage:** any — runs at the start of a session, before any capability.
**Purpose:** register and route the kit. This is the **only registered
skill** of the kit. It starts the work by checking project state,
validating the manifest, running `session-resume` (read-only), and
dispatching to the capability that state calls for. It matches on
**project state**, not on free-text topic — which is what removes skill
competition and gives the kit a single front door.

> **Source of truth:** `tree-spec.toml` sections
> `[pipeline.stages.*]` and `[pipeline.skills.*]` (this skill) and
> `[pipeline.evaluation]` (global rules). The manifest is the contract;
> this markdown is the procedure the agent follows to satisfy it. If they
> ever disagree, the manifest wins — escalate to the human.

## Startup sequence

1. **Match on project state.** If `tree-spec.toml` **or** `artifacts/`
   exists in the working directory → this skill runs. Otherwise, ask the
   human whether to `init` the kit. Non-TreeSpec work is left to whatever
   other skills exist — the partition is deterministic, which is what
   removes competition (AC-9).

2. **Check `tree-spec.toml`.**
   - **Missing** → run the `init` capability (create the manifest from
     `tree-spec.template.toml` plus the `artifacts/` skeleton), then
     continue.
   - **Present** → validate the user-owned sections (fail-closed on error
     — Step "Validation"), then recompute the machine-maintained `[epic]`
     pointer from `artifacts/` (record a warning on divergence, leave
     `artifacts/` unmodified — AC-6). If the human has not explicitly asked
     for a manifest change, do **not** write any user-owned section (AC-7).

3. **Run `session-resume`** (read-only) → resume report + recommended next
   action.

4. **Dispatch** to the capability named by the manifest stage / resume
   recommendation. The router only starts the work — the dispatched
   capability reads the shared documents. See **Shared documents** below.

5. **Fresh project, no active epic** → the router recommends creating one
   (`brainstorm` → `write-spec`).

## Validation (fail-closed)

When `tree-spec.toml` is present, **before routing**, validate the
user-owned sections. If any check fails, stop and report **each failed
check** — do **not** route to any capability (AC-4, AC-5):

1. **Kernel version** — `[kernel].version` is compatible with this kit.
2. **File paths** — every `[pipeline.skills.*].file` path resolves
   relative to the skill root (see "Manifest v0.2 resolution").
3. **Entry skills** — each stage's `entry_skill` is listed in that
   stage's `skills`.
4. **Gate skills** — every gate participant of kind `skill` names a
   declared skill.

If validation passes, continue to Step 3. Never silently regenerate or
"fix" a failed contract — report and stop (AC-5, forbidden list).

## Pre-flight (fast per-area checks)

For a targeted edit — a manifest section, a spec fix — pre-flight one
area before the full battery or CI. The wrapper wraps the same asserts as
`tests/`, so the two never disagree:

```bash
skills/tree-spec/scripts/tree-spec-check.sh --manifest
skills/tree-spec/scripts/tree-spec-check.sh --spec
skills/tree-spec/scripts/tree-spec-check.sh --router
```

`--all` (or no flag) runs every group and matches
`bash tests/run-all.sh` exit-code semantics (REQ-VALID-004 / EPIC-008).

## Capabilities

| Capability | Owns |
|---|---|
| `init` | bootstrap — manifest (from template) + `artifacts/` skeleton |
| `session-resume` | read-only state recovery + next-action recommendation |
| `intake` | raw sources → candidate buffer |
| `brainstorm` | L0 spec draft |
| `write-spec` | write + register spec |
| `plan` | decompose approved spec into tasks |
| `implement` | implement one task per session |
| `verify` | run AC oracles, capture evidence |

## Shared documents

The single source of truth for kit docs and templates is
`tree-spec/documents/`. Inside `core-capabilities/`, shared documents are
referenced once, as `../../documents/...` (capability dir → skill root).
AC-10 makes this greppable. Do not re-copy shared docs elsewhere.

## Manifest v0.2 resolution

`[pipeline.skills.*].file` values resolve **relative to the skill root**
(`skills/tree-spec/`), keeping the manifest portable across install
locations. Example: `core-capabilities/init/SKILL.md` resolves to
`skills/tree-spec/core-capabilities/init/SKILL.md`. The router declares
this once (here); AC-4 validates it on every start.

## Anti-patterns

- ❌ Routing on free-text topic instead of project state (AC-9).
- ❌ Fabricating a manifest when `tree-spec.toml` is missing — defer to
  `init`.
- ❌ Continuing to route after a failed validation check (AC-5).
- ❌ Writing a user-owned manifest section without an explicit human
  request (AC-7).
- ❌ Re-copying shared docs outside the skill — violates AC-10.

## Claim / Verify

- **Claim:** "Startup run, manifest validated (or init run on a fresh
  project), session-resume executed, next capability dispatched, no
  unrequested user-owned edits".
- **Verify (run by the `verify` skill at stage 4):**
  - The router matched on `tree-spec.toml` / `artifacts/` presence, not
    topic (AC-9).
  - Validation ran before routing and reported each failed check on error
    (AC-4, AC-5).
  - `[epic]` matches `artifacts/` after start, `artifacts/` unmodified
    (AC-6); zero user-owned lines changed without an explicit request
    (AC-7).
  - Shared doc refs inside core-capabilities use `../../documents/...`
    (AC-10).
