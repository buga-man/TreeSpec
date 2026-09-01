# TreeSpec Target — Phase 0 Dogfood

[![License: OSL-3.0](https://img.shields.io/badge/License-OSL--3.0-blue.svg)](./LICENSE.md)
[![maintained?](https://img.shields.io/badge/maintained-yes-green.svg)](./docs/REPOSITORY-PROTECTION.md)
[![PRs welcome (from forks)](https://img.shields.io/badge/PRs-from%20forks--blueviolet.svg)](./CONTRIBUTING.md)

> This repository is a **consumer** of the [TreeSpec](../) framework.
> It exists to validate that the phase 0 kit works end-to-end by
> **using it as the project itself**.
>
> **Read-only for everyone except the owner.** Direct edits are not
> accepted — see [`CONTRIBUTING.md`](./CONTRIBUTING.md) and
> [`docs/REPOSITORY-PROTECTION.md`](./docs/REPOSITORY-PROTECTION.md)
> for the fork → PR flow and the GitHub-side enforcement.

## What is here

- `tree-spec.toml` — project manifest (phase 0 minimal, agent-readable).
  Declares the 4-stage flow (`spec, plan, implement, verify`), the 3 human
  gates (`G_spec`, `G_plan`, `G_done`), the 7 skills, and the global
  evaluation rules (`[pipeline.evaluation]`).
- `skills/` — 7 skill folders, one per skill. Each folder holds a
  `SKILL.md` (the entry point the agent reads). Skills:
  `intake` (normalizes raw sources into the candidate buffer),
  `session-resume`, `brainstorm` (drafts L0 from ideas or buffered
  candidates; optional `source_doc` fallback), `write-spec`
  (bootstraps `artifacts/` on first run), `plan`, `implement`, `verify`.
- `specs/` — 8 specs describing the kit itself (1 setup + 6 skill specs + 1 i18n).
  These are the **kit describing itself** — they formalize the contract
  each component obeys. Useful as input to phase 1+ automation.
- `artifacts/` — the project's living memory:
  - `INDEX.md` — live epic index.
  - `README.md` — agent protocol (session start / end).
  - `global/biz-spec/REQ-TREESPEC-001.md` — the first spec.
  - `epics/EPIC-001-install-kit/` — the first epic, closed.

## What is NOT here

- `documents/concepts/` — those live in the framework repo. This target
  consumes the kit, not the framework's design docs.
- `documents/phases/` — same.
- Plugins, registry, CLI, runtime — phase 1+.

---

## Install guide

> This repo is **already installed** — the kit shipped here as part of
> phase 0 dogfood (`EPIC-001-install-kit`, all 8 ACs passed). Use this
> section as a ** checklist when installing the kit into a fresh
> project**, or as a sanity check after refactors.

### Prerequisites

- A TOML-aware tool. Optional: Python ≥ 3.11 (ships `tomllib` in stdlib).
- A text editor. No IDE, no specific host (Claude Code / Cursor /
  Windsurf / Aider all work — the kit is app-agnostic).
- No network, no admin rights, no package manager.

### Install in 5 steps

The kit is **self-contained** — `tree-spec.toml` paths are relative to
the manifest's own location, so copying the kit folder preserves the
wiring.

**Step 1.** Pick an install location. Two common options:

```
<project>/.treespec/phase_0/         # hidden, near the root
<project>/documents/phases/phase_0/  # visible, matches the framework layout
```

This repo uses the second form (under `documents/`).

**Step 2.** Copy the kit folder:

```
cp -r path/to/TreeSpec/documents/phases/phase_0  <project>/documents/phases/
```

This gives you `tree-spec.toml`, `README.md`, `setup.md`, `specs/`, and
`skills/`.

**Step 3.** Put the manifest at the project root (the agent reads it
from there at session start). Two options:

```
# Option A: copy and edit
cp <project>/documents/phases/phase_0/tree-spec.toml  <project>/tree-spec.toml
# then edit [identity].name and [identity].owners for your project

# Option B: symlink (single source of truth)
ln -s documents/phases/phase_0/tree-spec.toml  tree-spec.toml
```

**Step 4.** Initialize the `artifacts/` directory (**optional** —
`write-spec` bootstraps it automatically on first run):

```
mkdir -p <project>/artifacts/global/biz-spec
mkdir -p <project>/artifacts/epics
```

Copy `artifacts/README.md` and `artifacts/INDEX.md` templates from the
framework repo (or write your own — they hold the agent protocol and
the live epic index). The complete directory layout is documented in
`skills/tree-spec/documents/references/artifacts-layout.md`; no separate template
directory is needed for new epics.

If you skip this step, the `write-spec` skill will create the minimum
structure (`README.md`, `INDEX.md`, `global/biz-spec/`, `epics/`) when
you run it for the first time. The kit is self-bootstrapping.

**Step 5.** Sanity-check the install. From the project root:

```bash
# 1. The manifest parses as valid TOML
python -c "import tomllib; tomllib.load(open('tree-spec.toml','rb'))" && echo OK

# 2. Every skill path declared in the manifest exists
for s in session-resume brainstorm write-spec plan implement verify; do
  test -f "skills/$s/SKILL.md" || { echo "MISSING: $s"; exit 1; }
done && echo OK

# 3. artifacts/ has the protocol and the index
test -f artifacts/README.md && test -f artifacts/INDEX.md && echo OK
```

All three should print `OK`. If anything fails, see
`specs/REQ-SETUP-001.md` for the full acceptance contract.

### What the agent needs

Whichever environment you use, give the agent this one-paragraph brief
at the top of its session:

> You are working under TreeSpec phase 0. The project manifest is at
> `tree-spec.toml` — **read it as your contract**. It declares which
> skills run where, what each stage produces, and the global rules
> (`[pipeline.evaluation]`) you must obey. Start every session by running
> the `session-resume` skill (path is in the manifest). Follow the skill
> it recommends; the manifest's `[pipeline.stages.<X>].exit_criteria`
> tell you when a stage is done. Do not skip a human gate (`G_spec`,
> `G_plan`, `G_done`) — wait for human approval. At the end of the
> session, update the epic's `STATUS.md`, `tasks.md`, and (if applicable)
> `PATH.md` / `DECISIONS.md`.

That's the entire agent setup. No APIs, no plugins, no runtime.

### When the manual install becomes automated

Phase 0 is manual by design (no runtime). In phase 2 a `tree-spec init`
CLI will replace the 5 steps above with one command. The spec that
drives it: `specs/REQ-SETUP-001.md`.

---

## How to use the kit (this repo's daily loop)

1. Run `session-resume` (path in `tree-spec.toml`). It reads the
   artifacts and tells you which stage the active epic is at and
   which skill to run next.
2. Follow the skill it recommends.
3. End of session: update the epic's `STATUS.md`, `tasks.md`, and
   (if applicable) `PATH.md` / `DECISIONS.md`.

Gates `G_spec` / `G_plan` / `G_done` are human-only — wait for the
human to pass them before continuing.

### Working with raw requirements (BR, US, etc.)

`brainstorm` accepts an optional `source_doc: path` field. When
provided, it reads the document first, extracts candidate requirements
(structured BR/US lists or prose with "shall/must/should"), and asks
you which one to spec out.

```python
# Example: process a backlog
brainstorm(
    idea="auth backlog items",
    source_doc="backlog/auth.md",     # BR-1, BR-2, BR-3, ...
)
# → "I found 3 candidates. Spec which? (1, 2, 3, or describe)"

# Example: process one specific BR
brainstorm(
    idea="BR-7 from biz-spec.md",
    source_doc="docs/raw-requirements.md",
)
# → reads doc, finds BR-7, specs it out
```

The skill produces **one L0 draft per run**. In bulk mode (human picks
"spec them all"), it iterates one at a time, getting your confirmation
between drafts. No silent batch emission.

### First-run flow (fresh project)

If `artifacts/` does not yet exist (e.g., you installed only `tree-spec.toml`,
`skills/`, `specs/`), the kit bootstraps itself on first use:

```
session-resume   → reads tree-spec.toml
   → "no artifacts/ — bootstrap via write-spec (run brainstorm first)"
brainstorm       → dialogue with human → L0 spec draft (in memory)
write-spec       → Step 0: creates artifacts/{README.md, INDEX.md, global/biz-spec/, epics/}
                → Step 3+: writes the spec, registers it, creates biz-spec-delta
```

After this, the daily loop above takes over. The bootstrap step is
idempotent — re-running `write-spec` on an already-bootstrapped project
does not recreate existing files.

## Provenance

This target repo was bootstrapped by following the phase 0 kit
specifications written in the framework repo
(`../documents/phases/phase_0/specs/`). The first epic
(`EPIC-001-install-kit`) was executed via the 4-stage flow:

```
spec → G_spec → plan → G_plan → implement → verify → G_done
```

All 8 acceptance criteria of `REQ-TREESPEC-001` passed mechanical
sanity checks (twice — once after install, once after the skill
restructure to `skills/<id>/SKILL.md`). See
`artifacts/epics/EPIC-001-install-kit/docs/verification.md`.

## License

See [`LICENSE.md`](./LICENSE.md) (OSL-3.0). By contributing you agree to
these terms — see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

For security disclosures, follow [`SECURITY.md`](./SECURITY.md) — **do not**
file security issues as public issues.